---------------------------------------------------------------------------------------------------------------------------------------
-- Część dotycząc ogólnej struktury bazy danych
---------------------------------------------------------------------------------------------------------------------------------------


-- Sprawdzamy dostępne rozszerzenia
SELECT extname FROM pg_extension;

-- Instalacja postgisa (wcześniej przez przypadek usunąłem schemat public, co spowodowało dalsze problemy, więc musiałem go stworzyć ponownie)
CREATE SCHEMA IF NOT EXISTS public;
CREATE EXTENSION IF NOT EXISTS postgis;

-- sprawdzamy czy dobrze zainstalowało PostGISa
SELECT PostGIS_version();

-- tworzymy nowe schematy wg. zaleceń z prezentacji
CREATE SCHEMA raw;
CREATE SCHEMA temporary; 
CREATE SCHEMA analityka;


-- stworzenie użytkowników
CREATE USER jakub  WITH PASSWORD 'jakubgeoai'  LOGIN;
CREATE USER jacek  WITH PASSWORD 'jacekgeoai'  LOGIN;
CREATE USER lukasz WITH PASSWORD 'lukaszgeoai' LOGIN;


-- Nadawanie uprawnień na schematy itp
-----------------------------------------------------------------------------------------------------------------------------------------

-- 1) USAGE na schematach (wejście do schematu) - merytorycznie trochę duplikuje sie z linią 72, ale nie chciałem bardziej mieszać

GRANT USAGE ON SCHEMA analityka, temporary, public, raw
  TO jakub, jacek, lukasz;


-- 2) Pełne uprawnienia do tabel w schematach "roboczych"


GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA analityka
  TO jakub, jacek, lukasz;
ALTER DEFAULT PRIVILEGES IN SCHEMA analityka
  GRANT ALL PRIVILEGES ON TABLES TO jakub, jacek, lukasz;


GRANT CREATE ON SCHEMA "temporary" TO jacek, lukasz, jakub;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA temporary
  TO jakub, jacek, lukasz;
ALTER DEFAULT PRIVILEGES IN SCHEMA temporary
  GRANT ALL PRIVILEGES ON TABLES TO jakub, jacek, lukasz;

GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public
  TO jakub, jacek, lukasz;
ALTER DEFAULT PRIVILEGES IN SCHEMA public
  GRANT ALL PRIVILEGES ON TABLES TO jakub, jacek, lukasz;


-- 3) raw: tylko do odczytu (read‑only) + USAGE już wyżej

GRANT SELECT ON ALL TABLES IN SCHEMA raw
  TO jakub, jacek, lukasz;
ALTER DEFAULT PRIVILEGES IN SCHEMA raw
  GRANT SELECT ON TABLES TO jakub, jacek, lukasz;


-- 4) Metadane PostGIS dla QGIS / innych narzędzi

GRANT SELECT ON public.geometry_columns
  TO jakub, jacek, lukasz;
GRANT SELECT ON public.geography_columns
  TO jakub, jacek, lukasz;

