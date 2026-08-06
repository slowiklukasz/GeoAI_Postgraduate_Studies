-- W tym pliku znajdować się będą już gotowe zapytania, które tworzą tabele, widoki czy inne gotowe produkty bazy danych.
-- zapisywane do właściwego schematu bazy danych.
-- Ten plik jest plik do edycji, ale do stworzenia dopiero jak ogarnięty będzie poprzedni plik 02_* -  w sensie najpierw tworzysz kwerendę typu select a potem dopiero taką która zapisuje danę. Pomocne jest przy tym użycie pojęcia `CIT`


---------------------------------------------------------------------------------------------------------------------------------------
-- Przygotowanie tabeli raw.lesnictwa: dodanie kolumny `id` wyliczanej z trzeciego segmentu adr_for (numer leśnictwa).
-- Wymagane przez Zapytanie nr 4. IF EXISTS / GENERATED ALWAYS ... STORED czyni operację idempotentną.
---------------------------------------------------------------------------------------------------------------------------------------
ALTER TABLE raw.lesnictwa DROP COLUMN IF EXISTS id;
ALTER TABLE raw.lesnictwa
ADD COLUMN id NUMERIC
GENERATED ALWAYS AS (SPLIT_PART(adr_for, '-', 3)::numeric) STORED;


---------------------------------------------------------------------------------------------------------------------------------------
-- Zapytanie SQL nr 1: ile jest punktów informacji turystycznej w każdym leśnictwie?
---------------------------------------------------------------------------------------------------------------------------------------

CREATE MATERIALIZED VIEW analityka.vw_K_smietniki AS

-- CTE 1: Wybór punktów infrastruktury (BIWAK, ZADASZ, PARKING)
WITH wybrane_punkty AS (
    SELECT
        ogc_fid,
        kod_ob,
        ST_SetSRID(wkb_geometry, 2180) AS wkb_geometry
    FROM raw.turystyka_punktowa
    WHERE kod_ob IN ('BIWAK', 'ZADASZ', 'PARKING')
      AND ST_IsValid(wkb_geometry) = TRUE
),
-- CTE 2: Przygotowanie warstwy wydzieleń
wydzielenia_adresy AS (
    SELECT
        ogc_fid,
        adr_les,
        SPLIT_PART(adr_les, '-', 4) AS nr_lesnictwa,
        SPLIT_PART(adr_les, '-', 5) AS nr_oddzialu,
        ST_SetSRID(wkb_geometry, 2180) AS wkb_geometry
    FROM raw.wydzielenia
    WHERE adr_les IS NOT NULL
      AND ST_IsValid(wkb_geometry) = TRUE
),
-- CTE 3: Złączenie przestrzenne punktów z wydzieleniami
zlaczenie_przestrzenne AS (
    SELECT 
        p.ogc_fid AS id_punktu,
        p.kod_ob AS typ_obiektu,
        w.nr_lesnictwa,
        w.nr_oddzialu,
        p.wkb_geometry AS geom_punktu 
    FROM wybrane_punkty p
    INNER JOIN wydzielenia_adresy w
        ON ST_Intersects(p.wkb_geometry, w.wkb_geometry)
)
-- Zapytanie końcowe dodające ROW_NUMBER oraz wymuszające typ MultiPoint z SRID
SELECT 
    ROW_NUMBER() OVER () AS id_qgis, -- Unikalny klucz dla QGIS
    nr_lesnictwa,
    nr_oddzialu,
    typ_obiektu, 
    COUNT(id_punktu) AS liczba_pojemnikow_na_smieci,
    ST_SetSRID(ST_CollectionExtract(ST_Collect(geom_punktu), 1), 2180)::geometry(MultiPoint, 2180) AS wkb_geometry
FROM zlaczenie_przestrzenne
GROUP BY 
    nr_lesnictwa,
    nr_oddzialu,
    typ_obiektu
ORDER BY 
    nr_lesnictwa, 
    nr_oddzialu,
    typ_obiektu;

-- Tworzenie indeksu dla klucza głównego (wymóg QGIS)
CREATE UNIQUE INDEX idx_vw_k_smietniki_id_qgis 
ON analityka.vw_K_smietniki (id_qgis);

-- Stworzenie indeksu przestrzennego
CREATE INDEX IF NOT EXISTS _K_smietniki_geom 
ON analityka.vw_K_smietniki USING GIST (wkb_geometry);

---------------------------------------------------------------------------------------------------------------------------------------
-- Zapytanie SQL nr 2: Wykaz długości tras ze stravy z podzialem na leśnictwa i oddziały
---------------------------------------------------------------------------------------------------------------------------------------

CREATE MATERIALIZED VIEW analityka.vw_K_strava_dlugosc_tras AS
WITH wydzielenia_adresy AS (
    SELECT
        ogc_fid,
        SPLIT_PART(adr_les, '-', 4) AS nr_lesnictwa,
        ST_SetSRID(wkb_geometry, 2180) AS wkb_geometry
    FROM raw.wydzielenia
    WHERE adr_les IS NOT NULL
      AND ST_IsValid(wkb_geometry) = TRUE
),
strava_trasy AS (
    SELECT
        ogc_fid,
        ST_SetSRID(wkb_geometry, 2180) AS wkb_geometry
    FROM raw.strava
    WHERE ST_IsValid(wkb_geometry) = TRUE
),
przeciecie_tras AS (
    SELECT 
        w.nr_lesnictwa,
        ST_Intersection(s.wkb_geometry, w.wkb_geometry) AS przecieta_geometria
    FROM strava_trasy s
    INNER JOIN wydzielenia_adresy w
        ON ST_Intersects(s.wkb_geometry, w.wkb_geometry)
)
SELECT 
    ROW_NUMBER() OVER () AS id_qgis, -- Unikalny klucz dla QGIS
    nr_lesnictwa,
    ROUND((SUM(ST_Length(przecieta_geometria)) / 1000)::numeric, 2) AS suma_dlugosci_tras_km,
    ST_SetSRID(ST_CollectionExtract(ST_Collect(przeciecie_tras.przecieta_geometria), 2), 2180)::geometry(MultiLineString, 2180) AS wkb_geometry
FROM przeciecie_tras
WHERE ST_GeometryType(przecieta_geometria) IN ('ST_LineString', 'ST_MultiLineString')
GROUP BY 
    nr_lesnictwa
ORDER BY 
    nr_lesnictwa;

-- Tworzenie indeksu dla klucza głównego (wymóg QGIS)
CREATE UNIQUE INDEX idx_vw_k_strava_id_qgis 
ON analityka.vw_K_strava_dlugosc_tras (id_qgis);

CREATE INDEX IF NOT EXISTS idx_analityka_strava_dlugosc_tras_geom 
ON analityka.vw_K_strava_dlugosc_tras USING GIST (wkb_geometry);

---------------------------------------------------------------------------------------------------------------------------------------
-- Zapytanie SQL nr 3: 
---------------------------------------------------------------------------------------------------------------------------------------

-- Utworzenie fizycznej tabeli z wynikami zapytania w schemacie analityka
CREATE TABLE analityka.t_K_straz_pozarna AS

-- CTE 1: Wybranie budynków straży pożarnej
-- ST_SetSRID na 2180 - bdot10k_budynki ma w bazie SRID 900914 (QGIS custom), współrzędne i tak są PUWG 1992
WITH straz_pozarna AS (
    SELECT
        ogc_fid,
        nazwa1,
        ST_SetSRID(wkb_geometry, 2180) AS wkb_geometry
    FROM raw.bdot10k_budynki
    WHERE (nazwa1 ILIKE '%pożar%' OR nazwa1 ILIKE '%pozar%')
      AND ST_IsValid(wkb_geometry) = TRUE
),

-- CTE 2: Wybranie pół biwakowych z dodaniem kolumny nazwy obiektu
pola_biwakowe AS (
    SELECT
        ogc_fid,
        nzw_ob, -- Dodana nazwa własna biwaku
        ST_SetSRID(wkb_geometry, 2180) AS wkb_geometry
    FROM raw.turystyka_punktowa
    WHERE kod_ob = 'BIWAK'
      AND ST_IsValid(wkb_geometry) = TRUE
),

-- CTE 3: Przygotowanie warstwy oddziałów
oddzialy_adresy AS (
    SELECT
        ogc_fid,
        SPLIT_PART(adr_les, '-', 4) AS nr_lesnictwa,
        SPLIT_PART(adr_les, '-', 5) AS nr_oddzialu,
        ST_SetSRID(wkb_geometry, 2180) AS wkb_geometry
    FROM raw.oddzialy
    WHERE adr_les IS NOT NULL
      AND ST_IsValid(wkb_geometry) = TRUE
),

-- CTE 4: Przypisanie pól biwakowych do oddziałów (łączenie przestrzenne)
biwaki_w_oddzialach AS (
    SELECT 
        pb.ogc_fid AS id_biwaku,
        pb.nzw_ob AS nazwa_biwaku, -- Przekazujemy nazwę dalej
        oa.nr_lesnictwa,
        oa.nr_oddzialu,
        pb.wkb_geometry AS geom_biwaku
    FROM pola_biwakowe pb
    INNER JOIN oddzialy_adresy oa
        ON ST_Intersects(pb.wkb_geometry, oa.wkb_geometry)
)

-- Ostateczne zapytanie wstawiane do tabeli (Nearest Neighbor z LATERAL)
SELECT 
    bo.nr_lesnictwa,
    bo.nr_oddzialu,
    bo.id_biwaku,
    bo.nazwa_biwaku,
    sp.nazwa1 AS najblizsza_jednostka_strazy,
    ROUND(ST_Distance(bo.geom_biwaku, sp.wkb_geometry)::numeric, 2) AS odleglosc_do_strazy_m,
    bo.geom_biwaku AS wkb_geometry
FROM biwaki_w_oddzialach bo
CROSS JOIN LATERAL (
    SELECT 
        nazwa1, 
        wkb_geometry
    FROM straz_pozarna
    ORDER BY bo.geom_biwaku <-> wkb_geometry
    LIMIT 1
) sp
ORDER BY 
    bo.nr_oddzialu, 
    bo.nr_lesnictwa;

-- Założenie indeksu przestrzennego GIST dla nowo powstałej tabeli
CREATE INDEX IF NOT EXISTS idx_analityka_t_k_straz_pozarna_geom 
ON analityka.t_K_straz_pozarna USING GIST (wkb_geometry);

---------------------------------------------------------------------------------------------------------------------------------------
-- Zapytanie SQL nr 4: 
---------------------------------------------------------------------------------------------------------------------------------------

-- 1. Utworzenie fizycznej tabeli z wynikami w schemacie analityka
CREATE TABLE analityka.t_K_zageszczenie_budynkow AS

-- CTE 1: Filtracja tylko niezbędnych budynków
-- ST_SetSRID na 2180 - bdot10k_budynki ma w bazie SRID 900914 (QGIS custom), współrzędne i tak są PUWG 1992
WITH wybrane_budynki AS (
    SELECT ST_SetSRID(wkb_geometry, 2180) AS wkb_geometry
    FROM raw.bdot10k_budynki
    WHERE (
        nazwa1 ILIKE '%budynek jednorodzinny%' OR nazwa1 ILIKE '%budynek wielorodzinny%' OR
        nazwa1 ILIKE '%agroturystyka%' OR nazwa1 ILIKE '%apartament%' OR
        nazwa1 ILIKE '%budynek leśnictwa%' OR nazwa1 ILIKE '%dom weselny%' OR
        nazwa1 ILIKE '%dom wypoczyn%' OR nazwa1 ILIKE '%dom, nr rej.%' OR
        nazwa1 ILIKE '%dom letniskowy%'
    ) AND ST_IsValid(wkb_geometry) = TRUE
),

-- CTE 2: Przygotowanie warstwy leśnictw (naprawienie SRID i powierzchni)
lesnictwa_baza AS (
    SELECT 
        id, 
        SPLIT_PART(adr_for, '-', 4) AS nr_lesnictwa,
        f_r_name AS nazwa_lesnictwa,
        ST_SetSRID(wkb_geometry, 2180) AS geom_lesnictwa,
        (ST_Area(ST_SetSRID(wkb_geometry, 2180)) / 10000.0) AS powierzchnia_ha
    FROM raw.lesnictwa
    WHERE wkb_geometry IS NOT NULL AND ST_IsValid(wkb_geometry) = TRUE
),

-- CTE 3: Zliczanie budynków wewnątrz leśnictw przy użyciu indeksów
zliczanie_budynkow AS (
    SELECT 
        l.id,
        COUNT(b.wkb_geometry) AS liczba_budynkow
    FROM lesnictwa_baza l
    LEFT JOIN wybrane_budynki b 
        ON ST_Contains(l.geom_lesnictwa, b.wkb_geometry)
    GROUP BY l.id
)

-- Ostateczny SELECT wstawiający dane do nowej tabeli
SELECT 
    l.nr_lesnictwa,
    l.nazwa_lesnictwa,
    zb.liczba_budynkow,
    ROUND(l.powierzchnia_ha::numeric, 2) AS powierzchnia_lesnictwa_ha,
    CASE 
        WHEN l.powierzchnia_ha > 0 THEN ROUND((zb.liczba_budynkow / l.powierzchnia_ha)::numeric, 4)
        ELSE 0 
    END AS zageszczenie_budynkow_na_ha,
    l.geom_lesnictwa AS geom
FROM lesnictwa_baza l
JOIN zliczanie_budynkow zb 
    ON l.id = zb.id
ORDER BY 
    l.nr_lesnictwa;

-- 2. Założenie indeksu przestrzennego GIST dla nowo wygenerowanej tabeli
CREATE INDEX IF NOT EXISTS idx_analityka_t_k_zageszczenie_budynkow_geom 
ON analityka.t_K_zageszczenie_budynkow USING GIST (geom);