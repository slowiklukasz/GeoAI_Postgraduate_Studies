# Etap IV: Wizualizacja - instrukcja otwarcia projektu QGIS

Dokument opisuje, jak na świeżej maszynie poprawnie uruchomić projekt [2_Etap_IV_Wizualizacja.qgz](2_Etap_IV_Wizualizacja.qgz) - czyli skonfigurować połączenie z bazą, otworzyć projekt bez utraty stylów i layoutów wydruku oraz gdzie szukać gotowych map.

## Co zawiera projekt

[2_Etap_IV_Wizualizacja.qgz](2_Etap_IV_Wizualizacja.qgz) to projekt QGIS z:
- warstwami źródłowymi z `raw.*` (BDOT10k, wydzielenia, leśnictwa, oddziały, turystyka, Strava, segmenty CHM itd.)
- warstwami wynikowymi z `analityka.*` (widoki/tabele utworzone przez zapytania z Etapu III)
- ustawionymi stylami (symbology, etykiety, kolory) dla każdej warstwy
- layoutami wydruku map tematycznych (`Project → Layouts`)

## Połączenie z bazą danych w QGIS

Sama procedura zestawienia połączenia PostGIS w QGIS została opisana w [2_Etap_II_readme.md](2_Etap_II_readme.md) (sekcja „Import danych z bazy danych do programu QGIS"). Tutaj tylko parametry, jakie należy wpisać dla aktualnego kontenera z [2_Etap_VI_konteneryzacja_readme.md](2_Etap_VI_konteneryzacja_readme.md):

| Parametr | Wartość       |
| -------- | ------------- |
| Host     | `localhost`   |
| Port     | `5422`        |
| Database | `PBD`         |
| User     | `postgres`    |
| Password | `postgres`    |

**Nazwa połączenia w QGIS jest dowolna**, ale musi być zachowana spójność - jeśli projekt pierwotnie był zapisany z połączeniem nazwanym np. `PBD`, najlepiej u siebie nadać taką samą nazwę, żeby QGIS automatycznie podpiął warstwy.

## Otwieranie projektu - kolejność jest istotna

Główny problem przy klonowaniu repo na inny komputer: QGIS zapisuje w `.qgz` ścieżki absolutne do źródeł danych, w tym do konkretnego połączenia PostGIS. Jeśli na nowej maszynie połączenie jeszcze nie istnieje, QGIS pokaże „Handle bad layers" lub po prostu warstwy będą czerwone w drzewku.

Kolejność, która działa najlepiej:

1. **Krok 1** - skonfiguruj połączenie PostGIS w QGIS **zanim** otworzysz projekt. Parametry jak w tabeli wyżej.
2. **Krok 2** - dopiero teraz `Project → Open` i wybierz [2_Etap_IV_Wizualizacja.qgz](2_Etap_IV_Wizualizacja.qgz). Jeśli ścieżki się zgadzają (taka sama nazwa połączenia, schematy `raw.*` / `analityka.*` istnieją w bazie), warstwy podejdą same i można od razu pracować.
3. **Krok 3** - gdy QGIS otworzy okno **Handle Bad Layers**, spróbuj:
   - `Auto-Find` (jeśli przycisk jest dostępny) - QGIS sam próbuje dopasować źródło,
   - albo `Browse` przy każdej warstwie i wskaż ręcznie połączenie PostGIS oraz docelową tabelę.
   - Następnie `Apply changes`. W większości przypadków to wystarcza.

## Plan B - ręczna naprawa, gdy auto-repair zawiódł

> **Uwaga krytyczna**: layouty wydruku odwołują się do warstw **po nazwie**. Jeśli usuniesz zerwaną warstwę i dodasz świeżą z domyślną nazwą (np. `analityka.L_drzewa_zagrazajace`), a oryginalna nazywała się np. `Drzewa zagrażające` - kompozycja wydruku przestanie pokazywać tę warstwę. Aby zachować layouty wydruku, **nowa warstwa musi mieć dokładnie taką samą nazwę jak ta, którą zastępuje**.

Procedura krok po kroku:

1. W panelu `Browser`: rozwiń `PostgreSQL → twoje połączenie → PBD → analityka` (lub `raw`).
2. Znajdź tabelę odpowiadającą zerwanej warstwie i przeciągnij ją do panelu `Layers`.
3. **Sprawdź oryginalną nazwę warstwy** w QGIS-owym oknie błędu z Kroku 3 lub w drzewku - jest tam wpis „bad" z oryginalną etykietą.
4. Na nowo dodanej warstwie: prawym → `Rename Layer` → wpisz **dokładnie** tę samą nazwę co miała zerwana wersja.
5. Skopiuj styl ze starej (zerwanej) warstwy:
   - Na zerwanej warstwie: prawym → `Styles → Copy Style → All Style Categories`. QGIS pamięta parametry stylu z pliku `.qgz` mimo że warstwa jest „bad".
   - Na nowej warstwie: prawym → `Styles → Paste Style`.
6. Usuń wersję „bad" (zerwaną) z drzewka.
7. Powtórz dla każdej kolejnej zerwanej warstwy.
8. `Project → Save` (`Ctrl+S`).

Po tym layouty wydruku powinny renderować się tak jak w oryginale, bo zachowano nazwy warstw i style.

## Mapy do oglądania bez QGIS

Gotowe mapy w postaci PDF leżą w [materialy/05_obrazy/wydruki_map/](../05_obrazy/wydruki_map/) - obecnie m.in. [Zapytania 1 i 4 Wołosz.pdf](../05_obrazy/wydruki_map/Zapytania%201%20i%204%20Wo%C5%82osz.pdf), z czasem mogą dochodzić kolejne.

Te same mapy są dostępne jako edytowalne layouty wewnątrz [2_Etap_IV_Wizualizacja.qgz](2_Etap_IV_Wizualizacja.qgz):
1. Otwórz projekt (po wykonaniu kroków powyżej).
2. `Project → Layouts` lub menu `Project → Layout Manager`.
3. Wybierz layout z listy → otwiera się w osobnym oknie kompozycji.
4. Z tego okna można eksportować do PDF/PNG (`Layout → Export as PDF/Image`) lub edytować legendy, skale, podpisy.
