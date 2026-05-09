---------------------------------------------------------------------------------------------------------------------------------------
-- Zapytanie SQL nr 7: Statystyczne zestawienie skali zagrożeń według kategorii infrastruktury
---------------------------------------------------------------------------------------------------------------------------------------
-- Cel biznesowy:  Uzyskanie zbiorczej informacji o liczbie incydentów (H > D) dla każdej klasy obiektów.
-- Metoda:         Wykorzystanie funkcji unnest na przygotowanej wcześniej kolumnie 'lista_zagrozen'. Pozwala to na policzenie 
--                 każdego wystąpienia zagrożenia, nawet jeśli jedno drzewo zagraża kilku różnym typom obiektów.
-- Wynik:          Tabela statystyczna: kategoria obiektu vs liczba stwierdzonych zagrożeń.

WITH zagrozenia AS (
    -- Rozbijamy listę tekstową (np. "Droga, Szl_L") na osobne wiersze
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

-- Zestawienie statystyczne wykazuje, że największe ryzyko kolizji z drzewostanem dotyczy dróg publicznych (12 343 incydenty) oraz tras generowanych przez użytkowników w aplikacji Strava (11 933). Kluczowym wnioskiem jest fakt, że liczba zagrożeń dla tras Strava jest niemal identyczna jak dla dróg asfaltowych. Oficjalne szlaki liniowe (Szl_L) generują znacznie mniejszą liczbę kolizji (7 455)iska liczba zagrożeń dla budynków (367) 


---------------------------------------------------------------------------------------------------------------------------------------
-- Zapytanie SQL nr 8: Analiza powierzchniowa stref zagrożenia upadkiem drzew
---------------------------------------------------------------------------------------------------------------------------------------
-- Cel biznesowy: Określenie skali przestrzennej zagrożenia poprzez obliczenie sumarycznej powierzchni obszarów kolizyjnych.
-- Interpretacja: Wynik pozwala ocenić, jak duża część uroczyska (w ujęciu obszarowym) znajduje się w strefie ryzyka.

WITH pow_zagrozenia AS (
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
-- Zapytanie SQL nr 9: Analiza kondycji gatunkowej na podstawie bilansu powierzchniowego koron (2012-2025)
---------------------------------------------------------------------------------------------------------------------------------------
-- Cel biznesowy: Identyfikacja gatunków drzew tracących największą masę powierzchniową (użytkowanie rębne, zamieranie).
-- Interpretacja: Zestawienie pozwala ocenić realną skalę regresji gatunków. Wskaźnik procentowy (avg_proc_zmiana_zwarcia) 
--                jest odporny na różną wielkość wydzieleń i precyzyjnie wskazuje, które drzewostany znikają z mapy.

SELECT 
    gatunek,
    COUNT(*) AS liczba_wydzielen,
    -- Średni ubytek/przyrost powierzchni koron na 1 wydzielenie [m2]
    ROUND(AVG(zmiana_powierzchni_m2)::numeric, 1) AS avg_zmiana_pow_m2,
    -- KLUCZOWY WSKAŹNIK: Średnia procentowa zmiana zwarcia (miara kondycji gatunku)
    ROUND(AVG(procentowa_zmiana_zwarcia)::numeric, 1) AS avg_proc_zmiana_zwarcia,
    -- Sumaryczny bilans powierzchniowy dla całego gatunku [ha]
    ROUND((SUM(zmiana_powierzchni_m2) / 10000)::numeric, 2) AS suma_bilans_gatunku_ha
FROM analityka.L_zmiana_segmentow_w_wydzieleniach
GROUP BY gatunek
ORDER BY avg_proc_zmiana_zwarcia ASC; -- Gatunki najbardziej "zmasakrowane" na górze

-- Analiza powierzchniowa (area) segmentów AI ostatecznie zweryfikowała procesy zachodzące w Uroczysku Las Miejski. Najważniejszym wynikiem jest wykazanie ubytku ponad 12 hektarów powierzchni koron świerka, co przy spadku zwarcia o 10% dokumentuje skalę rozpadu tego gatunku. Jednocześnie dane potwierdziły skuteczność zabiegów pielęgnacyjnych w drzewostanach dębowych (wzrost powierzchni koron o 9.2% przy jednoczesnym obniżeniu wysokości średniej). Wyniki te dowodzą, że w analizie Change Detection parametr powierzchniowy jest znacznie bardziej miarodajny niż parametry wysokościowe, które mogą maskować realną degradację biomasy lasu
