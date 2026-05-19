-- TWORZENIE TABEL OBIEKTOW POTENCJALNIE ZAGROZONYCH WG ADRESU

-- ============================================================
-- USUWANIE TABEL WYNIKOWYCH I TYMCZASOWYCH PRZED PONOWNYM URUCHOMIENIEM
-- ============================================================

DROP TABLE IF EXISTS analityka.j_clip_turystyka_punktowa;
DROP TABLE IF EXISTS analityka.j_clip_strava;
DROP TABLE IF EXISTS analityka.j_clip_torykolejowe;
DROP TABLE IF EXISTS analityka.j_clip_sciezki;
DROP TABLE IF EXISTS analityka.j_clip_drogi;
DROP TABLE IF EXISTS analityka.j_clip_budynki;

DROP TABLE IF EXISTS analityka.bdot10k_torykolejowe_clip;
DROP TABLE IF EXISTS analityka.bdot10k_sciezki_clip;
DROP TABLE IF EXISTS analityka.bdot10k_drogi_clip;
DROP TABLE IF EXISTS analityka.bdot10k_budynki_clip;
DROP TABLE IF EXISTS analityka.wydzielenia_bufory;

-- ============================================================
-- BLOK 1: PRZYCINANIE WARSTW BDOT10k DO ZASIĘGU GRANICY NADLEŚNICTWA
-- ============================================================

DO $$
DECLARE
    granica GEOMETRY;
BEGIN
    SELECT ST_MakeValid(ST_Union(wkb_geometry)) INTO granica FROM raw.granica_nadlesnictwa;

    -- === TORY KOLEJOWE ===
    CREATE TABLE analityka.bdot10k_torykolejowe_clip AS
    SELECT * FROM (
        SELECT *,
            ST_CollectionExtract(
                ST_Intersection(
                    CASE WHEN ST_IsValid(wkb_geometry) THEN wkb_geometry ELSE ST_MakeValid(wkb_geometry) END,
                    granica
                ), 2) AS geom_clip
        FROM raw.bdot10k_torykolejowe
        WHERE wkb_geometry && granica
          AND ST_Intersects(wkb_geometry, granica)
    ) sub
    WHERE NOT ST_IsEmpty(geom_clip);

    -- === ŚCIEŻKI ===
    CREATE TABLE analityka.bdot10k_sciezki_clip AS
    SELECT * FROM (
        SELECT *,
            ST_CollectionExtract(
                ST_Intersection(
                    CASE WHEN ST_IsValid(wkb_geometry) THEN wkb_geometry ELSE ST_MakeValid(wkb_geometry) END,
                    granica
                ), 2) AS geom_clip
        FROM raw.bdot10k_sciezki
        WHERE wkb_geometry && granica
          AND ST_Intersects(wkb_geometry, granica)
    ) sub
    WHERE NOT ST_IsEmpty(geom_clip);

    -- === DROGI ===
    CREATE TABLE analityka.bdot10k_drogi_clip AS
    SELECT * FROM (
        SELECT *,
            ST_CollectionExtract(
                ST_Intersection(
                    CASE WHEN ST_IsValid(wkb_geometry) THEN wkb_geometry ELSE ST_MakeValid(wkb_geometry) END,
                    granica
                ), 2) AS geom_clip
        FROM raw.bdot10k_drogi
        WHERE wkb_geometry && granica
          AND ST_Intersects(wkb_geometry, granica)
    ) sub
    WHERE NOT ST_IsEmpty(geom_clip);

    -- === BUDYNKI ===
    CREATE TABLE analityka.bdot10k_budynki_clip AS
    SELECT * FROM (
        SELECT *,
            ST_CollectionExtract(
                ST_Intersection(
                    CASE WHEN ST_IsValid(wkb_geometry) THEN wkb_geometry ELSE ST_MakeValid(wkb_geometry) END,
                    granica
                ), 3) AS geom_clip
        FROM raw.bdot10k_budynki
        WHERE wkb_geometry && granica
          AND ST_Intersects(wkb_geometry, granica)
    ) sub
    WHERE NOT ST_IsEmpty(geom_clip);

END;
$$;

CREATE INDEX ON analityka.bdot10k_torykolejowe_clip USING GIST (geom_clip);
CREATE INDEX ON analityka.bdot10k_sciezki_clip      USING GIST (geom_clip);
CREATE INDEX ON analityka.bdot10k_drogi_clip        USING GIST (geom_clip);
CREATE INDEX ON analityka.bdot10k_budynki_clip      USING GIST (geom_clip);

-- ============================================================
-- BLOK 2: BUFORY NA PODSTAWIE WYSOKOŚCI Z RAPORTU
-- ============================================================

CREATE TABLE analityka.wydzielenia_bufory AS
SELECT
    w.adr_les,
    r."Wys",
    ST_Buffer(w.wkb_geometry, r."Wys" * 1.5) AS geom
FROM raw.wydzielenia w
INNER JOIN raw."raport_z_wysokosciami" r
    ON w.adr_les = r."Adres leśny"
WHERE r."Wys" IS NOT NULL;

CREATE INDEX ON analityka.wydzielenia_bufory USING GIST (geom);

-- ============================================================
-- BLOK 3: CZĘŚCI WSPÓLNE BUFORU Z WARSTWAMI
-- ============================================================

-- === TURYSTYKA PUNKTOWA ===
CREATE TABLE analityka.j_clip_turystyka_punktowa AS
SELECT
    row_number() OVER () AS id,
    ST_SetSRID(t.wkb_geometry, 2180) AS wkb_geometry,  -- renamed: geom → wkb_geometry
    trim(split_part(b.adr_les, '-', 4)) AS lesnictwo,
    trim(split_part(b.adr_les, '-', 5)) AS oddzial
FROM raw.turystyka_punktowa t
INNER JOIN analityka.wydzielenia_bufory b
    ON t.wkb_geometry && b.geom
   AND ST_Intersects(t.wkb_geometry, b.geom);

-- === TRASY STRAVA ===
CREATE TABLE analityka.j_clip_strava AS
SELECT row_number() OVER () AS id, wkb_geometry, lesnictwo, oddzial
FROM (
    SELECT
        ST_SetSRID(
            ST_CollectionExtract(
                ST_Union(ST_Intersection(t.wkb_geometry, b.geom)),
                2), 2180) AS wkb_geometry,              -- renamed: geom_clip → wkb_geometry
        trim(split_part(b.adr_les, '-', 4)) AS lesnictwo,
        trim(split_part(b.adr_les, '-', 5)) AS oddzial
    FROM raw.strava t
    INNER JOIN analityka.wydzielenia_bufory b
        ON t.wkb_geometry && b.geom
       AND ST_Intersects(t.wkb_geometry, b.geom)
    GROUP BY lesnictwo, oddzial
) sub;

-- === TORY KOLEJOWE ===
CREATE TABLE analityka.j_clip_torykolejowe AS
SELECT row_number() OVER () AS id, wkb_geometry, lesnictwo, oddzial
FROM (
    SELECT
        ST_SetSRID(
            ST_CollectionExtract(
                ST_Union(ST_Intersection(t.geom_clip, b.geom)),
                2), 2180) AS wkb_geometry,              -- renamed: geom_clip → wkb_geometry
        trim(split_part(b.adr_les, '-', 4)) AS lesnictwo,
        trim(split_part(b.adr_les, '-', 5)) AS oddzial
    FROM analityka.bdot10k_torykolejowe_clip t
    INNER JOIN analityka.wydzielenia_bufory b
        ON t.geom_clip && b.geom
       AND ST_Intersects(t.geom_clip, b.geom)
    GROUP BY lesnictwo, oddzial
) sub;

-- === ŚCIEŻKI ===
CREATE TABLE analityka.j_clip_sciezki AS
SELECT row_number() OVER () AS id, wkb_geometry, lesnictwo, oddzial
FROM (
    SELECT
        ST_SetSRID(
            ST_CollectionExtract(
                ST_Union(ST_Intersection(t.geom_clip, b.geom)),
                2), 2180) AS wkb_geometry,              -- renamed: geom_clip → wkb_geometry
        trim(split_part(b.adr_les, '-', 4)) AS lesnictwo,
        trim(split_part(b.adr_les, '-', 5)) AS oddzial
    FROM analityka.bdot10k_sciezki_clip t
    INNER JOIN analityka.wydzielenia_bufory b
        ON t.geom_clip && b.geom
       AND ST_Intersects(t.geom_clip, b.geom)
    GROUP BY lesnictwo, oddzial
) sub;

-- === DROGI ===
CREATE TABLE analityka.j_clip_drogi AS
SELECT row_number() OVER () AS id, wkb_geometry, lesnictwo, oddzial
FROM (
    SELECT
        ST_SetSRID(
            ST_CollectionExtract(
                ST_Union(ST_Intersection(t.geom_clip, b.geom)),
                2), 2180) AS wkb_geometry,              -- renamed: geom_clip → wkb_geometry
        trim(split_part(b.adr_les, '-', 4)) AS lesnictwo,
        trim(split_part(b.adr_les, '-', 5)) AS oddzial
    FROM analityka.bdot10k_drogi_clip t
    INNER JOIN analityka.wydzielenia_bufory b
        ON t.geom_clip && b.geom
       AND ST_Intersects(t.geom_clip, b.geom)
    WHERE t."kategoriaz" NOT IN ('wewnętrzna')
      AND t."kategoriaz" IS NOT NULL
    GROUP BY lesnictwo, oddzial
) sub;

-- === BUDYNKI ===
CREATE TABLE analityka.j_clip_budynki AS
SELECT row_number() OVER () AS id, wkb_geometry, lesnictwo, oddzial
FROM (
    SELECT
        ST_SetSRID(
            ST_CollectionExtract(
                ST_Union(ST_Intersection(t.geom_clip, b.geom)),
                3), 2180) AS wkb_geometry,              -- renamed: geom_clip → wkb_geometry
        trim(split_part(b.adr_les, '-', 4)) AS lesnictwo,
        trim(split_part(b.adr_les, '-', 5)) AS oddzial
    FROM analityka.bdot10k_budynki_clip t
    INNER JOIN analityka.wydzielenia_bufory b
        ON t.geom_clip && b.geom
       AND ST_Intersects(t.geom_clip, b.geom)
    GROUP BY lesnictwo, oddzial
) sub;

-- ============================================================
-- USUWANIE TABEL TYMCZASOWYCH
-- ============================================================

DROP TABLE IF EXISTS analityka.bdot10k_torykolejowe_clip,
                     analityka.bdot10k_sciezki_clip,
                     analityka.bdot10k_drogi_clip,
                     analityka.bdot10k_budynki_clip,
                     analityka.wydzielenia_bufory;

-- ============================================================
-- INDEKSY PRZESTRZENNE NA TABELACH WYNIKOWYCH j_clip_*
-- ============================================================

CREATE INDEX ON analityka.j_clip_turystyka_punktowa USING GIST (wkb_geometry);
CREATE INDEX ON analityka.j_clip_strava             USING GIST (wkb_geometry);
CREATE INDEX ON analityka.j_clip_torykolejowe       USING GIST (wkb_geometry);
CREATE INDEX ON analityka.j_clip_sciezki            USING GIST (wkb_geometry);
CREATE INDEX ON analityka.j_clip_drogi              USING GIST (wkb_geometry);
CREATE INDEX ON analityka.j_clip_budynki            USING GIST (wkb_geometry);

-- ============================================================
-- KLUCZE GŁÓWNE NA TABELACH WYNIKOWYCH j_clip_*
-- ============================================================

ALTER TABLE analityka.j_clip_turystyka_punktowa ADD PRIMARY KEY (id);
ALTER TABLE analityka.j_clip_strava             ADD PRIMARY KEY (id);
ALTER TABLE analityka.j_clip_torykolejowe       ADD PRIMARY KEY (id);
ALTER TABLE analityka.j_clip_sciezki            ADD PRIMARY KEY (id);
ALTER TABLE analityka.j_clip_drogi              ADD PRIMARY KEY (id);
ALTER TABLE analityka.j_clip_budynki            ADD PRIMARY KEY (id);

-- ============================================================
-- REJESTRACJA W geometry_columns
-- ============================================================

SELECT Populate_Geometry_Columns('analityka.j_clip_turystyka_punktowa'::regclass);
SELECT Populate_Geometry_Columns('analityka.j_clip_strava'::regclass);
SELECT Populate_Geometry_Columns('analityka.j_clip_torykolejowe'::regclass);
SELECT Populate_Geometry_Columns('analityka.j_clip_sciezki'::regclass);
SELECT Populate_Geometry_Columns('analityka.j_clip_drogi'::regclass);
SELECT Populate_Geometry_Columns('analityka.j_clip_budynki'::regclass);