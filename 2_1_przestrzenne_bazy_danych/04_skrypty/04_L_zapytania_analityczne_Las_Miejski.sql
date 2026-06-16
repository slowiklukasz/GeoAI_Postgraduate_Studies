
---------------------------------------------------------------------------------------------------------------------------------------
-- Zapytanie SQL nr 1: Przygotowanie zoptymalizowanej warstwy infrastruktury lokalnej (AOI)
---------------------------------------------------------------------------------------------------------------------------------------
-- Cel analityczny: Optymalizacja wydajnościowa poprzez ograniczenie zakresu przestrzennego analizy.
-- Metoda:          Wyznaczenie prostokątnej obwiedni (Bounding Box) dla obszaru występowania segmentów drzew, a następnie zastosowanie 
--                  funkcji ST_Intersection w celu fizycznego docięcia liniowych i punktowych obiektów infrastruktury do tego obszaru.
-- Wynik:           Zindeksowana tabela tymczasowa, zawierająca wyłącznie istotne fragmenty infrastruktury w bezpośrednim sąsiedztwie
--                  wybranego fragmentu lasu. Zestaw plików poligonowych w schemacie temporary.


-- KROK 1: Czyszczenie starej infrastruktury tymczasowej
DROP TABLE IF EXISTS temporary.L_infrastruktura_lokalna CASCADE;

-- KROK 2: Przygotowanie przyciętej i naprawionej infrastruktury w zasięgu analizy
CREATE TABLE temporary.L_infrastruktura_lokalna AS
-- Wyznaczenie prostokątnego obszaru drzew (AOI) z zapasem 100m
WITH aoi AS (
    SELECT ST_SetSRID(ST_Expand(ST_Extent(wkb_geometry), 100), 2180) AS maska 
    FROM raw.segments_2025
)
-- Docięcie (ST_Intersection) obiektów infrastruktury do obszaru AOI
SELECT 'Budynek' AS typ, ST_Intersection(ST_MakeValid(t.wkb_geometry), a.maska) AS wkb_geometry FROM raw.bdot10k_budynki t, aoi a WHERE ST_Intersects(t.wkb_geometry, a.maska)
UNION ALL SELECT 'Droga', ST_Intersection(ST_MakeValid(t.wkb_geometry), a.maska) FROM raw.bdot10k_drogi t, aoi a WHERE ST_Intersects(t.wkb_geometry, a.maska)
UNION ALL SELECT 'Sciezka', ST_Intersection(ST_MakeValid(t.wkb_geometry), a.maska) FROM raw.bdot10k_sciezki t, aoi a WHERE ST_Intersects(t.wkb_geometry, a.maska)
UNION ALL SELECT 'Kolej', ST_Intersection(ST_MakeValid(t.wkb_geometry), a.maska) FROM raw.bdot10k_torykolejowe t, aoi a WHERE ST_Intersects(t.wkb_geometry, a.maska)
UNION ALL SELECT 'Szl_L', ST_Intersection(ST_MakeValid(t.wkb_geometry), a.maska) FROM raw.turystyka_liniowa t, aoi a WHERE ST_Intersects(t.wkb_geometry, a.maska)
UNION ALL SELECT 'Szl_P', ST_Intersection(ST_MakeValid(t.wkb_geometry), a.maska) FROM raw.turystyka_punktowa t, aoi a WHERE ST_Intersects(t.wkb_geometry, a.maska)
UNION ALL SELECT 'Strava', ST_Intersection(ST_MakeValid(t.wkb_geometry), a.maska) FROM raw.strava t, aoi a WHERE ST_Intersects(t.wkb_geometry, a.maska);

-- KROK 3: Budowa indeksu przestrzennego dla zapewnienia wydajności analiz statystycznych
CREATE INDEX idx_infra_local_geom ON temporary.L_infrastruktura_lokalna USING GIST(wkb_geometry);
ANALYZE temporary.L_infrastruktura_lokalna;


---------------------------------------------------------------------------------------------------------------------------------------
-- Zapytanie SQL nr 2: Kompleksowa inwentaryzacja i priorytetyzacja drzew zagrażających infrastrukturze
---------------------------------------------------------------------------------------------------------------------------------------
-- Cel analityczny: Identyfikacja wszystkich segmentów drzew, których zasięg upadku (1.5 * H) koliduje z infrastrukturą.
-- Interpretacja:   Każdy wiersz reprezentuje jedno drzewo zagrażające. Dodatkowe kolumny (liczba i lista obiektów) 
--                  pozwalają na szybką ocenę skali ryzyka – od punktowych zagrożeń (1 obiekt) po klastry o wysokim 
--                  potencjale szkód (wiele obiektów w zasięgu jednego pnia).
-- Wynik:           Warstwa poligonowa drzew z pełną informacją o celu zagrożenia i dystansie kolizyjnym.

-- KROK 1: Czyszczenie starej tabeli
DROP TABLE IF EXISTS analityka.L_drzewa_zagrazajace CASCADE;

-- KROK 2: Agregacja zagrożeń dla każdego segmentu drzewa
CREATE TABLE analityka.L_drzewa_zagrazajace AS
WITH wszystkie_kolizje AS (
    SELECT 
        s.ogc_fid AS segment_id,
        s.max_val AS wysokosc_m,
        i.typ AS typ_obiektu,
        ST_Distance(s.wkb_geometry, i.wkb_geometry) AS dystans,
        s.wkb_geometry
    FROM raw.segments_2025 s
    JOIN temporary.L_infrastruktura_lokalna i ON ST_DWithin(s.wkb_geometry, i.wkb_geometry, s.max_val * 1.5)
    WHERE ST_Distance(s.wkb_geometry, i.wkb_geometry) < (s.max_val * 1.5) 
      AND s.max_val > 0
)
SELECT 
    ROW_NUMBER() OVER () AS id_qgis,
    segment_id,
    wysokosc_m,
    -- Liczymy, dla ilu obiektów to konkretne drzewo zagraża
    COUNT(*) AS liczba_zagrozonych_obiektow,
    -- Tworzymy listę typów tych obiektów (np. "Droga, Sciezka")
    string_agg(DISTINCT typ_obiektu, ', ') AS lista_zagrozen,
    -- Wybieramy najmniejszy dystans do jakiegokolwiek obiektu
    ROUND(MIN(dystans)::numeric, 2) AS min_dystans_m,
    ST_SetSRID(wkb_geometry, 2180)::geometry(MultiPolygon, 2180) AS wkb_geometry
FROM wszystkie_kolizje
GROUP BY segment_id, wysokosc_m, wkb_geometry
-- Sortujemy od najbardziej "szkodliwych" drzew
ORDER BY liczba_zagrozonych_obiektow DESC, wysokosc_m DESC;

-- KROK 3: Budowa indeksu przestrzennego dla zapewnienia wydajności analiz statystycznych
CREATE INDEX idx_wynik_turystyka_geom ON analityka.L_drzewa_zagrazajace USING GIST(wkb_geometry);


---------------------------------------------------------------------------------------------------------------------------------------
-- Zapytanie SQL nr 3: Modelowanie geometrycznych stref zagrożenia upadkiem drzew
---------------------------------------------------------------------------------------------------------------------------------------
-- Cel analityczny: Wizualizacja realnego zasięgu rażenia drzewostanu ograniczonego wyłącznie do kierunku kolizyjnego. 
-- Mechanizm:       Dla każdego drzewa zagrażającego tworzony jest poligon typu "klin" rozpięty między pniem a najbliższym punktem 
--                  na obiekcie infrastruktury. Zastosowanie funkcji ST_UnaryUnion scala nachodzące na siebie kliny w jednolite, 
--                  czytelne obszary operacyjne (Dissolve).
-- Wynik:           Warstwa poligonowa (MultiPolygon).

-- KROK 1: Czyszczenie starej tabeli
DROP TABLE IF EXISTS analityka.L_strefy_zagrozenia_upadkiem_drzew CASCADE;

-- KROK 2: Generowanie stref poligonów zagrożenia i ich scalanie (Dissolve)
CREATE TABLE analityka.L_strefy_zagrozenia_upadkiem_drzew AS
WITH strefy_bazowe AS (
    SELECT 
        s.ogc_fid,
        -- Budowa kierunkowego poligonu zagrożenia między drzewem a infrastrukturą lokalną
        ST_ConvexHull(
            ST_Collect(
                ARRAY[
                    s.wkb_geometry, 
                    ST_Buffer(ST_ClosestPoint(i.wkb_geometry, s.wkb_geometry), 5) -- 5m szerokości pasa rażenia na obiekcie
                ]
            )
        ) AS geom_strefy
    FROM raw.segments_2025 s
    JOIN temporary.L_infrastruktura_lokalna i ON ST_DWithin(s.wkb_geometry, i.wkb_geometry, s.max_val * 1.5)
    WHERE (s.max_val * 1.5) > ST_Distance(s.wkb_geometry, i.wkb_geometry) AND s.max_val > 0
)
-- Agregacja i unifikacja geometrii dla poprawy czytelności produktu informacyjnego
SELECT 
    ROW_NUMBER() OVER () AS id_qgis,
    ST_Multi(ST_UnaryUnion(ST_Collect(geom_strefy)))::geometry(MultiPolygon, 2180) AS wkb_geometry
FROM strefy_bazowe;

-- KROK 3: Budowa indeksu przestrzennego dla zapewnienia wydajności analiz statystycznych
CREATE INDEX idx_strefy_zagr_drzew_geom ON analityka.L_strefy_zagrozenia_upadkiem_drzew USING GIST(wkb_geometry);


---------------------------------------------------------------------------------------------------------------------------------------
-- Zapytanie SQL nr 4: Generowanie siatki heksagonalnej (HexGrid 15m)
---------------------------------------------------------------------------------------------------------------------------------------
-- Cel analityczny: Stworzenie stałej, geometrycznej bazy odniesienia dla analiz porównawczych (Change Detection 2012-2025). 
-- Wynik:           Tabela pomocnicza (tymczasowa), umożliwiająca porónanie danych z lat 2012 i 2025. 

-- KROK 1: Czyszczenie starej wersji siatki
DROP TABLE IF EXISTS temporary.L_siatka_heksagonalna_15m CASCADE;

-- KROK 2: Generowanie siatki heksagonalnej o boku 15m dla obszaru badań
CREATE TABLE temporary.L_siatka_heksagonalna_15m AS
SELECT 
    ROW_NUMBER() OVER() AS id_qgis,
    grid.geom::geometry(Polygon, 2180) AS wkb_geometry
FROM (
    -- Wyznaczenie zasięgu na podstawie tabeli segmentów i generowanie siatki
    SELECT ST_HexagonGrid(
        15, 
        ST_SetSRID(ST_Extent(wkb_geometry), 2180) -- Wymuszenie SRID 2180 dla zasięgu
    ) AS grid_obj
    FROM raw.segments_2025
) sub,
LATERAL (SELECT (grid_obj).*) grid; -- Rozpakowanie rekordu funkcji do kolumn

-- KROK 3: Budowa indeksu przestrzennego dla zapewnienia wydajności analiz statystycznych
CREATE INDEX idx_hexgrid_15m_geom ON temporary.L_siatka_heksagonalna_15m USING GIST(wkb_geometry);


---------------------------------------------------------------------------------------------------------------------------------------
-- Zapytanie SQL nr 4b: Agregacja statystyk inwentaryzacyjnych do siatki odniesienia (2025)
---------------------------------------------------------------------------------------------------------------------------------------
-- Cel analityczny: Podsumowanie cech biometrycznych drzewostanu (wysokość max, średnia, zagęszczenie) na podstawie danych z roku 2025.
-- Metoda:          Agregacja przestrzenna (Spatial Join) segmentów AI wykrytych w gęstym nalocie LiDAR (15 pkt/m2) do stałych oczek 
--                  siatki heksagonalnej. 
-- Wynik:           Warstwa heksagonalna (heatmapa) stanowiąca aktualny (2025 r.) obraz struktury wysokościowej lasu.

-- KROK 1: Czyszczenie starej wersji heatmapy
DROP TABLE IF EXISTS analityka.L_heatmapa_2025 CASCADE;

-- KROK 2: Generowanie siatki z zagregowanymi statystykami wysokościowymi i ilościowymi
CREATE TABLE analityka.L_heatmapa_2025 AS
SELECT 
    h.id_qgis AS hex_id,
    h.wkb_geometry,
    -- Statystyka ilościowa: liczba wykrytych koron drzew w oczku 15m
    COUNT(s.ogc_fid) AS liczba_drzew,
    -- Statystyka pionowa: średnia i maksymalna wysokość koron [m]
    AVG(s.max_val) AS srednia_wysokosc,
    MAX(s.max_val) AS max_wysokosc_w_strefie
FROM temporary.L_siatka_heksagonalna_15m h
JOIN raw.segments_2025 s ON ST_Intersects(h.wkb_geometry, s.wkb_geometry)
WHERE s.max_val > 0 AND s.max_val < 60 -- Eliminacja błędów instrumentalnych i NoData
GROUP BY h.id_qgis, h.wkb_geometry;

-- KROK 3: Budowa indeksu przestrzennego dla zapewnienia wydajności wizualizacji i analiz porównawczych
CREATE INDEX idx_heatmapa_2025_geom ON analityka.L_heatmapa_2025 USING GIST(wkb_geometry);


---------------------------------------------------------------------------------------------------------------------------------------
-- Zapytanie SQL nr 5: Modelowanie intensywności zagrożenia (Analiza statystyczna na siatce 15m)
---------------------------------------------------------------------------------------------------------------------------------------
-- Cel biznesowy: Identyfikacja miejsc o najwyższym skumulowanym potencjale szkód. 
-- Metoda:        Agregacja danych o drzewach zagrażających do stałej siatki odniesienia (oczka 15m). 
--                Wyznaczenie statystyk wysokościowych (MAX, AVG) oraz zagęszczenia punktowych źródeł ryzyka.
-- Wynik:         Tabela heksagonalna stanowiąca bazę dla gradientowej mapy ryzyka.

DROP TABLE IF EXISTS analityka.L_intensywnosc_zagrozen_siatka CASCADE;

CREATE TABLE analityka.L_intensywnosc_zagrozen_siatka AS
SELECT 
    h.id_qgis,
    -- Statystyka MAX: Najwyższe drzewo celujące w dany obszar (potencjał uderzenia)
    MAX(z.wysokosc_m) AS max_h_zagrozenia,
    -- Statystyka AVG: Średnia wysokość wszystkich drzew zagrażających temu punktowi
    ROUND(AVG(z.wysokosc_m)::numeric, 2) AS avg_h_zagrozenia,
    -- Statystyka COUNT: Liczba pni, których zasięg upadku obejmuje dane oczko siatki
    COUNT(z.segment_id) AS zagęszczenie_pni_zgr,
    h.wkb_geometry
FROM temporary.L_siatka_heksagonalna_15m h
-- Łączymy siatkę z warstwą drzew zidentyfikowanych w Zapytaniu nr 2
JOIN analityka.L_drzewa_zagrazajace z ON ST_Intersects(h.wkb_geometry, z.wkb_geometry)
GROUP BY h.id_qgis, h.wkb_geometry;

-- Budowa indeksu przestrzennego dla zapewnienia wydajności przy wizualizacji i docięciu
CREATE INDEX idx_intens_siatka_geom ON analityka.L_intensywnosc_zagrozen_siatka USING GIST(wkb_geometry);



---------------------------------------------------------------------------------------------------------------------------------------
-- Zapytanie SQL nr 6 Ocena skali zagrożeń w wydzieleniach leśnych 
---------------------------------------------------------------------------------------------------------------------------------------
-- Cel biznesowy: Identyfikacja jednostek leśnych charakteryzujących się najwyższym potencjałem szkód dla infrastruktury. 
--                Przyjęto założenie, że wysokość drzewa jest bezpośrednim wskaźnikiem zagrożenia.
-- Metoda:        Agregacja przestrzenna (Spatial Join) wyselekcjonowanych segmentów zagrożenia (H*1.5 > D) do oficjalnych 
--                granic wydzieleń BDL.
-- Wynik:         Tabela poligonowa umożliwiająca klasyfikację wydzieleń o zwiększonym ryzyku.

DROP TABLE IF EXISTS analityka.L_skala_zagrozen_wydzielenia CASCADE;

CREATE TABLE analityka.L_skala_zagrozen_wydzielenia AS
SELECT 
    ROW_NUMBER() OVER () AS id_qgis,
    w.adr_les AS adres_lesny,
    w.gat_pan AS gatunek,
    -- KLUCZOWE PARAMETRY: Energia potencjalna zagrożenia
    MAX(s.wysokosc_m) AS maksymalna_wysokosc_segmentow,
    ROUND(AVG(s.wysokosc_m)::numeric, 2) AS srednia_wysokosc_segmentow,
    -- Dane pomocnicze: Liczba pni i zagęszczenie
    COUNT(s.segment_id) AS liczba_pni_zgrazajacych,
    ROUND(
        (COUNT(s.segment_id) / (ST_Area(w.wkb_geometry) / 10000))::numeric, 2
    ) AS zageszczenie_zgrozen_na_1ha,
    ST_Multi(w.wkb_geometry)::geometry(MultiPolygon, 2180) AS wkb_geometry
FROM raw.wydzielenia w
JOIN analityka.L_drzewa_zagrazajace s ON ST_Intersects(w.wkb_geometry, s.wkb_geometry)
GROUP BY w.adr_les, w.gat_pan, w.wkb_geometry
-- Sortowanie priorytetowe według wysokości (im wyższe drzewa, tym wyżej w rankingu)
ORDER BY maksymalna_wysokosc_segmentow DESC, srednia_wysokosc_segmentow DESC;

CREATE INDEX idx_skala_zagr_wydz_geom ON analityka.L_skala_zagrozen_wydzielenia USING GIST(wkb_geometry);




--NIEAKTUALNE, ODBIEGAJACE OD TEMATYKI BEZPIECZENSTWA, CIAGLE BARDZO FAJNE ANALTYCZNIE (DELTY WYSOKOSCI 2025-2021, OBSERWACJA DYNAMIKI ZMIAN UDZALU WYSOKOSCIOWEGO/POWIERZHNIOWEGO GATUNKÓW W DRZEWOSTANIE)

-- ---------------------------------------------------------------------------------------------------------------------------------------
-- -- Zapytanie SQL nr 4a: Agregacja statystyk wysokościowych 2012 do siatki
-- ---------------------------------------------------------------------------------------------------------------------------------------
-- DROP TABLE IF EXISTS analityka.L_heatmapa_2012 CASCADE;

-- CREATE TABLE analityka.L_heatmapa_2012 AS
-- SELECT 
--     h.id_qgis AS hex_id,
--     h.wkb_geometry,
--     COUNT(s.ogc_fid) AS liczba_drzew,
--     AVG(s.max_val) AS srednia_wysokosc,
--     MAX(s.max_val) AS max_wysokosc_w_strefie
-- FROM temporary.L_siatka_heksagonalna_15m h
-- JOIN raw.segments_2012 s ON ST_Intersects(h.wkb_geometry, s.wkb_geometry)
-- WHERE s.max_val > 0 AND s.max_val < 60 -- Filtr błędów
-- GROUP BY h.id_qgis, h.wkb_geometry;


-- ---------------------------------------------------------------------------------------------------------------------------------------
-- -- Zapytanie SQL nr 5: Analiza dynamiki zmian cech drzewostanu (Change Detection 2012-2025)
-- ---------------------------------------------------------------------------------------------------------------------------------------
-- -- Cel analityczny: Monitoring procesów zachodzących w lesie. Identyfikacja obszarów wzrostu oraz ubytków.
-- -- Metodyka:        Analiza różnicowa wysokości maksymalnej (czubki) oraz średniej (zwarcie korony). 
-- --                  Zastosowanie H_avg pozwala na wykrycie degradacji struktury lasu (luk), których sam parametr H_max nie wyłapuje.
-- -- Wynik:           Fizyczna tabela heksagonalna z klasyfikacją uwzględniającą rozpad drzewostanu i wycinki.

-- -- KROK 1: Czyszczenie starej wersji analizy zmian
-- DROP TABLE IF EXISTS analityka.L_dynamika_zmian_wysokosci_drzewostanu CASCADE;

-- -- KROK 2: Wyliczenie różnic wysokości i klasyfikacja statusu zmiany (Logika H_max + H_avg)
-- CREATE TABLE analityka.L_dynamika_zmian_wysokosci_drzewostanu AS
-- WITH roznica_statystyczna AS (
--     SELECT 
--         h12.hex_id,
--         h12.wkb_geometry,
--         -- Delta wysokości maksymalnej (zmiana czubków)
--         (h25.max_wysokosc_w_strefie - h12.max_wysokosc_w_strefie) AS delta_h_max,
--         -- Delta wysokości średniej (wskaźnik zwarcia/luk)
--         (h25.srednia_wysokosc - h12.srednia_wysokosc) AS delta_h_avg,
--         -- Różnica liczby wykrytych segmentów
--         (h25.liczba_drzew - h12.liczba_drzew) AS delta_liczba_drzew
--     FROM analityka.L_heatmapa_2012 h12
--     JOIN analityka.L_heatmapa_2025 h25 ON h12.hex_id = h25.hex_id
--     WHERE h12.max_wysokosc_w_strefie > 0 AND h25.max_wysokosc_w_strefie > 0
-- )
-- SELECT 
--     ROW_NUMBER() OVER () AS id_qgis,
--     hex_id,
--     ROUND(delta_h_max::numeric, 2) AS przyrost_h_max_m,
--     ROUND(delta_h_avg::numeric, 2) AS przyrost_h_avg_m,
--     delta_liczba_drzew AS zmiana_liczby_drzew,
--     -- Jeśli średnia wysokość spadła o więcej niż 2m, mamy do czynienia z ubytkiem/lukami (czarne plamy na CHM)
--     -- Nawet jeśli czubek (h_max) urósł, spadek średniej oznacza, że las się "przerzedził".
--     CASE 
--         WHEN delta_h_avg < -2.0 THEN 'Ubytek'
--         WHEN delta_h_max > 2.0 AND delta_h_avg > -0.5 THEN 'Wzrost'
--         ELSE 'Stabilizacja'
--     END AS status_zmiany,
--     wkb_geometry::geometry(Polygon, 2180) AS wkb_geometry
-- FROM roznica_statystyczna;

-- -- KROK 3: Budowa indeksu przestrzennego dla zapewnienia wydajności analiz statystycznych
-- CREATE INDEX idx_dynamika_zmian_h_geom ON analityka.L_dynamika_zmian_wysokosci_drzewostanu USING GIST(wkb_geometry);



-- ---------------------------------------------------------------------------------------------------------------------------------------
-- -- Zapytanie SQL nr 6: Bilans powierzchniowy ubytków i przyrostów koron (Analiza na segmentach AI)
-- ---------------------------------------------------------------------------------------------------------------------------------------
-- -- Cel biznesowy: Precyzyjne określenie zmiany zwarcia lasu poprzez sumowanie powierzchni (area) wszystkich 
-- --                wykrytych segmentów drzew w latach 2012 i 2025 w granicach wydzieleń BDL.
-- -- Interpretacja: Wynik bezpośrednio wskazuje wydzielenia, w których las fizycznie "zniknął".

-- -- KROK 1: Czyszczenie starej wersji analizy zmian
-- DROP TABLE IF EXISTS analityka.L_zmiana_segmentow_w_wydzieleniach CASCADE;

-- -- KROK 2: Wyliczenie różnic w powierzchniach segmnetów w obrębie wydzieleń dla lat 2012-2025
-- CREATE TABLE analityka.L_zmiana_segmentow_w_wydzieleniach AS
-- WITH pow_2012 AS (
--     SELECT w.adr_les, SUM(s.area) as suma_area_2012
--     FROM raw.wydzielenia w
--     JOIN raw.segments_2012 s ON ST_Intersects(w.wkb_geometry, s.wkb_geometry)
--     GROUP BY w.adr_les
-- ),
-- pow_2025 AS (
--     SELECT w.adr_les, SUM(s.area) as suma_area_2025, AVG(s.max_val) as avg_h_max_2025
--     FROM raw.wydzielenia w
--     JOIN raw.segments_2025 s ON ST_Intersects(w.wkb_geometry, s.wkb_geometry)
--     GROUP BY w.adr_les
-- )
-- SELECT 
--     ROW_NUMBER() OVER () AS id_qgis,
--     w.adr_les AS adres_lesny,
--     w.gat_pan AS gatunek,
--     ROUND(p12.suma_area_2012::numeric, 0) AS pow_koron_2012_m2,
--     ROUND(p25.suma_area_2025::numeric, 0) AS pow_koron_2025_m2,
--     -- Różnica powierzchni koron w m2
--     ROUND((p25.suma_area_2025 - p12.suma_area_2012)::numeric, 0) AS zmiana_powierzchni_m2,
--     -- Procentowa zmiana zwarcia (ile % lasu ubyło/przyrosło)
--     ROUND(((p25.suma_area_2025 - p12.suma_area_2012) / NULLIF(p12.suma_area_2012, 0) * 100)::numeric, 1) AS procentowa_zmiana_zwarcia,
--     ST_Multi(w.wkb_geometry)::geometry(MultiPolygon, 2180) AS wkb_geometry
-- FROM raw.wydzielenia w
-- LEFT JOIN pow_2012 p12 ON w.adr_les = p12.adr_les
-- LEFT JOIN pow_2025 p25 ON w.adr_les = p25.adr_les
-- WHERE p12.suma_area_2012 IS NOT NULL OR p25.suma_area_2025 IS NOT NULL;

-- -- KROK 3: Budowa indeksu przestrzennego dla zapewnienia wydajności analiz statystycznych
-- CREATE INDEX idx_pow_zmiana_geom ON analityka.L_zmiana_segmentow_w_wydzieleniach USING GIST(wkb_geometry);