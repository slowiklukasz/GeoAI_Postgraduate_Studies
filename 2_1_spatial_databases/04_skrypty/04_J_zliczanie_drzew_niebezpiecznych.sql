-- ============================================================
-- TWORZENIE TABELI pomiary_temp
-- ============================================================

-- Usuń tabelę pomiary_bufory jeśli istnieje (żeby uniknąć konfliktu przy tworzeniu pomiary_temp)
DROP TABLE IF EXISTS analityka.pomiary_bufory;
-- Usuń tabelę pomiary_temp jeśli istnieje (czyste środowisko przed tworzeniem nowej)
DROP TABLE IF EXISTS analityka.pomiary_temp;

-- Utwórz nową tabelę pomiary_temp na podstawie wyników zapytania
-- Wszystkie warstwy są w EPSG:2180 (PUWG 1992), więc bez ST_Transform / ST_SetSRID.
CREATE TABLE analityka.pomiary_temp AS
SELECT
    p.*,          -- wszystkie kolumny z tabeli pomiary
    w.adr_les     -- adres leśny z tabeli wydzielenia
FROM raw.pomiary p
-- Dołącz wydzielenia leśne do punktów pomiarowych
LEFT JOIN raw.wydzielenia w
    -- Warunek 1: sprawdź czy obwiednie (bounding boxy) się przecinają (optymalizacja przestrzenna)
    ON p.wkb_geometry && w.wkb_geometry
   -- Warunek 2: sprawdź czy punkt leży wewnątrz wydzielenia (dokładne sprawdzenie)
   AND ST_Within(p.wkb_geometry, w.wkb_geometry);

-- Utwórz indeks przestrzenny GiST na kolumnie geometrii (przyspiesza zapytania przestrzenne)
CREATE INDEX ON analityka.pomiary_temp USING GIST (wkb_geometry);
-- Ustaw kolumnę id jako klucz główny tabeli
ALTER TABLE analityka.pomiary_temp ADD PRIMARY KEY (id);


-- ============================================================
-- TWORZENIE BUFORÓW WOKÓŁ PUNKTÓW POMIAROWYCH
-- ============================================================

-- Usuń tabelę buforów jeśli istnieje (czyste środowisko)
DROP TABLE IF EXISTS analityka.pomiary_bufory;

-- Rozpocznij transakcję (wszystkie operacje wykonają się jako jedna całość lub żadna)
BEGIN;

-- Utwórz tabelę buforów na podstawie punktów pomiarowych
CREATE TABLE analityka.pomiary_bufory AS
SELECT
    id,           -- identyfikator drzewa
    wys,          -- wysokość drzewa (użyta do obliczenia promienia bufora)
    adr_les,      -- adres leśny (oddział/pododdział)
    -- Utwórz bufor kołowy o promieniu = 1.5 × wysokość drzewa
    ST_Buffer(wkb_geometry, wys * 1.5) AS wkb_geometry
FROM analityka.pomiary_temp
-- Pomiń rekordy bez podanej wysokości (nie można obliczyć bufora)
WHERE wys IS NOT NULL;

-- Utwórz indeks przestrzenny GiST na geometrii buforów
CREATE INDEX ON analityka.pomiary_bufory USING GIST (wkb_geometry);


-- ============================================================
-- ZLICZANIE BUFORÓW PRZECINAJĄCYCH OBIEKTY W WARSTWACH j_clip_
-- ============================================================

-- Sprawdź przecięcia buforów z punktami turystycznymi
SELECT
    'j_clip_turystyka_punktowa' AS warstwa,              -- nazwa analizowanej warstwy
    COUNT(DISTINCT b.id) AS ilosc_drzew_niebezpiecznych, -- liczba unikalnych drzew zagrażających obiektom
    string_agg(DISTINCT b.adr_les, ', ' ORDER BY b.adr_les) AS "adresy obiektow" -- lista adresów leśnych
FROM analityka.pomiary_bufory b
INNER JOIN analityka.j_clip_turystyka_punktowa t
    ON b.wkb_geometry && t.wkb_geometry          -- najpierw szybki test bounding box
   AND ST_Intersects(b.wkb_geometry, t.wkb_geometry) -- potem dokładne sprawdzenie przecięcia

-- Dołącz wyniki dla warstwy tras Strava (szlaki aktywności)
UNION ALL
SELECT
    'j_clip_strava' AS warstwa,
    COUNT(DISTINCT b.id),
    string_agg(DISTINCT b.adr_les, ', ' ORDER BY b.adr_les)
FROM analityka.pomiary_bufory b
INNER JOIN analityka.j_clip_strava t
    ON b.wkb_geometry && t.wkb_geometry
   AND ST_Intersects(b.wkb_geometry, t.wkb_geometry)

-- Dołącz wyniki dla warstwy torów kolejowych
UNION ALL
SELECT
    'j_clip_torykolejowe' AS warstwa,
    COUNT(DISTINCT b.id),
    string_agg(DISTINCT b.adr_les, ', ' ORDER BY b.adr_les)
FROM analityka.pomiary_bufory b
INNER JOIN analityka.j_clip_torykolejowe t
    ON b.wkb_geometry && t.wkb_geometry
   AND ST_Intersects(b.wkb_geometry, t.wkb_geometry)

-- Dołącz wyniki dla warstwy ścieżek (np. rowerowych, pieszych)
UNION ALL
SELECT
    'j_clip_sciezki' AS warstwa,
    COUNT(DISTINCT b.id),
    string_agg(DISTINCT b.adr_les, ', ' ORDER BY b.adr_les)
FROM analityka.pomiary_bufory b
INNER JOIN analityka.j_clip_sciezki t
    ON b.wkb_geometry && t.wkb_geometry
   AND ST_Intersects(b.wkb_geometry, t.wkb_geometry)

-- Dołącz wyniki dla warstwy dróg
UNION ALL
SELECT
    'j_clip_drogi' AS warstwa,
    COUNT(DISTINCT b.id),
    string_agg(DISTINCT b.adr_les, ', ' ORDER BY b.adr_les)
FROM analityka.pomiary_bufory b
INNER JOIN analityka.j_clip_drogi t
    ON b.wkb_geometry && t.wkb_geometry
   AND ST_Intersects(b.wkb_geometry, t.wkb_geometry)

-- Dołącz wyniki dla warstwy budynków
UNION ALL
SELECT
    'j_clip_budynki' AS warstwa,
    COUNT(DISTINCT b.id),
    string_agg(DISTINCT b.adr_les, ', ' ORDER BY b.adr_les)
FROM analityka.pomiary_bufory b
INNER JOIN analityka.j_clip_budynki t
    ON b.wkb_geometry && t.wkb_geometry
   AND ST_Intersects(b.wkb_geometry, t.wkb_geometry)

-- Posortuj wyniki alfabetycznie według nazwy warstwy
ORDER BY warstwa;

-- Zatwierdź transakcję (zapisz wszystkie zmiany trwale)
COMMIT;

-- Posprzątaj — usuń tymczasową tabelę buforów po zakończeniu analizy
DROP TABLE IF EXISTS analityka.pomiary_bufory;
-- Posprzątaj — usuń tymczasową tabelę pomiarów po zakończeniu analizy
DROP TABLE IF EXISTS analityka.pomiary_temp;