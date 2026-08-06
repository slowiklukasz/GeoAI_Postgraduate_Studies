# Etap I: Instrukcja instalacji działającej bazy

W poniższym pliku zostaną przedstaawione kroki które podjęliśmy, aby postawić bazę danych PostgreSQL (PSQL) z zainstalowanym rozszerzeniem PostGIS będącego częścią Projektu na zaliczenie Przedmiotu Przestrzenne Bazy Danych.

## Środowisko pracy

W odróżnieniu od metody z zajęć serwer PSQL wkomponowano w już istniejącą infrastrukturę sieciową. Był to serwer plików zainstalowany w lokalnej sieci jednego z uczestników grupy. 
Serwer Postgis zbudowano jako kontener Dockerowy  na serwerze NAS w aplikacji do zarządzania kontenerami Portainer na komputerze jednopłytkowym Raspberry Pi 5 8GB RAM, zainstalowany za pomocą pliku Docker Compose zwanym także manifestem yamlowym Docker.


### Połączenie do sieci VPN

Aby umożliwić grupie pracę na wspólnej lokalizacji sieciowej zestawiono połączenie VPN za pomocą aplikacji Tailscale, dzięki czemu użytkownicy mogli się łączyć z siecią lokalną, na której postawiono serwer PSQL i w pełni korzystać ze współpracy grupowej. 

Aby dołączyć do sieci Tailnet, należało zalogować się np. kontem Google, zainstalować dedykowaną aplikację, oraz wybrać tzw. węzeł wyjściowy na skonfigurowany przez administratora sieci Tailscale, reszta dzieje się automatycznie.

![Screenshot z Tailscale](/materialy/05_obrazy/screeny_do_raportow/explorer_rNespiPHjg.png "Screenshot z Tailscale")


## Wybór i instalacja systemu bazodanowego:

W projekcie wybraliśmy PostgreSQL + PostGIS. Z racji tego, że przed pierwszymi zajęciami już stawialiśmy serwer postgres jako kontener Dockerowy, w naszym projekcie posłużymy się już gotowym kontenerem. Było to również rekomendowane rozwiązanie, które najbardziej nam odpowiadało, ze względu na swoją uniwersalność, rodzaj i specyfikę danych oraz potencjał do nauki.

## Konfiguracja połączenia i uprawnień

Konfiguracja połączenia i uprawnień ma miejsce na samym początku. Baza danych PSQL posiada mechanizmy wielodostępu, więc z założenia powinna być zarządzana przez wielu użytkowników o różnych uprawnieniach dla poszczególnych elementów bazy danych. 

W naszym przypadku było to wydanie komend administracyjnych w SQL przez użytkownika `postgres`, co obejmowało m.in stworzenie schematów, użytkowników oraz nadanie im uprawnień do poszczególnych tabel w schemacie. Więcej informacji można znaleźć w pliku [00_ustawienia_administracyjne.sql](/materialy/04_skrypty/00_ustawienia_administracyjne.sql) w którym zawarto komendy użyte przed właściwym rozpoczęciem pracy z bazą danych.

Zestawienie połączenia miało miejsce w aplikacjach DBeaver/QGIS na podstawie instrukcji z zajęć, co pozwoliło na testowanie kwerend i wizualizację danych przestrzennych. Więcej o zestawieniu połączenia i imporcie danych w [dokumencie dotyczącym etapu II](/materialy/06_raporty/Etap_II_readme.md).

## Dokumentacja procesu instalacji (screenshot + opis kroków)

Instalacja bazy danych w największym stopniu polegała na tzw. stworzeniu `nowego stosu` w aplikacji Portainer, która jest wygodnym menedżerem kontenerów Docker'a.

![Screenshot z Portainer](/materialy/05_obrazy/screeny_do_raportow/portainer%20view.png "Screenshot z Portainer")

Jako, że podana w `Instrukcji do przygotowania środowiska do zajęć` komenda:
```bash
docker run --name ibles_bazy -e POSTGRES_PASSWORD=postgres -e POSTGRES_USER=postgres -e POSTGRES_DB=postgres -p 5432:5432 -d postgis/postgis:latest
```
dotyczyła samego Dockera, niezbędne było zmodyfikowanie jej do tzw. pliku Docker Compose, który często jest alternatywą do instalacji wielu kontenerów jednocześnie (wspomnianego wyżej stosu). W tym przypadku zainstalowano dodatkowo, kontener z aplikacją pgAdmin, managera dla baz PSQL, z bardziej przejrzystym interfejsem graficznym oraz zarządaniem uprawnieniami użytkowników.


Manifest yaml pliku Docker compose:

```yaml
version: "3.8"

services:
  postgis:
    image: imresamu/postgis:latest # obraz kompatybilny z architektórą ARM64
    container_name: ibles_bazy
    restart: unless-stopped
    environment:
      POSTGRES_PASSWORD: postgres
      POSTGRES_USER: postgres
      POSTGRES_DB: postgres
    ports:
      - 5432:5432
    volumes:
      - /srv/dev-disk-by-uuid-b05bf252-32b4-4c82-a5f2-95ac000dc191/docker/data/postgis:/var/lib/postgresql # mapowanie do konkretnego miejsca na serwerze plików, w tym przypadku do zamontowanego systemu plików ext4 na ktorym trzymano kontenery Dockerowe

  pgadmin:
    image: dpage/pgadmin4:latest
    container_name: ibles_pgadmin
    restart: unless-stopped
    environment:
      PGADMIN_DEFAULT_EMAIL: admin@example.com # email/login użytkownika administracyjnego w pgAdmin, nie mylić z użytkownikiem administracyjnym całej bazy danych.
      PGADMIN_DEFAULT_PASSWORD: your_secure_password_here # email/login użytkownika administracyjnego w pgAdmin
      PGADMIN_LISTEN_PORT: 80
    ports:
      - 15432:80
    volumes:
      - /srv/dev-disk-by-uuid-b05bf252-32b4-4c82-a5f2-95ac000dc191/docker/data/pgadmin:/var/lib/pgadmin
    depends_on:
      - postgis

```

Zainstalowanie pgAdmina jako dodatkowej nakładki monitorującej postęp/poprawność prac (zamiast DBeavera) umożliwia dostęp i zarządzanie serwerem z przegladarki bez instalowania dodatkowych aplikacji.

Jak już wspomniano samo połączenie do bazy danych w pgAdmin ma miejsce za pomocą interfejsu graficznego, gdzie po kliknięciu na ikonkę "Add New Server"
otwiera się okienko prowadzące nas za krok po kroku przez cały proces.

Przy tworzeniu nowej basy domyślnym użytkownikiem administracyjnym jest użytkownik **postgres**, z hasłem postgres. 

![Screenshot z pgAdmin](/materialy/05_obrazy/screeny_do_raportow/pgAdmin2.png "Screenshot z pgAdmin")

Widok na bazę danych widać w panelu z lewej strony ekranu. 

![Screenshot z pgAdmin](/materialy/05_obrazy/screeny_do_raportow/pgAdmin.png "Screenshot z pgAdmin")

Znajdujący się na skraju lewej strony ekranu pasek z ikonkami umożliwia na tworzenie zaptyań SQL i zarządzanie bazą danych.

![Screenshot z pgAdmin3](/materialy/05_obrazy/screeny_do_raportow/pgAdmin3.png "Screenshot z pgAdmin").