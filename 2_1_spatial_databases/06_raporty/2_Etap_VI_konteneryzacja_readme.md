# Etap VI: Konteneryzacja - instrukcja instalacyjna stacka PostGIS

Dokument opisuje, jak postawić od zera lokalne środowisko PostgreSQL + PostGIS w Dockerze, używane w projekcie. Po wykonaniu kroków poniżej dostajemy działającą bazę z gotowymi schematami i użytkownikami, do której można podpiąć QGIS lub DBeavera i kontynuować pracę z importem danych oraz uruchamianiem analiz.

## Po co konteneryzacja

- **Brak konieczności instalacji Postgresa lokalnie** - cały stack siedzi w jednym kontenerze, host pozostaje czysty.
- **Reprodukowalność** - każdy członek zespołu po `docker compose up` dostaje identyczne środowisko: ta sama wersja PostGIS, te same schematy, ten sam zestaw użytkowników.
- **Izolacja** - port `5422` na hoście nie koliduje z lokalnym Postgresem (gdyby ktoś go miał na domyślnym `5432`).
- **Łatwy reset** - `docker compose down -v` czyści wszystko, kolejny `up` stawia bazę od zera w mniej niż 2 minuty.

## Wymagania wstępne

| Komponent          | Wersja / źródło                                                         |
| ------------------ | ----------------------------------------------------------------------- |
| Docker Desktop     | aktualna wersja z [docker.com/products/docker-desktop](https://www.docker.com/products/docker-desktop/) (Windows/Mac) lub Docker Engine + Compose V2 (Linux) |
| Docker Compose V2  | wbudowany w Docker Desktop (subkomenda `docker compose`, **ze spacją**) |
| Wolne miejsce      | ~2 GB na image PostGIS + wolumen z danymi                               |

Weryfikacja, że Compose działa:

```powershell
docker compose version
```

Spodziewany output to coś typu `Docker Compose version v2.x.x`. Jeśli komenda nie istnieje, Docker Desktop nie jest zainstalowany lub jest w wersji starszej niż V2.

## Struktura plików stacka

Wszystkie pliki potrzebne do postawienia kontenera leżą w roocie repo oraz w `materialy/04_skrypty/`:

| Ścieżka                                                                                                | Rola                                                                                                                                |
| ------------------------------------------------------------------------------------------------------ | ----------------------------------------------------------------------------------------------------------------------------------- |
| [Dockerfile](/Dockerfile)                                                                              | Definicja własnego image'a: `FROM postgis/postgis:latest` + doinstalowanie `gdal-bin` (potrzebne dla `ogr2ogr` przy imporcie shape'ów) |
| [docker-compose.yml](/docker-compose.yml)                                                              | Definicja serwisu `db`: nazwa kontenera, zmienne środowiskowe, mapowanie portów, wolumeny (trwałe dane + bind mount `/materialy`)    |
| [materialy/04_skrypty/00_ustawienia_administracyjne.sql](/materialy/04_skrypty/00_ustawienia_administracyjne.sql) | Skrypt uruchamiany jest **automatycznie** przy pierwszym starcie - tworzy schematy `raw`/`temporary`/`analityka` oraz użytkowników `jakub`, `jacek`, `lukasz` z odpowiednimi uprawnieniami |
| [materialy/04_skrypty/01_import_danych.sh](/materialy/04_skrypty/01_import_danych.sh)                  | Skrypt do importu shape'ów (`ogr2ogr` w pętli po katalogu) - uruchamiany **ręcznie** po pierwszym starcie                              |
| [materialy/04_skrypty/02_struktura bazy_danych.sql](/materialy/04_skrypty/02_struktura%20bazy_danych.sql) | Indeksy GIST/B-tree + FK constraint - uruchamiany **ręcznie** po imporcie shape'ów                                                     |

## Pierwsze uruchomienie (od zera)

### Krok 1 - klon repozytorium

Otwórz folder a projektem, w którym będą się znajdować pliki `Docker` oraz Docker `compose`.

### Krok 2 - budowa i start kontenera

```powershell
docker compose up -d --build
```

Co się dzieje pod spodem:

1. Docker pobiera bazowy image `postgis/postgis:latest` (~700 MB kolejne uruchomienia używają cache).
2. Build własnego image'a: `apt-get install gdal-bin` (~30 s).
3. Tworzy named volume `pgdata` (jeśli nie istnieje).
4. Startuje kontener `postgis_db`.
5. Docker-entrypoint Postgresa wykonuje `initdb` - inicjalizuje cluster (~10 s).
6. Wewnątrz kontenera startuje tymczasowy serwer Postgres na `localhost:5432` (tylko do init).
7. Odpalane są skrypty z `/docker-entrypoint-initdb.d/` w kolejności alfabetycznej - w naszym przypadku tylko `00_ustawienia_administracyjne.sql`.
8. Wewnątrz `00_*`: `CREATE EXTENSION postgis;` (1-2 minuty - to może chwilkę potrwać, **nie panikuj** jeśli logi zwalniają), potem `CREATE SCHEMA`, `CREATE USER`, `GRANT ...`.
9. Po sukcesie init serwer jest restartowany i wystawiany na port `5432` kontenera, który Docker mapuje na `5422` hosta.

### Krok 3 - obserwacja logów

```powershell
docker compose logs -f db
```

(Wyjście z `-f` - `Ctrl+C`, kontener dalej działa w tle.)

Czego szukać:

- `running /docker-entrypoint-initdb.d/00_ustawienia_administracyjne.sql` - skrypt init startuje.
- Sekwencja `CREATE SCHEMA`, `CREATE EXTENSION`, `CREATE ROLE`, `GRANT` - bez `ERROR` / `FATAL`.
- `PostgreSQL init process complete; ready for start up.` - init zakończony sukcesem.
- `database system is ready to accept connections` - serwer przyjmuje połączenia z zewnątrz.

### Krok 4 - weryfikacja statusu

```powershell
docker compose ps
```

Spodziewane: kolumna `STATUS` pokazuje `Up X minutes`, kolumna `PORTS` zawiera `0.0.0.0:5422->5432/tcp`.

Szybki sanity check:

```powershell
docker compose exec db psql -U postgres -d PBD -c "SELECT PostGIS_version();"
docker compose exec db psql -U postgres -d PBD -c "\dn"
docker compose exec db psql -U postgres -d PBD -c "\du"
```

- `PostGIS_version()` - zwraca wersję, np. `3.5 USE_GEOS=1 USE_PROJ=1 USE_STATS=1`.
- `\dn` - widać schematy `analityka`, `public`, `raw`, `temporary`.
- `\du` - widać role `postgres`, `jakub`, `jacek`, `lukasz`.

## Wyjaśnienie parametrów `docker-compose.yml`

| Linia                                  | Co robi                                                                                                                                              |
| -------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------- |
| `services: db:`                        | Definiuje pojedynczy serwis o nazwie `db`. Compose używa tej nazwy do odwołań (`docker compose exec db ...`).                                        |
| `build: .`                             | Buduje image z `Dockerfile` w bieżącym katalogu (zamiast brać gotowy z rejestru).                                                                    |
| `container_name: postgis_db`           | Stała nazwa kontenera (bez tego Compose generuje `przestrzenne-bazy-danych-db-1`). Ułatwia odwołania w `docker exec`, monitoring.                    |
| `restart: unless-stopped`              | Kontener automatycznie wstaje po restarcie Dockera / hosta. Nie wstaje tylko jeśli był ręcznie zatrzymany przez `docker compose stop`.               |
| `environment.POSTGRES_USER: postgres`  | Superuser bazy. Wymagane przez image postgresa - bez tego initdb się nie uruchomi.                                                                     |
| `environment.POSTGRES_PASSWORD: postgres` | Hasło superuser-a. **Uwaga**: hardkod tylko dla lokalnej pracy; produkcja → sekret, nie plaintext w repo.                                         |
| `environment.POSTGRES_DB: PBD`         | Nazwa bazy tworzonej przy starcie. Wszystkie nasze skrypty pracują na `PBD`.                                                                          |
| `ports: "5422:5432"`                   | Mapowanie `host:container`. Postgres wewnątrz kontenera nasłuchuje na `5432`, my łączymy się z hosta na `5422` (żeby nie kolidować z ew. lokalnym Postgresem). |
| `volumes: pgdata:/var/lib/postgresql/data` | **Named volume** dla trwałych danych bazy. Przeżywa `docker compose down`; znika dopiero przy `docker compose down -v`.                          |
| `volumes: ./materialy:/materialy`      | **Bind mount** całego katalogu `materialy/` z hosta pod `/materialy` w kontenerze - shape'y, skrypty, raporty widoczne z poziomu kontenera.          |
| `volumes: ./materialy/04_skrypty/00_*.sql:/docker-entrypoint-initdb.d/00_*.sql:ro` | Mount pliku init SQL pod magiczną ścieżkę `/docker-entrypoint-initdb.d/`. Entrypoint Postgresa uruchamia stamtąd skrypty alfabetycznie. `:ro` = tylko do odczytu (zabezpieczenie). |
| `volumes: pgdata:`                     | Deklaracja named volume na poziomie compose (musi być, inaczej Compose nie wie, że `pgdata` ma być persistentnym wolumenem a nie bind mountem).      |

> **Uwaga techniczna:** w pliku celowo **nie ma** `tty: true` ani `stdin_open: true` na głównym procesie. Wersja kompose z `tty: true` powodowała, że `psql` w entrypoint myślał że ma terminal i włączał pager (`less`), przez co init zawisał na pierwszym `SELECT`-cie. Terminal interaktywny dostajemy bez tego - przez `docker compose exec -it db bash` (który alokuje własny TTY).

## Praca z bazą po starcie

| Komenda                                                   | Działanie                                                              |
| --------------------------------------------------------- | ---------------------------------------------------------------------- |
| `docker compose start`                                    | Wstanie zatrzymanego wcześniej kontenera (nie zmienia config).         |
| `docker compose stop`                                     | Zatrzymanie kontenera bez kasowania (dane w wolumenie zostają).        |
| `docker compose restart`                                  | Restart serwisu - przydatne po zmianie compose lub jeśli baza zgłupiała. |
| `docker compose exec -it db bash`                         | Otwarcie interaktywnego bash-a wewnątrz kontenera.                     |
| `docker compose exec db psql -U postgres -d PBD`          | Otwarcie psql wewnątrz kontenera (bez wchodzenia w bash).              |
| `docker compose logs db --tail 100`                       | Ostatnie 100 linii logów.                                              |
| `docker compose logs -f db`                               | Stream logów na żywo (`Ctrl+C` żeby przerwać).                         |
| `docker compose ps`                                       | Lista uruchomionych kontenerów stacka + ich status.                    |
| `docker compose down`                                     | Zatrzymanie i usunięcie kontenera. Wolumen `pgdata` **zostaje**.       |
| `docker compose down -v`                                  | Zatrzymanie + usunięcie kontenera **i wolumenu** - utrata wszystkich danych. |

## Połączenie z hosta (DBeaver / QGIS / psql)

Parametry połączenia są stałe i wynikają wprost z `docker-compose.yml`:

| Parametr  | Wartość       | Skąd to się bierze                                                            |
| --------- | ------------- | ----------------------------------------------------------------------------- |
| Host      | `localhost`   | Kontener mapuje port na `0.0.0.0`, więc dostępny przez `localhost` lub `127.0.0.1` |
| Port      | `5422`        | **Host port** z mapowania `5422:5432`. Łatwa pomyłka: w środku kontenera nadal `5432`, ale z hosta strzelamy na `5422`. |
| Database  | `PBD`         | `POSTGRES_DB` z compose                                                       |
| User      | `postgres`    | Superuser; alternatywnie `jakub`/`jacek`/`lukasz` (hasła `<imie>geoai`)        |
| Password  | `postgres`    | `POSTGRES_PASSWORD` z compose                                                 |

Z linii poleceń:

```powershell
psql -h localhost -p 5422 -U postgres -d PBD
```

(Wymaga zainstalowanego klienta `psql` na hoście. Alternatywnie: `docker compose exec db psql ...` jak wyżej.)

## Workflow uzupełnienia danych (ręcznie, po pierwszym starcie)

`00_*.sql` tworzy tylko strukturę administracyjną (schematy + userzy). Tabele z danymi i indeksy zakładamy ręcznie:

### Krok 1 - wejście do kontenera

```powershell
docker compose exec -it db bash
```

(Cały dalszy ciąg poleceń uruchamiany jest **wewnątrz** kontenera.)

### Krok 2 - import shape'ów z `/materialy/01_dane/wektory/` do schematu `raw`

```bash
bash /materialy/04_skrypty/01_import_danych.sh \
  --host localhost \
  --port 5432 \
  --dbname PBD \
  --user postgres \
  --password postgres \
  --schema raw \
  --katalog /materialy/01_dane/wektory
```

| Argument                | Znaczenie                                                                                                |
| ----------------------- | -------------------------------------------------------------------------------------------------------- |
| `--host localhost`      | Łączymy się do Postgresa **w tym samym kontenerze** - z perspektywy procesu w kontenerze to localhost.   |
| `--port 5432`           | **Port wewnątrz kontenera**, nie `5422` (5422 to mapowanie tylko do hosta).                              |
| `--dbname PBD`          | Cel: nasza baza projektowa.                                                                              |
| `--user postgres`       | Superuser - może tworzyć tabele w dowolnym schemacie.                                                    |
| `--password postgres`   | Zgodne z `POSTGRES_PASSWORD` w compose.                                                                  |
| `--schema raw`          | Tabele lądują w schemacie `raw` (zgodnie z koncepcją: raw → temporary → analityka).                      |
| `--katalog /materialy/01_dane/wektory` | Folder z plikami `.shp` - skrypt iteruje po wszystkich i robi `ogr2ogr` dla każdego.            |

Skrypt wypisze dla każdego pliku linię typu `Importuję: bdot10k_budynki -> raw.bdot10k_budynki`. Po zakończeniu `Import zakończony!`.

### Krok 3 - import `raport_z_wysokosciami` z CSV przez DBeavera

**Ten krok jest konieczny PRZED uruchomieniem `02_struktura bazy_danych.sql`** - skrypt zakłada indeks B-tree i FK constraint na tabeli `raw.raport_z_wysokosciami`, a tej tabeli nie ma w `.shp` (jest w pliku CSV). Bez tego kroku `02_*` wyłoży się błędem `relation "raw.raport_z_wysokosciami" does not exist`.

Zgodnie z procesem opisanym w [2_Etap_II_readme.md](2_Etap_II_readme.md):

1. Plik źródłowy to [materialy/01_dane/raport z wysokosciami.xlsx](/materialy/01_dane/raport%20z%20wysokosciami.xlsx), wyeksportowany do [materialy/01_dane/raport z wysokosciami.csv](/materialy/01_dane/raport%20z%20wysokosciami.csv).
2. Import realizujemy przez DBeavera, okienkiem dialogowym **Import Data**.
3. **Należy zmienić separator z `,` na `;`** - inaczej wszystkie kolumny zlecą się do jednej.

![Import tabeli CSV w DBeaverze](/materialy/05_obrazy/screeny_do_raportow/import%20tabeli%20csv.png "Import tabeli")

Konkretne kliknięcia w DBeaverze:

1. W panelu Database Navigator rozwiń połączenie → `PBD` → `Schemas` → `raw` → prawym na `Tables` → **Import Data**.
2. Wybierz źródło: **CSV** → wskaż plik `materialy/01_dane/raport z wysokosciami.csv`.
3. W ustawieniach importera: **Column delimiter** = `;`, **Header position** = `First line`, kodowanie = `UTF-8`.
4. Nazwa tabeli docelowej: `raport_z_wysokosciami` (schemat `raw`).
5. **Start** → poczekaj na "Data transfer completed".

Weryfikacja:
```bash
psql -U postgres -d PBD -c 'SELECT count(*) FROM raw."raport_z_wysokosciami";'
```

Tabela powinna mieć kolumny `Adres leśny`, `Warstwa`, `Gatunek`, `Udział`, `Wiek`, `Wys`, `D1.3` (zgodnie z ERD).

### Krok 4 - indeksy GIST/B-tree + FK constraint

```bash
psql -U postgres -d PBD -f "/materialy/04_skrypty/02_struktura bazy_danych.sql"
```

Plik zakłada indeksy przestrzenne dla wszystkich tabel z `raw.*` mających kolumnę geometrii, plus B-tree na `adr_les` oraz `"Adres leśny"` w `raport_z_wysokosciami` i FK constraint między `raport_z_wysokosciami` a `wydzielenia`. Po Kroku 3 wszystkie tabele referowane w tym pliku już istnieją - skrypt powinien przejść bez błędów.

## Reset środowiska

Jeśli baza wpadła w nieprzyjemny stan (lub po prostu chcesz świeży init):

```powershell
docker compose down -v
docker compose up -d --build
```

> **Uwaga**: `-v` usuwa wolumen `pgdata` z **całą zawartością bazy**. Wszystkie zaimportowane tabele i zmiany w bazie znikają. Jeśli masz coś istotnego, najpierw zrób dump:
>
> ```powershell
> docker compose exec db pg_dump -U postgres -d PBD -F c -f /materialy/backup_$(Get-Date -Format yyyyMMdd_HHmm).dump
> ```

Po `up -d --build` kontener wstaje z czystym wolumenem i `00_*` uruchamia się ponownie - schematy i userzy są na świeżo.

## Troubleshooting

| Objaw                                                                              | Przyczyna i rozwiązanie                                                                                                          |
| ---------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------- |
| `EOFException` w DBeaverze przy próbie połączenia                                  | Port wejściowy = `5422`, nie `5432`. Drugi powód: init kontenera wisi (zob. niżej `tty: true`).                                  |
| `Connection refused` na `localhost:5432`                                           | Próbujesz strzelać na port wewnątrzkontenerowy. Z hosta zawsze `localhost:5422`.                                                 |
| Logi pokazują `(END)` i init wisi                                                  | W `docker-compose.yml` jest `tty: true` na głównym procesie - usuń tę linię. Pager `less` zatrzymuje psql w init.                |
| `PostgreSQL Database directory appears to contain a database; Skipping initialization` | Wolumen `pgdata` już zawiera bazę z poprzedniego runu, więc skrypty init są pomijane. Jeśli chcesz świeży init: `docker compose down -v`. |
| `relation "raw.raport_z_wysokosciami" does not exist` przy `02_struktura bazy_danych.sql` | Brak importu CSV w Kroku 3 workflowu. Najpierw zaimportuj `raport z wysokosciami.csv` przez DBeavera (separator `;`), potem `02_*`. |
| `relation "raw.X" does not exist` (inna tabela) przy `02_struktura bazy_danych.sql` | Indeksy próbują się założyć przed importem danych. Najpierw `01_import_danych.sh`, potem CSV, potem `02_*`.                       |
| Pierwsze `docker compose up --build` trwa 1-2 minuty bez ruchu w logach            | To `CREATE EXTENSION postgis` - normalne, daj mu skończyć.                                                                       |
| `permission denied` przy mountcie `/materialy` (Linux)                             | UID kontenera (postgres = 999) nie pasuje do właściciela katalogu na hoście. Najprostszy fix: `chmod -R a+rX materialy/`.        |
| Build się wykłada na `apt-get install gdal-bin`                                    | Brak internetu w kontenerze - sprawdź konfigurację sieci Dockera (`docker network ls`, ew. DNS).                                  |
