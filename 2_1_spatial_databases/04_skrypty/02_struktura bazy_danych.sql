-- Będą tutaj składowane definicje typu indeksy (zwykłe i przestrzenne)


---------------------------------------------------------------------------------------------------------------------------------------
-- Utworzenie indeksów przestrzennych dla danych w schemacie raw, który jest w pełni dostępny tylko dla użytkownika administracyjnego postgres
---------------------------------------------------------------------------------------------------------------------------------------

-- 1. bdot10k_budynki
CREATE INDEX IF NOT EXISTS idx_raw_bdot10k_budynki_geom
ON raw.bdot10k_budynki USING GIST (wkb_geometry);

-- 2. bdot10k_drogi
CREATE INDEX IF NOT EXISTS idx_raw_bdot10k_drogi_geom
ON raw.bdot10k_drogi USING GIST (wkb_geometry);

-- 3. bdot10k_sciezki
CREATE INDEX IF NOT EXISTS idx_raw_bdot10k_sciezki_geom
ON raw.bdot10k_sciezki USING GIST (wkb_geometry);

-- 4. bdot10k_torykolejowe
CREATE INDEX IF NOT EXISTS idx_raw_bdot10k_torykolejowe_geom
ON raw.bdot10k_torykolejowe USING GIST (wkb_geometry);

-- 5. granica_nadlesnictwa
CREATE INDEX IF NOT EXISTS idx_raw_granica_nadlesnictwa_geom
ON raw.granica_nadlesnictwa USING GIST (wkb_geometry);

-- 6. lesnictwa (używa kolumny 'geom')
CREATE INDEX IF NOT EXISTS idx_raw_lesnictwa_geom
ON raw.lesnictwa USING GIST (wkb_geometry);

-- 7. oddzialy
CREATE INDEX IF NOT EXISTS idx_raw_oddzialy_geom
ON raw.oddzialy USING GIST (wkb_geometry);

-- 8. pomiary (SRID 4326 - WGS84)
CREATE INDEX IF NOT EXISTS idx_raw_pomiary_geom
ON raw.pomiary USING GIST (wkb_geometry);

-- 9. segments_2025
CREATE INDEX IF NOT EXISTS idx_raw_segments_2025_geom
ON raw.segments_2025 USING GIST (wkb_geometry);

-- 10. strava
CREATE INDEX IF NOT EXISTS idx_raw_strava_geom
ON raw.strava USING GIST (wkb_geometry);

-- 11. turystyka_liniowa
CREATE INDEX IF NOT EXISTS idx_raw_turystyka_liniowa_geom
ON raw.turystyka_liniowa USING GIST (wkb_geometry);

-- 12. turystyka_punktowa
CREATE INDEX IF NOT EXISTS idx_raw_turystyka_punktowa_geom
ON raw.turystyka_punktowa USING GIST (wkb_geometry);

-- 13. wydzielenia
CREATE INDEX IF NOT EXISTS idx_raw_wydzielenia_geom
ON raw.wydzielenia USING GIST (wkb_geometry);


---------------------------------------------------------------------------------------------------------------------------------------
-- Indeksy B-tree na kolumnach adresów leśnych (przyspieszają JOIN-y po adr_les)
---------------------------------------------------------------------------------------------------------------------------------------

CREATE INDEX IF NOT EXISTS idx_raw_granica_nadlesnictwa_adr_les
ON raw.granica_nadlesnictwa (adr_les);

CREATE INDEX IF NOT EXISTS idx_raw_oddzialy_adr_les
ON raw.oddzialy (adr_les);

-- Najpierw drop, na wypadek gdyby z poprzedniego runa został zwykły (nie-unikalny) indeks.
-- Bez tego CREATE UNIQUE INDEX IF NOT EXISTS nie zadziała (zobaczy istniejący nieunikalny i pominie).
DROP INDEX IF EXISTS raw.idx_raw_wydzielenia_adr_les;
CREATE UNIQUE INDEX idx_raw_wydzielenia_adr_les
ON raw.wydzielenia (adr_les);

CREATE unique INDEX IF NOT EXISTS idx_raw_raport_z_wysokosciami_adres_lesny
ON raw.raport_z_wysokosciami ("Adres leśny");


-- Opcjonalnie: Przeliczenie statystyk bazy po założeniu indeksów
VACUUM ANALYZE raw.bdot10k_budynki;
VACUUM ANALYZE raw.bdot10k_drogi;
VACUUM ANALYZE raw.bdot10k_sciezki;
VACUUM ANALYZE raw.bdot10k_torykolejowe;
VACUUM ANALYZE raw.granica_nadlesnictwa;
VACUUM ANALYZE raw.lesnictwa;
VACUUM ANALYZE raw.oddzialy;
VACUUM ANALYZE raw.pomiary;
VACUUM ANALYZE raw.raport_z_wysokosciami;
VACUUM ANALYZE raw.segments_2025;
VACUUM ANALYZE raw.strava;
VACUUM ANALYZE raw.turystyka_liniowa;
VACUUM ANALYZE raw.turystyka_punktowa;
VACUUM ANALYZE raw.wydzielenia;

-- stworzenie klucza obcego dla tabeli z wysokościami
ALTER TABLE raw.raport_z_wysokosciami
ADD CONSTRAINT fk_raport_wydzielenia_adr_les
FOREIGN KEY ("Adres leśny")
REFERENCES raw.wydzielenia (adr_les);
