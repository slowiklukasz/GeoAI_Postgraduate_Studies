#!/bin/bash

set -e

usage() {
  echo "Użycie:"
  echo "  $0 --host HOST --port PORT --dbname DBNAME --user USER --password PASSWORD --schema SCHEMA --katalog KATALOG"
  echo
  echo "Przykład:"
  echo "  $0 --host localhost --port 5432 --dbname geodata --user postgres --password moje_haslo --schema roboczy --katalog /dane/shp"
  exit 1
}

HOST=""
PORT=""
DBNAME=""
USER_NAME=""
PASSWORD=""
SCHEMA=""
KATALOG=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --host)
      HOST="$2"
      shift 2
      ;;
    --port)
      PORT="$2"
      shift 2
      ;;
    --dbname)
      DBNAME="$2"
      shift 2
      ;;
    --user)
      USER_NAME="$2"
      shift 2
      ;;
    --password)
      PASSWORD="$2"
      shift 2
      ;;
    --schema)
      SCHEMA="$2"
      shift 2
      ;;
    --katalog)
      KATALOG="$2"
      shift 2
      ;;
    -h|--help)
      usage
      ;;
    *)
      echo "Nieznany argument: $1"
      usage
      ;;
  esac
done

if [[ -z "$HOST" || -z "$PORT" || -z "$DBNAME" || -z "$USER_NAME" || -z "$PASSWORD" || -z "$SCHEMA" || -z "$KATALOG" ]]; then
  echo "Błąd: musisz podać wszystkie wymagane argumenty."
  usage
fi

if [[ ! -d "$KATALOG" ]]; then
  echo "Błąd: katalog '$KATALOG' nie istnieje."
  exit 1
fi

BAZA="PG:host=$HOST port=$PORT dbname=$DBNAME user=$USER_NAME password=$PASSWORD"

shopt -s nullglob
PLIKI=( "$KATALOG"/*.shp )

if [[ ${#PLIKI[@]} -eq 0 ]]; then
  echo "Brak plików SHP w katalogu: $KATALOG"
  exit 0
fi

for f in "${PLIKI[@]}"; do
  nazwa=$(basename "$f" .shp)
  echo "Importuję: $nazwa -> ${SCHEMA}.${nazwa}"
  # -t_srs EPSG:2180 - wymusza, by warstwa wynikowa w PostGIS była w PUWG 1992.
  #   Jeśli .prj wskazuje już 2180 -> brak realnej transformacji, tylko spójna etykieta.
  #   Jeśli .prj wskazuje inny układ (np. 4326 dla pomiarów, custom 900914 z QGIS) ->
  #   ogr2ogr reprojektuje współrzędne do 2180.
  ogr2ogr -f "PostgreSQL" "$BAZA" "$f" \
    -nln "$nazwa" \
    -nlt PROMOTE_TO_MULTI \
    -t_srs EPSG:2180 \
    -lco SCHEMA="$SCHEMA"
done

echo "Import zakończony!"