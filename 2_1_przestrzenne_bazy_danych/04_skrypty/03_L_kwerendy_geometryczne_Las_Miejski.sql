---------------------------------------------------------------------------------------------------------------------------------------
-- Zapytanie SQL nr 7: Statystyczne zestawienie skali zagrożeń według kategorii infrastruktury
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

-- Zestawienie statystyczne wykazuje, że największe ryzyko kolizji z drzewostanem dotyczy dróg publicznych (12 343 incydenty) oraz tras generowanych przez użytkowników w aplikacji Strava (11 933). Szlaki liniowe (Szl_L) generują znacznie mniejszą liczbę kolizji (7 455), stwierdzona zotała niska liczba zagrożeń dla budynków (367) 


---------------------------------------------------------------------------------------------------------------------------------------
-- Zapytanie SQL nr 8: Analiza powierzchniowa stref zagrożenia upadkiem drzew
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
-- Zapytanie SQL nr 9: Ranking wydzieleń leśnych o najwyższym profilu zagrożenia (Zestawienie raportowe)
---------------------------------------------------------------------------------------------------------------------------------------
-- Cel biznesowy: Wyłonienie priorytetowych jednostek do kontroli terenowej. 
-- Założenie:     Główne przyjęte kryteria dot, zagożenia to maksymalna oraz średnia wysokość drzew spałeniająych warunek (D < 1.5 * H)

SELECT 
    adres_lesny,
    gatunek,
    maksymalna_wysokosc_segmentow AS h_max_m,
    srednia_wysokosc_segmentow AS h_avg_m,
    liczba_pni_zgrazajacych AS liczba_sztuk_do_wycinki,
    zageszczenie_zgrozen_na_1ha AS zgr_na_hektar
FROM analityka.L_skala_zagrozen_wydzielenia
-- Filtrujemy tylko te jednostki, w których faktycznie stwierdzono zagrożenia
WHERE liczba_pni_zgrazajacych > 0
-- Sortowanie priorytetowe: od drzew najwyższych (najgroźniejszych)
ORDER BY maksymalna_wysokosc_segmentow DESC, srednia_wysokosc_segmentow DESC
LIMIT 10;





--NIEAKTUALNE, ODBIEGAJACE OD TEMATYKI BEZPIECZENSTWA, CIAGLE BARDZO FAJNE ANALTYCZNIE (DELTY WYSOKOSCI 2025-2021, OBSERWACJA DYNAMIKI ZMIAN UDZALU WYSOKOSCIOWEGO/POWIERZHNIOWEGO GATUNKÓW W DRZEWOSTANIE)

-- ---------------------------------------------------------------------------------------------------------------------------------------
-- -- Zapytanie SQL nr 9: Analiza kondycji gatunkowej na podstawie bilansu powierzchniowego koron (2012-2025)
-- ---------------------------------------------------------------------------------------------------------------------------------------
-- -- Cel biznesowy: Identyfikacja gatunków drzew tracących największą masę powierzchniową (użytkowanie rębne, zamieranie).
-- -- Interpretacja: Zestawienie pozwala ocenić realną skalę regresji i przyrostu gatunków.

-- SELECT 
--     gatunek,
--     COUNT(*) AS liczba_wydzielen,
--     -- Średni ubytek/przyrost powierzchni koron na 1 wydzielenie [m2]
--     ROUND(AVG(zmiana_powierzchni_m2)::numeric, 1) AS srednia_zmiana_powierzchni_m2,
--     -- Średnia procentowa zmiana zwarcia
--     ROUND(AVG(procentowa_zmiana_zwarcia)::numeric, 1) AS srednia_procentowa_zmiana_zwarcia,
--     -- Sumaryczny bilans powierzchniowy dla całego gatunku [ha]
--     ROUND((SUM(zmiana_powierzchni_m2) / 10000)::numeric, 2) AS zmiana_powierzchni_ha
-- FROM analityka.L_zmiana_segmentow_w_wydzieleniach
-- GROUP BY gatunek
-- ORDER BY srednia_procentowa_zmiana_zwarcia ASC;

-- -- Analiza wykazała drastyczny ubytek powierzchni koron świerka (łącznie o 12,35 ha) oraz dębu szypułkowego (spadek zwarcia o 30,3%), co stanowi statystyczne potwierdzenie masowego zamierania drzewostanów iglastych oraz intensywnej gospodarki rębnej widocznej na modelach CHM. Równocześnie zidentyfikowano pozytywny wpływ zabiegów pielęgnacyjnych w dojrzałych drzewostanach dębowych, gdzie mimo usuwania pojedynczych sztuk, zwarcie koron wzrosło o 9,2% dzięki ekspansji bocznej ocalałych drzew dorodnych. Kluczowym wnioskiem merytorycznym jest wykazanie, że analiza bilansu powierzchniowego segmentów AI jest znacznie bardziej miarodajna niż statystyki wysokościowe, które poprzez wzrost czubków ocalałych pni maskowały realną skalę fragmentacji i ubytku biomasy lasu.

