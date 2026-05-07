
---------------------------------------------------------------------------------------------------------------------------------------
-- Zapytanie SQL nr 1: Przygotowanie zoptymalizowanej warstwy infrastruktury lokalnej (AOI)
---------------------------------------------------------------------------------------------------------------------------------------
-- Cel analityczny: Optymalizacja wydajnościowa poprzez ograniczenie zakresu przestrzennego analizy. Wykonanie obliczeń 
--                  dystansu dla pełnych warstw BDOT10k i Strava w skali całego Nadleśnictwa Giżycko przy tysiącach 
--                  segmentów drzew jest nieefektywne i obciążające dla silnika bazy danych.
-- Metoda:          Wyznaczenie prostokątnej obwiedni (Bounding Box) dla obszaru występowania drzew, a następnie zastosowanie funkcji 
--                  ST_Intersection w celu fizycznego docięcia liniowych i punktowych obiektów infrastruktury do tego obszaru.
-- Wynik:           Zindeksowana tabela tymczasowa, zawierająca wyłącznie istotne fragmenty infrastruktury w bezpośrednim sąsiedztwie wybranego
--                  fragmentu lasu. Zestaw plików poligonowych w schemacie temporary


-- KROK 1: Czyszczenie starej infrastruktury tymczasowej
DROP TABLE IF EXISTS temporary.L_infrastruktura_lokalna CASCADE;

-- KROK 2: Przygotowanie przyciętej i naprawionej infrastruktury w zasięgu analizy
CREATE TABLE temporary.L_infrastruktura_lokalna AS
-- CTE 1: Wyznaczenie prostokątnego obszaru drzew (AOI) z zapasem 100m
WITH aoi AS (
    SELECT ST_SetSRID(ST_Expand(ST_Extent(wkb_geometry), 100), 2180) AS maska 
    FROM raw.segmenty_dwa_rastry
)
-- CTE 2: Precyzyjne docięcie (ST_Intersection) obiektów infrastruktury do obszaru AOI
SELECT 'Budynek' AS typ, ST_Intersection(ST_MakeValid(t.wkb_geometry), a.maska) AS wkb_geometry FROM raw.bdot10k_budynki t, aoi a WHERE ST_Intersects(t.wkb_geometry, a.maska)
UNION ALL SELECT 'Droga', ST_Intersection(ST_MakeValid(t.wkb_geometry), a.maska) FROM raw.bdot10k_drogi t, aoi a WHERE ST_Intersects(t.wkb_geometry, a.maska)
UNION ALL SELECT 'Sciezka', ST_Intersection(ST_MakeValid(t.wkb_geometry), a.maska) FROM raw.bdot10k_sciezki t, aoi a WHERE ST_Intersects(t.wkb_geometry, a.maska)
UNION ALL SELECT 'Kolej', ST_Intersection(ST_MakeValid(t.wkb_geometry), a.maska) FROM raw.bdot10k_torykolejowe t, aoi a WHERE ST_Intersects(t.wkb_geometry, a.maska)
UNION ALL SELECT 'Szl_L', ST_Intersection(ST_MakeValid(t.wkb_geometry), a.maska) FROM raw.turystyka_liniowa t, aoi a WHERE ST_Intersects(t.wkb_geometry, a.maska)
UNION ALL SELECT 'Szl_P', ST_Intersection(ST_MakeValid(t.wkb_geometry), a.maska) FROM raw.turystyka_punktowa t, aoi a WHERE ST_Intersects(t.wkb_geometry, a.maska)
UNION ALL SELECT 'Strava', ST_Intersection(ST_MakeValid(t.wkb_geometry), a.maska) FROM raw.strava t, aoi a WHERE ST_Intersects(t.wkb_geometry, a.maska);

-- Budowa indeksu przestrzennego dla optymalizacji złączeń
CREATE INDEX idx_infra_local_geom ON temporary.L_infrastruktura_lokalna USING GIST(wkb_geometry);
ANALYZE temporary.L_infrastruktura_lokalna;


---------------------------------------------------------------------------------------------------------------------------------------
-- Zapytanie SQL nr 2: Identyfikacja drzew zagrażających infrastrukturze (Bufor bezpieczeństwa 1.5 * H > D)
---------------------------------------------------------------------------------------------------------------------------------------
-- Cel analityczny: Precyzyjne wytypowanie segmentów drzew, których wysokość wraz z przyjętym marginesem bezpieczeństwa (50%) 
--                  stwarza ryzyko dla ruchu turystycznego i infrastruktury.
-- Mechanizm:       Zastosowanie złączenia przestrzennego z dynamicznym buforem bezpieczeństwa. Warunek 1.5 * H > D pozwala na 
--                  wykrycie nie tylko drzew mogących upaść bezpośrednio na obiekt turystyczny.
-- Wynik:           Warstwa poligonowa "Drzewa zagrażające", zawierająca informację o typie zagrożonego obiektu oraz odległości.

-- KROK 1: Czyszczenie starej tabeli wynikowej
DROP TABLE IF EXISTS analityka.L_drzewa_zagrazajace CASCADE;

-- KROK 2: Selekcja unikalnych segmentów spełniających warunek zwiększonego zasięgu rażenia
CREATE TABLE analityka.L_drzewa_zagrazajace AS
SELECT DISTINCT ON (s.id)
    ROW_NUMBER() OVER () AS id_qgis, -- Unikalny klucz dla QGIS
    s.id AS segment_id,
    s.max_val AS wysokosc_m,
    i.typ AS zagrozenie_dla,
    ROUND(ST_Distance(s.wkb_geometry, i.wkb_geometry)::numeric, 2) AS dystans_m,
    ST_SetSRID(s.wkb_geometry, 2180)::geometry(MultiPolygon, 2180) AS wkb_geometry
FROM raw.segmenty_dwa_rastry s
-- ST_DWithin i WHERE uwzględniają teraz mnożnik 1.5 dla wysokości maksymalnej
JOIN temporary.L_infrastruktura_lokalna i ON ST_DWithin(s.wkb_geometry, i.wkb_geometry, s.max_val * 1.5)
WHERE ST_Distance(s.wkb_geometry, i.wkb_geometry) < (s.max_val * 1.5) 
  AND s.max_val > 0
ORDER BY s.id, ST_Distance(s.wkb_geometry, i.wkb_geometry) ASC;

-- KROK 3: Budowa indeksu przestrzennego dla warstwy wynikowej
CREATE INDEX idx_wynik_turystyka_geom ON analityka.L_drzewa_zagrazajace USING GIST(wkb_geometry);


---------------------------------------------------------------------------------------------------------------------------------------
-- Zapytanie SQL nr 3: Modelowanie geometrycznych stref zagrożenia upadkiem drzew
---------------------------------------------------------------------------------------------------------------------------------------
-- Cel analityczny: Wizualizacja realnego zasięgu rażenia drzewostanu ograniczonego wyłącznie do kierunku kolizyjnego. 
--                  (odejście od teoretycznych buforów kołowych na rzecz precyzyjnych korytarzy upadku).
-- Mechanizm:       Dla każdego drzewa zagrażającego tworzony jest poligon typu "klin" rozpięty między pniem a najbliższym punktem 
--                  na obiekcie infrastruktury. Zasięg klina uwzględnia margines bezpieczeństwa (1.5 * H). Zastosowanie funkcji 
--                  ST_UnaryUnion scala nachodzące na siebie kliny w jednolite, czytelne obszary operacyjne (Dissolve).
-- Wynik:           Fizyczna tabela poligonowa (MultiPolygon) stanowiąca gotowy podkład do planowania cięć bezpieczników przy szlakach.

-- KROK 1: Czyszczenie starej tabeli
DROP TABLE IF EXISTS analityka.L_strefy_zagrozenia_upadkiem_drzew CASCADE;

-- KROK 2: Generowanie stref poligonów zagrożenia i ich scalanie (Dissolve)
CREATE TABLE analityka.L_strefy_zagrozenia_upadkiem_drzew AS
WITH strefy_bazowe AS (
    SELECT 
        s.id,
        -- Budowa kierunkowego poligonu zagrożenia (trapezu) między drzewem a infrastrukturą lokalną
        ST_ConvexHull(
            ST_Collect(
                ARRAY[
                    s.wkb_geometry, 
                    ST_Buffer(ST_ClosestPoint(i.wkb_geometry, s.wkb_geometry), 5) -- 5m szerokości pasa rażenia na obiekcie
                ]
            )
        ) AS geom_strefy
    FROM raw.segmenty_dwa_rastry s
    JOIN temporary.L_infrastruktura_lokalna i ON ST_DWithin(s.wkb_geometry, i.wkb_geometry, s.max_val * 1.5)
    WHERE (s.max_val * 1.5) > ST_Distance(s.wkb_geometry, i.wkb_geometry) AND s.max_val > 0
)
-- Agregacja i unifikacja geometrii dla poprawy czytelności produktu informacyjnego
SELECT 
    ROW_NUMBER() OVER () AS id_qgis,
    ST_Multi(ST_UnaryUnion(ST_Collect(geom_strefy)))::geometry(MultiPolygon, 2180) AS wkb_geometry
FROM strefy_bazowe;

-- KROK 3: Budowa indeksu przestrzennego dla zapewnienia wydajności warstwy w systemie QGIS
CREATE INDEX idx_strefy_zagr_drzew_geom ON analityka.L_strefy_zagrozenia_upadkiem_drzew USING GIST(wkb_geometry);


---------------------------------------------------------------------------------------------------------------------------------------
-- Zapytanie SQL nr 4: Generowanie heksagonalnej (HexGrid 15m)
---------------------------------------------------------------------------------------------------------------------------------------
-- Cel analityczny: Stworzenie stałej, geometrycznej bazy odniesienia dla analiz porównawczych (Change Detection 2012-2025). 
-- Dlaczego:        Siatka heksagonalna jest optymalna statystycznie – minimalizuje błędy brzegowe (efekt narożnika) i pozwala na 
--                  obiektywną agregację statystyk z różnych nalotów LiDAR o różnej gęstości chmury punktów.
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
    FROM raw.segmenty_dwa_rastry
) sub,
LATERAL (SELECT (grid_obj).*) grid; -- Rozpakowanie rekordu funkcji do kolumn

-- KROK 3: Budowa indeksu przestrzennego dla zapewnienia wydajności analiz statystycznych
CREATE INDEX idx_hexgrid_15m_geom ON temporary.L_siatka_heksagonalna_15m USING GIST(wkb_geometry);


---------------------------------------------------------------------------------------------------------------------------------------
-- Zapytanie SQL nr 5: Analiza dynamiki zmian wysokości maksymalnej drzewostanu (Change Detection 2012-2025)
---------------------------------------------------------------------------------------------------------------------------------------
-- Cel analityczny: Monitoring procesów zachodzących w lesie w okresie 13 lat. Identyfikacja obszarów naturalnego wzrostu 
--                  oraz wykrycie nagłych ubytków wysokości wynikających z cięć rębnych lub procesów zamierania.
-- Metodyka:        Analiza oparta jest na różnicy wysokości maksymalnej (H_max). Wybór tego parametru (zamiast wysokości średniej) 
--                  pozwala na +/- obiektywne porównanie nalotów LiDAR o różnej gęstości (4 vs 15 pkt/m2).
-- Wynik:           Fizyczna tabela heksagonalna z klasyfikacją dynamiki zmian (Wzrost / Stabilizacja / Ubytek).

-- KROK 1: Czyszczenie starej wersji analizy zmian
DROP TABLE IF EXISTS analityka.L_dynamika_zmian_wysokosci_drzewostanu CASCADE;

-- KROK 2: Wyliczenie różnic wysokości i klasyfikacja statusu zmiany
CREATE TABLE analityka.L_dynamika_zmian_wysokosci_drzewostanu AS
WITH roznica_statystyczna AS (
    SELECT 
        h12.hex_id,
        h12.geom,
        -- Różnica wysokości maksymalnej (H_max 2025 - H_max 2012)
        (h25.max_wysokosc_w_strefie - h12.max_wysokosc_w_strefie) AS zmiana_h
    FROM analizy.heatmapa_2012 h12
    JOIN analizy.heatmapa_2025 h25 ON h12.hex_id = h25.hex_id
    WHERE h12.max_wysokosc_w_strefie > 0 AND h25.max_wysokosc_w_strefie > 0
)
SELECT 
    ROW_NUMBER() OVER () AS id_qgis, -- Unikalny identyfikator pod QGIS
    hex_id,
    ROUND(zmiana_h::numeric, 2) AS przyrost_h_max_m,
    -- Klasyfikacja stanu lasu na podstawie dynamiki wzrostu
    CASE 
        WHEN zmiana_h > 2 THEN 'Wzrost naturalny'
        WHEN zmiana_h < -5 THEN 'Ubytek / Wycinka'
        ELSE 'Stabilizacja'
    END AS status_zmiany,
    geom::geometry(Polygon, 2180) AS wkb_geometry
FROM roznica_statystyczna;

-- KROK 3: Budowa indeksu przestrzennego dla płynnej wizualizacji Change Detection
CREATE INDEX idx_dynamika_zmian_h_geom ON analityka.L_dynamika_zmian_wysokosci_drzewostanu USING GIST(wkb_geometry);


---------------------------------------------------------------------------------------------------------------------------------------
-- Zapytanie SQL nr 6: Agregacja dynamiki zmian drzewostanu do wydzieleń leśnych (Analiza BDL)
---------------------------------------------------------------------------------------------------------------------------------------
-- Cel analityczny: Transformacja wyników analizy czasowej (Change Detection) z poziomu siatki heksagonalnej do 
--                  oficjalnych wydzieleń leśnych. Umożliwia wsparcie procesów zarządczych i aktualizacji opisu taksacyjnego. 
--                  Ranking wydzieleń według      średniej 
--                  zmiany wysokości maksymalnej (H_max) pozwala na szybką identyfikację obszarów, w których nastąpiła 
--                  intensywna wycinka lub rozpad drzewostanu (np. w wyniku gradacji szkodników wtórnych).
-- Metoda:          Złączenie przestrzenne (Spatial Join) granic wydzieleń BDL z danymi statystycznymi z lat 2012 i 2025. 
--                  Parametr delty H_max pozwala na obiektywną ocenę zmian w górnym piętrze lasu.
-- Wynik:           Fizyczna tabela poligonowa w schemacie analityka, gotowa do wizualizacji kartograficznej przyrostów i ubytków.


-- KROK 1: Czyszczenie starej wersji agregacji
DROP TABLE IF EXISTS analityka.L_zmiana_wysokosci_wydzielenia CASCADE;

-- KROK 2: Agregacja różnic wysokościowych z siatki heksagonalnej do granic wydzieleń BDL
CREATE TABLE analityka.L_zmiana_wysokosci_wydzielenia AS
SELECT 
    ROW_NUMBER() OVER () AS id_qgis, -- Unikalny klucz dla QGIS
    w.adr_les AS adres_lesny,
    w.gat_pan AS gatunek_dominujacy,
    COUNT(h12.hex_id) AS liczba_probek_pomiarowych,
    -- Średnia zmiana wysokości maksymalnej w całym wydzieleniu [m]
    ROUND(AVG(h25.max_wysokosc_w_strefie - h12.max_wysokosc_w_strefie)::numeric, 2) AS srednia_zmiana_h_max_m,
    -- Identyfikacja najgłębszego punktowego ubytku (np. zrąb gniazdowy)
    MIN(h25.max_wysokosc_w_strefie - h12.max_wysokosc_w_strefie) AS maksymalny_ubytek_m,
    ST_Multi(w.wkb_geometry)::geometry(MultiPolygon, 2180) AS wkb_geometry
FROM raw.wydzielenia w
-- Dołączamy dane statystyczne z lat 2012 i 2025
JOIN analizy.heatmapa_2012 h12 ON ST_Intersects(w.wkb_geometry, h12.geom)
JOIN analizy.heatmapa_2025 h25 ON h12.hex_id = h25.hex_id
-- Omijamy obszary bez danych LiDAR (NoData)
WHERE h12.max_wysokosc_w_strefie > 0 AND h25.max_wysokosc_w_strefie > 0
GROUP BY w.adr_les, w.gat_pan, w.wkb_geometry
-- Wybieramy tylko wydzielenia z reprezentatywną liczbą próbek (min. 3 heksagony)
HAVING COUNT(h12.hex_id) >= 3
ORDER BY srednia_zmiana_h_max_m ASC;

-- KROK 3: Budowa indeksu przestrzennego dla warstwy wynikowej
CREATE INDEX idx_zmiana_wydz_bdl_geom ON analityka.L_zmiana_wysokosci_wydzielenia USING GIST(wkb_geometry);