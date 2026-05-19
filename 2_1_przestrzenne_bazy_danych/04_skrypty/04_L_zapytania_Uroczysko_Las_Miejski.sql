---------------------------------------------------------------------------------------------------------------------------------------
-- Zapytanie SQL nr 7: Przygotowanie zoptymalizowanej warstwy infrastruktury lokalnej (AOI Clipping).
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
-- Zapytanie SQL nr 8: Wytypowanie drzew zagrażających na podstawie wyników segmentacji CHM z 2025 roku.
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
    wkb_geometry::geometry(MultiPolygon, 2180) AS wkb_geometry
FROM wszystkie_kolizje
GROUP BY segment_id, wysokosc_m, wkb_geometry
-- Sortujemy od najbardziej "szkodliwych" drzew
ORDER BY liczba_zagrozonych_obiektow DESC, wysokosc_m DESC;

-- KROK 3: Budowa indeksu przestrzennego dla zapewnienia wydajności analiz statystycznych
CREATE INDEX idx_wynik_turystyka_geom ON analityka.L_drzewa_zagrazajace USING GIST(wkb_geometry);


---------------------------------------------------------------------------------------------------------------------------------------
-- Zapytanie SQL nr 9: Statystyczne zestawienie skali zagrożeń według kategorii infrastruktury
---------------------------------------------------------------------------------------------------------------------------------------
-- Cel biznesowy:  Uzyskanie zbiorczej informacji o liczbie incydentów (H > D) dla każdej klasy obiektów.
-- Metoda:         Wykorzystanie funkcji unnest na przygotowanej wcześniej kolumnie 'lista_zagrozen'. Pozwala to na policzenie 
--                 każdego wystąpienia zagrożenia, nawet jeśli jedno drzewo zagraża kilku różnym typom obiektów.
-- Wynik:          Tabela statystyczna: kategoria obiektu vs liczba stwierdzonych zagrożeń.

WITH zagrozenia AS (
    -- Rozbicie listę tekstową (np. "Droga, Szl_L") na osobne wiersze
    SELECT 
        trim(unnest(string_to_array(lista_zagrozen, ','))) AS kategoria_obiektu
    FROM analityka.L_drzewa_zagrazajace
)
SELECT 
    kategoria_obiektu,
    COUNT(*) AS liczba_zagrozen
FROM zagrozenia
GROUP BY kategoria_obiektu
ORDER BY liczba_zagrozen DESC;


---------------------------------------------------------------------------------------------------------------------------------------
-- Zapytanie SQL nr 10: Modelowanie geometrycznych stref zagrożenia upadkiem drzew
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
-- Zapytanie SQL nr 11: Analiza powierzchniowa stref zagrożenia upadkiem drzew
---------------------------------------------------------------------------------------------------------------------------------------
-- Cel biznesowy: Określenie skali przestrzennej zagrożenia poprzez obliczenie sumarycznej powierzchni obszarów kolizyjnych.
-- Interpretacja: Wynik pozwala ocenić, jak duża część uroczyska (w ujęciu obszarowym) znajduje się w strefie ryzyka.

WITH 
pow_zagrozenia AS (
    -- Sumujemy powierzchnię wszystkich poligonów z tabeli stref
    SELECT SUM(ST_Area(wkb_geometry)) AS suma_m2
    FROM analityka.L_strefy_zagrozenia_upadkiem_drzew
),
pow_calkowita AS (
    -- Wyznaczamy całkowitą powierzchnię obszaru opracowania na podstawie zasięgu segmentów
    SELECT ST_Area(ST_ConvexHull(ST_Collect(wkb_geometry))) AS total_m2
    FROM raw.segments_2025
)
SELECT 
    ROUND(z.suma_m2::numeric, 2) AS pow_stref_m2,
    ROUND((z.suma_m2 / 10000)::numeric, 4) AS pow_stref_ha,
    ROUND((z.suma_m2 / c.total_m2 * 100)::numeric, 2) AS procent_powierzchni_lasu
FROM pow_zagrozenia z, pow_calkowita c;


---------------------------------------------------------------------------------------------------------------------------------------
-- Zapytanie SQL nr 12: Generowanie siatki heksagonalnej (HexGrid 15m)
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
-- Zapytanie SQL nr 13: Parametryzacja i inwentaryzacja statystyczna drzewostanu na bazie segmentów AI (stan na 2025 r.) w postaci heatmapy
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
-- Zapytanie SQL nr 14: Modelowanie natężenia ryzyka i identyfikacja stref zwiększonego ryzyka w postaci heatmapy
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
-- Zapytanie SQL nr 15 Ocena skali i gęstości zagrożeń w wydzieleniach leśnych (Analiza BDL)
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


---------------------------------------------------------------------------------------------------------------------------------------
-- Zapytanie SQL nr 16: Wykaz wydzieleń leśnych o najwyższym potencjalnym ryzyku wynikającym z dużej wysokości drzew.
---------------------------------------------------------------------------------------------------------------------------------------
-- Cel biznesowy: Wyłonienie priorytetowych jednostek do kontroli terenowej. 
-- Założenie:     Główne przyjęte kryteria dot, zagożenia to maksymalna oraz średnia wysokość drzew spałeniająych warunek (D < 1.5 * H)

SELECT 
    adres_lesny,
    gatunek,
    maksymalna_wysokosc_segmentow AS h_max_m,
    srednia_wysokosc_segmentow AS h_avg_m,
    liczba_pni_zgrazajacych AS liczba_sztuk_do_kontroli,
    zageszczenie_zgrozen_na_1ha AS zgr_na_hektar
FROM analityka.L_skala_zagrozen_wydzielenia
-- Filtrujemy tylko te jednostki, w których faktycznie stwierdzono zagrożenia
WHERE liczba_pni_zgrazajacych > 0
-- Sortowanie priorytetowe: od drzew najwyższych (najgroźniejszych)
ORDER BY maksymalna_wysokosc_segmentow DESC, srednia_wysokosc_segmentow DESC
LIMIT 10;


