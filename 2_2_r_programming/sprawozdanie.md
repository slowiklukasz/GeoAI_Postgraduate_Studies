# Sprawozdanie z opracowania projektu: Przetwarzanie i wizualizacja porównawcza danych taksacyjnych BDL (2015–2025)

**Autorzy:** Karol Pietruszka, Łukasz Słowik  
**Obiekt badań:** Nadleśnictwo Piwniczna  
**Środowisko:** R (RStudio / VS Code)

---

## 1. Cel i zakres prac
Celem zadania była implementacja zautomatyzowanego potoku przetwarzania danych, umożliwiającego porównanie cech taksacyjnych drzewostanów (wiek, wysokość, miąższość, pierśnica) w 10-letnim cyklu czasowym (2015–2025). Analiza skupiła się na gatunkach panujących w piętrze głównym.

## 2. Architektura systemu i opis funkcji
Projekt zaprojektowano w sposób modularny, co zapewnia wysoką czytelność i samotłumaczalność kodu. Nazewnictwo przygotowano w języku angielskim dla spójności z bibliotekami systemowymi, natomiast dokumentacja techniczna w standardzie **Roxygen2** jest w języku polskim.

### 2.1. Główny skrypt sterujący
*   **`main.R`**: Odpowiada za konfigurację stałych ścieżek wejściowych i wyjściowych, wczytywanie modułów zewnętrznych oraz sekwencyjne wywoływanie etapów przetwarzania i eksportu wyników.

### 2.2. Opis modułów i funkcji tematycznych

#### Moduł `functions/setup_env.R` (Automatyzacja środowiska)
*   `safe_library(packages)`: Funkcja porównuje listę wymaganych bibliotek z zasobami systemowymi, automatycznie instaluje braki z repozytorium CRAN i importuje pakiety do sesji.

#### Moduł `functions/data_processing.R` (Procesy ETL)
*   `prepare_forest_data(df_input, year_suffix)`: Realizuje czyszczenie danych (usuwanie spacji, rzutowanie typów), filtruje zbiór do warstwy DRZEW i gatunku dominującego (rank 1) oraz mapuje techniczne skróty BDL na czytelne nazwy techniczne z sufiksem roku.
*   `create_comparison_table(df_2015, df_2025)`: Integruje dane wieloczasowe metodą *Inner Join*, oblicza różnice dla cech taksacyjnych oraz implementuje logikę detekcji zmiany gatunku dominującego.

#### Moduł `functions/visualization_tools.R` (Wizualizacja statystyczna)
*   `plot_structure_comparison(...)`: Generuje histogramy nakładane (alpha = 0.5), umożliwiając wizualną ocenę przesunięcia trendów wzrostowych i starzenia się lasu na jednym wykresie.
*   `plot_species_area_change(...)`: Oblicza pole powierzchni poligonów bezpośrednio z geometrii (`st_area`), prezentując zmiany struktur gatunkowych w hektarach, co jest merytorycznie istotniejsze niż proste zliczanie wydzieleń.
*   `plot_structure_by_species(...)`: Realizuje analizę panelową dla 10 głównych gatunków, stosując zmienną skalę osi Y (`free_y`) dla zachowania czytelności rzadszych taksonów.

#### Moduł `functions/spatial_tools.R` (Analiza przestrzenna / Spatial Databases)
*   `make_forest_map(...)`: Uniwersalny szablon graficzny dla map tematycznych, zapewniający spójność wizualną (wycentrowane tytuły, palety Viridis).
*   `create_comparison_maps(...)`: Koordynuje generowanie zestawu map przyrostów cech oraz mapę kategoryczną zmiany gatunku panującego.

#### Moduł `functions/utils.R` (Narzędzia pomocnicze)
*   `save_plot(obj, filename, target_dir, w, h)`: Standaryzuje proces eksportu grafiki, wymuszając rozdzielczość 300 DPI, białe tło i ujednolicone wymiary plików PNG.

## 3. Wygenerowane produkty projektu
W wyniku działania skryptu, w katalogu `/output` wygenerowano następujące zbiory danych i wizualizacje:

### 3.1. Produkty tabelaryczne (katalog `/tables`)
*   **`species_comparison_2015_2025.csv`**: Tabela wynikowa (Master Table) zawierająca zestawienie cech taksacyjnych dla obu lat oraz obliczone przyrosty dla wysokości, miąższości i pierśnicy. Zawiera również flagę logiczną identyfikującą wydzielenia ze zmianą gatunku dominującego.

### 3.2. Wizualizacje statystyczne (katalog `/plots`)
*   **Histogramy rozkładów ogólnych**: Trzy wykresy (wiek, wysokość, miąższość) przedstawiające nakładające się rozkłady statystyczne dla lat 2015 i 2025.
*   **Wykres zmian powierzchniowych**: Zestawienie słupkowe sumarycznej powierzchni [ha] zajmowanej przez poszczególne gatunki dominujące w obu okresach.
*   **Szczegółowy rozkład wieku**: Z uwzględnieniem 10 najliczniejszych gatunków panujących.

### 3.3. Produkty kartograficzne (katalog `/maps`)
*   **Mapy różnic cech ciągłych**: Trzy mapy tematyczne (wysokość, miąższość, pierśnica) obrazujące przestrzenny wymiar przyrostów.
*   **Mapa zmiany gatunku**: Mapa kategoryczna wskazująca lokalizację wydzieleń, w których nastąpiła zmiana gatunku panującego w 10-letnim cyklu czasowym.

## 4. Podsumowanie i wnioski
Zastosowane zostało podejście bazujące na wykorzystaniu programowania funkcyjnego oraz silnej parametryzacji ścieżek. Narzędzie jest uniwersalne i może zostać wykorzystane do analizy dowolnego innego nadleśnictwa po zmianie stałych wejściowych w pliku `main.R`. Celem zachowania czytelności całość kodu została udokumentowana zgodnie ze standardem **Roxygen2**.

## 5. Wykorzystanie AI
W projekcie wykorzystano modele AI (LLM) do konsultacji składni języka R, wyszukiwania informacji o standardach opisu funkcji oraz wsparcia w redagowaniu dokumentacji technicznej. AI pełniło rolę narzędzia pomocniczego, pozwalającego na sprawne przeniesienie dobrych praktyk programistycznych ze środowiska Python do środowiska R.