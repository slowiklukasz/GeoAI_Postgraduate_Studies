# Etap II: Raport z opisem źródeł danych i procesu ich importu

W poniższym dokumencie pochylamy się nad tym jakie dany zostały zaimportowane do projektu oraz w jaki sposób.

## Źródła danych:

| Warstwa               | Typ                | Źródło                                                | Opis                                                                                                                                                                  |
| --------------------- | ------------------ | ----------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| bdot10k_budynki       | tabela z geometrią | Baza Danych Obiektów Topograficznych                  | Zawiera dane dotyczące budynków                                                                                                                                       |
| bdot10k_drogi         | tabela z geometrią | Baza Danych Obiektów Topograficznych                  | Zawiera dane dotyczące dróg                                                                                                                                           |
| bdot10k_sciezki       | tabela z geometrią | Baza Danych Obiektów Topograficznych                  | Zawiera dane dotyczące ścieżek pieszych i tras rowerowych                                                                                                             |
| bdot10k_torykolejowe  | tabela z geometrią | Baza Danych Obiektów Topograficznych                  | Zawiera dane dotyczące torów kolejowych                                                                                                                               |
| granica_nadlesnictwa  | tabela z geometrią | Warstwy Pochodne LMN Nadleśnictwa Giżycko             | Przedstawia zasięg administracyjny nadleśnictwa                                                                                                                       |
| lesnictwa             | tabela z geometrią | Warstwy Pochodne LMN Nadleśnictwa Giżycko             | przedstawia zasięg administracyjny leśnictw w Nadleśnictwie Giżycko                                                                                                   |
| oddzialy              | tabela z geometrią | Warstwy Pochodne LMN Nadleśnictwa Giżycko             | przedstawia podział przestrzenny Nadleśnictwa Giżycko na oddziały leśne                                                                                               |
| wydzielenia           | tabela z geometrią | Warstwy Pochodne LMN Nadleśnictwa Giżycko             | przedstawia podział przestrzenny Nadleśnictwa Giżycko na wydzielenia leśne                                                                                            |
| turystyka_liniowa     | tabela z geometrią | Warstwy Pochodne LMN Nadleśnictwa Giżycko             | Zawiera dane zinwentaryzowanych przez Nadleśnictwo tras rowerowych i pieszych                                                                                         |
| turystyka_punktowa    | tabela z geometrią | Warstwy Pochodne LMN Nadleśnictwa Giżycko             | Zawiera dane zinwentaryzowanych przez Nadleśnictwo obiektów turystyki w tym wiat czy pól biwakowych                                                                   |
| strava                | tabela z geometrią | Zwektoryzowane dane pozyskane z aplikacji Strava      | Wskazuje trasy uczęszczane przez użytkowników aplikacji                                                                                                               |
| pomiary               | tabela z geometrią | Dane pomiarowe z terenu                               | Punktowa lokalizacja drzew niebezpiecznych                                                                                                                            |
| raport z wysokosciami | tabela             | Baza Danych Systemu Informatycznego Lasów Państwowych | zawiera atrybuty dotyczące drzewostanów według adresu leśnego                                                                                                         |
| CHM_B09_od1m          | raster             | Dane pozyskane ze zbioru Nadleśnictwa Giżycko         | Wysokościowy Model Koron dla okolic Giżycka w tym kompleksu uroczyska Las Miejski                                                                                     |
| segments_2012         | tabela z geometrią | Opracowanie własne (na podst. danych GUGiK)           | Wynik segmentacji koron drzew wykonanej autorskim modelem AI na podstawie chmury punktów LiDAR (.laz) z nalotu w 2012 roku                                            |
| segments_2025         | tabela z geometrią | Opracowanie własne (na podst. danych Nadleśnictwa)    | Wynik segmentacji koron drzew wykonanej autorskim modelem AI na podstawie Wysokościowego Modelu Koron (CHM) dla okolic Giżycka, w tym kompleksu uroczyska Las Miejski |

## Import danych do bazy danych

### Import danych geometrycznych do bazy danych

Jako, że mieliśmy do czynienia z więcej niż jedną warstwą i dane były w plikach typu ESRI Shapefile postanowiliśmy powyższy proces zautomatyzować. Decyzja o pracy w przygotowanym do zajęć kontenerze dockerowym dodatkowo znajdującym się na serwerze lokalnym stworzyła konieczność zdalnego dostępu:

1. Najpierw po SSH do serwera na którym zainstalowany został Docker:

```bash
ssh user@hostname albo user@ipaddress
```

2. Z tegoże serwera osobno do kontenera:

```bash
docker exec -it <container-name> /bin/bash
```

3. Kolejnym krokiem było przeniesienie pliku z warstwami z hosta na którym się znajdowały na serwer. W tym celu użyto protokołu SFTP w aplikacji filezilla, aby umożliwić zdalną wymianę danych, co pokazano na ilustracji niżej.

![Filezilla](/materialy/05_obrazy/screeny_do_raportow/Filezilla.png "Filezilla")

4. Następnie wybraliśmy metodę importu danych za pomocą biblioteki GDAL, instalowanej z wewnątrz kontenera poleceniem:

```bash
apt-get update && apt-get install -y gdal-bin libgdal-dev
```

5. Następnym krokiem była modyfikacja skryptu do importu plików shp z ćwiczeń tworząc plik [`import_danych.sh`](/materialy/04_skrypty/import_danych.sh) używając poleceń

```bash
touch import_danych.sh # tworzymy pusty plik, który zostaje następnie wypełniony tekstem skryptu lub kopiujemy plik, tak samo jak dane z punktu 3-go.
chmod +x import_danych.sh # nadajemu mu uprawnienia wykonywalne
```

Najważniejszą zmianą było to, że skrypt [`import_danych.sh`](/materialy/04_skrypty/import_danych.sh) przyjmuje (wymaga) teraz wszystkiech argumentów dotyczące importu warstw do bazy danych następujących, które do tej pory były wpisane na sztywno, co zwiększa jego praktyczną użyteczność.

Komenda do masowego dodawania warstw .shp do bazy danych:

```bash
./import_danych.sh  --host <iphosta> --port 5432 --dbname postgres --user postgres --password postgres --schema raw --katalog /var/lib/postgresql/przestrzenne-bazy-danych/wektory
```

Wytłumaczenie:

| Element                        | Znaczenie                                                           |
| ------------------------------ | ------------------------------------------------------------------- |
| ./import_danych.sh             | Uruchamia skrypt importu w bieżącym katalogu                        |
| --host <iphosta>               | Adres serwera PostgreSQL                                            |
| --port 5432                    | Port PostgreSQL (domyślnie 5432)                                    |
| --dbname postgres              | Nazwa bazy docelowej                                                |
| --user postgres / --password … | Dane logowania do bazy                                              |
| --schema raw                   | Schemat, w którym tworzone są tabele z danych                       |
| --katalog /var/lib/.../wektory | Katalog z plikami .shp do wsadowego importu                         |
| Działanie całości              | Import wszystkich .shp z katalogu jako osobne tabele do raw w bazie |

---

---

**Warto dodać, że podczas importu `ogr2ogr` nadaje swój klucz główny podczas importu tabeli do bazy PSQL**.

---

---

![Primary key](/materialy/05_obrazy/screeny_do_raportow/primary%20key.png "Primary key")

### Import danych tabelarycznych do bazy danych

Oprócz danych z geometrią, posiadaliśmy również [tabelę wysokości gatunku panującego dla każdego wydzielenia](/materialy/01_dane/raport%20z%20wysokosciami.xlsx), która:

1. najpierw została wyeksportowana do [pliku .csv](/materialy/01_dane/raport%20z%20wysokosciami.csv)
2. zaimportowana w DBeaverze do bazy danych za pomocą okienka dialogowego. Należy zwrócić uwagę, iż konieczna była zmiana separatora z `,` na `;`.

![Import tabeli](/materialy/05_obrazy/screeny_do_raportow/import%20tabeli%20csv.png "Import tabeli")

## Import danych z bazy danych do programu QGIS

Dodawanie nowej warstwy/nowych warstw PSQL w QGIS realizuje się poprzez:

1. Wybranie dodania nowej warstwy PSQL (ikona ze słoniem)

`Layer > Add layer > Add PostGIS layer`

![Połączenie w QGIS 1](/materialy/05_obrazy/screeny_do_raportow/postgis%20connection%20i%20qgis%201.png "Połączenie w QGIS 1")

2. wybranie zestawienia nowego połączenia poprzez kliknięcie przycisku `New` i wypełnieniu formularza podobnie jak w `Instrukcji do zajęć`, przy czym zamiast nazwy hosta wpisujemy `lokalny adres ip` na ktorej postawiono serwer PSQL. Inne mogą być również `numer portu` na który ma łączyć się aplikacja oraz dane użytkownika (w 99.9% przypadków inne niż dane użytkownika administracyjnego `postgres`). Warto również przetestować połączenie.

![Połączenie w QGIS 2](/materialy/05_obrazy/screeny_do_raportow/PostGIS%20connection%20in%20qgis.png "Połączenie w QGIS 2")

3. Następnie należy zestawić połączenie z bazą danych za pomocą przycisku `Connect`

![Połączenie w QGIS 3](/materialy/05_obrazy/screeny_do_raportow/postgis%20connection%203.png "Połączenie w QGIS 3")

4. Ostatnim krokiem będzie wybranie warstw które chcemy dodać do projektu QGIS. W tym celu należy kliknąć na wybrany obiekt (jeden lub więcej) oraz nacisnąć `Add`.

![Połączenie w QGIS 4](/materialy/05_obrazy/screeny_do_raportow/postgis%20connection4.png "Połączenie w QGIS 4")

## Schematy ERD

Baza składa się z trzech schematów o różnym poziomie uprawnień.

W schemacie `raw` przechowywane są surowe dane wejściowe - tabele zaimportowane z plików ESRI Shapefile (warstwy BDOT10k, granica nadleśnictwa, wydzielenia, leśnictwa, oddziały, turystyka, Strava, segmenty CHM, pomiary terenowe) oraz tabela `raport_z_wysokosciami` z pliku CSV. Jest to główny schemat, z którego pobierane są dane wejściowe do wszystkich zapytań analitycznych. Tabela `raport_z_wysokosciami` jest powiązana z tabelą `wydzielenia` kluczem obcym po kolumnie z adresem leśnym.

![ERD schematu raw](/materialy/05_obrazy/screeny_do_raportow/erd1.png "ERD raw")

Schemat `temporary` służy do przechowywania tabel pomocniczych powstających w trakcie wykonywania zapytań wieloetapowych - np. zoptymalizowanej warstwy infrastruktury lokalnej oraz siatki heksagonalnej. Tabele te są usuwane po zakończeniu pracy zapytań, w których powstały.

Schemat `analityka` zawiera wszystkie trwałe tabele i widoki wynikowe stworzone przez zapytania SQL z [Etapu III](2_Etap_III_readme.md). Prostokąty o różnych kolorach na schemacie ERD wskazują na autorów poszczególnych tabel: czerwony – Jacek Koplin, niebieski – Łukasz Słowik, zielony – Jakub Wołosz. Wyniki przyjmują postać trwałych tabel oraz zmaterializowanych widoków.

![ERD schematu analityka](/materialy/05_obrazy/screeny_do_raportow/erd2.png "ERD analityka")

Na potrzeby pracy z bazą oprócz użytkownika administracyjnego `postgres` stworzono trzech użytkowników pomocniczych: `jakub`, `jacek` i `lukasz`. Użytkownicy ci nie posiadają uprawnień do edycji danych w schemacie `raw`, ale mogą wchodzić do schematu, przeglądać jego zawartość oraz wykonywać zapytania typu `SELECT` - pozwoliło to uniknąć przypadkowego usunięcia danych przez innego członka zespołu. W schematach roboczych (`temporary`, `analityka`) użytkownicy otrzymali pełne uprawnienia również dla nowo powstałych tabel. Całość konfiguracji znajduje się w pliku [`00_ustawienia_administracyjne.sql`](/materialy/04_skrypty/00_ustawienia_administracyjne.sql).