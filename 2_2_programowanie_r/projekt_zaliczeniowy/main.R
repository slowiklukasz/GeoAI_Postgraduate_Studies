##############################################################################
# 1. SKRÓTY KLAWISZOWE -------------------------------------------------------
##############################################################################

# ctrl+shift+c  - komentowanie kodu
# ctrl+shift+r  - tworzenie zakładki
# ctrl+alt+r    - odpalenie całego plku

##############################################################################
# 2. IMPORT FUNKCJI ----------------------------------------------------------
##############################################################################

source("functions/setup_env.R")
source("functions/data_processing.R")
source("functions/visualization_tools.R")
source("functions/spatial_tools.R")

##############################################################################
# 3. INSTALACJA I IMPRT BIBLIOTEK --------------------------------------------
##############################################################################

libraries_to_use <- c("tidyverse", "sf", "mapview", "ggspatial")
safe_library(libraries_to_use)

##############################################################################
# 4. KONFIGURACJA SCIEŻEK ZAPISÓW --------------------------------------------
##############################################################################
DIR_IN_2015 <- "./Data/BDL_03_21_PIWNICZNA_2015"
DIR_IN_2025 <- "./Data/BDL_03_21_PIWNICZNA_2025"

DIR_TABELE  <- "output/tables"
DIR_WYKRESY <- "output/plots"
DIR_MAPY    <- "output/maps"

if (!dir.exists(DIR_TABELE)) {
  dir.create(DIR_TABELE, recursive = TRUE)
}

if (!dir.exists(DIR_WYKRESY)) {
  dir.create(DIR_WYKRESY, recursive = TRUE)
}

if (!dir.exists(DIR_MAPY)) {
  dir.create(DIR_MAPY, recursive = TRUE)
}


##############################################################################
# 5. IMPORT DANYCH -----------------------------------------------------------
##############################################################################
# Dane jakie należy wykorzystać:
# 1. f_storey_species.txt – dane o gatunkach w piętrach
# 2. g_subarea.shp – warstwa geometryczna wydzieleń leśnych

# Import plików tekstowych (atrybuty)
atrybuty_gatunkowe_2015 <- read.table(
  file.path(DIR_IN_2015, "f_storey_species.txt"), sep='\t', header = T)

atrybuty_gatunkowe_2025 <- read.table(
  file.path(DIR_IN_2025, "f_storey_species.txt"), sep='\t', header = T)

# Import plików geometrycznych (mapy)
wydzielenia_2015 <- read_sf(file.path(DIR_IN_2015, "G_SUBAREA.shp"))
wydzielenia_2025 <- read_sf(file.path(DIR_IN_2025, "G_SUBAREA.shp"))

##############################################################################
# 6. ZESTAWIENIE GATUNKÓW ORAZ ICH CECH DLA WYDZIELEN W 2015 I 2025 ----------
##############################################################################

# 1. Przygotowanie danych (filtrowanie i zmiana nazw)
gatunki_panujace_2015 <- prepare_forest_data(atrybuty_gatunkowe_2015, "2015")
gatunki_panujace_2025 <- prepare_forest_data(atrybuty_gatunkowe_2025, "2025")

# 2. Tworzenie zestawienia porównawczego za pomocą nowej funkcji
zestawienie_2015_2025 <- 
  create_comparison_table(
    gatunki_panujace_2015,
    gatunki_panujace_2025
  )

# 3. Zapis do CSV
write_csv(
  zestawienie_2015_2025, 
  file.path(DIR_TABELE, "zestawienie_gatunkow_2015_2025.csv")
)

##############################################################################
# 7. WIZUALIZACJA PORÓWNAWCZA ------------------------------------------------
##############################################################################

# 1. Porównanie struktury wieku
wykres_struktury_wieku <- plot_structure_comparison(
  gatunki_panujace_2015, gatunki_panujace_2025, 
  "wiek", "Struktura wiekowa: 2015 vs 2025", "[lat]"
)
zapisz_wykres(wykres_struktury_wieku, "1_struktura_wieku.png")
print(wykres_struktury_wieku)

# 2. Porównanie struktury wysokości
wykres_struktury_wysokosci <- plot_structure_comparison(
  gatunki_panujace_2015, gatunki_panujace_2025, 
  "wys", "Struktura wysokościowa: 2015 vs 2025", "[m]"
)
zapisz_wykres(wykres_struktury_wysokosci, "2_struktura_wysokosci.png")
print(wykres_struktury_wysokosci)

# 3. Porównanie struktury miąższości
wykres_struktury_miazszosci <- plot_structure_comparison(
  gatunki_panujace_2015, gatunki_panujace_2025, 
  "vol", "Struktura miąższościowa: 2015 vs 2025", "[m3/ha]"
)
zapisz_wykres(wykres_struktury_miazszosci, "3_struktura_miazszosci.png")
print(wykres_struktury_miazszosci)

# 4. Zmiana powierzchniowa gatunków panujących
wykres_zmiany_powierzchni_gatunkow <- plot_species_area_change(
  gatunki_panujace_2015, gatunki_panujace_2025, 
  wydzielenia_2015, wydzielenia_2025
)
zapisz_wykres(wykres_zmiany_powierzchni_gatunkow, "4_zmiana_powierzchniowa.png")
print(wykres_zmiany_powierzchni_gatunkow)

# 5. Analiza szczegółowa: Struktura wieku w rozbiciu na gatunki
wykres_wieku_wedlug_gatunkow <- plot_structure_by_species(
  gatunki_panujace_2015, gatunki_panujace_2025, 
  "wiek", "[lat]"
)
# Ten wykres jest szerszy (panele), więc podajemy inne wymiary (w=12, h=8)
zapisz_wykres(wykres_wieku_wedlug_gatunkow, "5_struktura_wieku_gatunki.png", w = 12, h = 8)
print(wykres_wieku_wedlug_gatunkow)


##############################################################################
# 8. MAPY PORÓWNAWCZE --------------------------------------------------------
##############################################################################

# 1. Generujemy mapy za pomocą funkcji z spatial_tools.R
mapy_projektowe <- create_comparison_maps(wydzielenia_2025, zestawienie_2015_2025)

# 2. Wyświetlamy mapy w oknie Plots
print(mapy_projektowe$wys)
print(mapy_projektowe$vol)
print(mapy_projektowe$bhd)
print(mapy_projektowe$gat)

# 3. Zapisujemy mapy jako pliki graficzne (używając stałej DIR_MAPY i file.path)
ggsave(file.path(DIR_MAPY, "mapa_roznica_wysokosci.png"), mapy_projektowe$wys, width = 10, height = 8, bg = "white")
ggsave(file.path(DIR_MAPY, "mapa_roznica_miazszosci.png"), mapy_projektowe$vol, width = 10, height = 8, bg = "white")
ggsave(file.path(DIR_MAPY, "mapa_roznica_piersnicy.png"), mapy_projektowe$bhd, width = 10, height = 8, bg = "white")
ggsave(file.path(DIR_MAPY, "mapa_zmiana_gatunku.png"),    mapy_projektowe$gat, width = 10, height = 8, bg = "white")

message("Mapy zostały zapisane w folderze: ", DIR_MAPY)
message("--- PROJEKT ZAKOŃCZONY POMYŚLNIE ---")

