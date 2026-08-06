##############################################################################
# 1. INSTRUKCJA URUCHOMIENIA / RUN INSTRUCTIONS ------------------------------
##############################################################################

# KROK 1: Konfiguracja ścieżek do katalogów z danymi BDL w sekcji nr 2 (DIR_IN_...).
# KROK 2: Uruchomienie przetwarzania skrótem: CTRL + ALT + R.
# KROK 3: Automatyczne generowanie wyników (CSV, Wykresy, Mapy) w katalogu /output.

# Skrypt zapewnia automatyczną weryfikację środowiska oraz instalację 
# brakujących bibliotek. Architektura projektu oparta jest na modułach tematycznych 
# zlokalizowanych w katalogu /functions.

##############################################################################
# 2. KONFIGURACJA ŚCIEŻEK ----------------------------------------------------
##############################################################################

# Definicja ścieżek wejściowych (Input) i wyjściowych (Output)
# Katalogi tworzone automatycznie jeśli nie istnieją

# Input
DIR_IN_2015 <- "./Data/BDL_03_21_PIWNICZNA_2015"
DIR_IN_2025 <- "./Data/BDL_03_21_PIWNICZNA_2025"

# Output
DIR_TABLES <- "output/tables"
DIR_PLOTS <- "output/plots"
DIR_MAPS <- "output/maps"


##############################################################################
# 3. IMPORT WŁASNYCH FUNKCJI -------------------------------------------------
##############################################################################

# Wczytanie modułów z własnymi funkcjami
# Lokalizacja: katalog functions/

source("functions/setup_env.R")
source("functions/data_processing.R")
source("functions/visualization_tools.R")
source("functions/spatial_tools.R")
source("functions/utils.R")


##############################################################################
# 4. INSTALACJA I ŁADOWANIE BIBLIOTEK ----------------------------------------
##############################################################################

# Automatyczna instalacja i ładowanie potrzebnych bibliotek
# Wykorzystanie własnej funkcji: functions/setup_env.R -> safe_library()

libraries_to_use <- c("tidyverse", "sf", "mapview", "ggspatial")
safe_library(libraries_to_use)


##############################################################################
# 5. TWORZENIE STRUKTURY KATALOGÓW WYNIKOWYCH -------------------------------
##############################################################################


if (!dir.exists(DIR_TABLES)) {
  dir.create(DIR_TABLES, recursive = TRUE)
}
if (!dir.exists(DIR_PLOTS)) {
  dir.create(DIR_PLOTS, recursive = TRUE)
}
if (!dir.exists(DIR_MAPS)) {
  dir.create(DIR_MAPS, recursive = TRUE)
}


##############################################################################
# 6. IMPORT DANYCH -----------------------------------------------------------
##############################################################################

# Import danych taksacyjnych (atrybuty) oraz geometrycznych (granice wydzieleń)

storey_species_2015 <- read.table(
  file.path(DIR_IN_2015, "f_storey_species.txt"),
  sep = "\t", header = TRUE
)

storey_species_2025 <- read.table(
  file.path(DIR_IN_2025, "f_storey_species.txt"),
  sep = "\t", header = TRUE
)

forest_layer_2015 <- read_sf(file.path(DIR_IN_2015, "G_SUBAREA.shp"))
forest_layer_2025 <- read_sf(file.path(DIR_IN_2025, "G_SUBAREA.shp"))


##############################################################################
# 7. ANALIZA PORÓWNAWCZA CECH GATUNKOWYCH (2015 VS 2025) ---------------------
##############################################################################

# Przetwarzanie danych i tworzenie tabeli porównawczej
# Wykorzystanie własnych funkcji: functions/data_processing.R
# Eksport zestawienia do CSV

dominant_species_2015 <- prepare_forest_data(storey_species_2015, "2015")
dominant_species_2025 <- prepare_forest_data(storey_species_2025, "2025")

comparison_table <- create_comparison_table(dominant_species_2015, dominant_species_2025)

write_csv(
  comparison_table,
  file.path(DIR_TABLES, "species_comparison_2015_2025.csv")
)


##############################################################################
# 8. WIZUALIZACJA STATYSTYK -- -----------------------------------------------
##############################################################################

# Generowanie wykresów porównawczych cech taksacyjnych
# Wykorzystanie własnych funkcji: functions/visualization_tools.R

plot_age_structure <- plot_structure_comparison(
  dominant_species_2015, dominant_species_2025,
  parameter = "age",
  title = "Age Distribution",
  unit = "[years]"
)
plot_height_structure <- plot_structure_comparison(
  dominant_species_2015, dominant_species_2025,
  parameter = "height",
  title = "Forest Height Distribution",
  unit = "[m]"
)
plot_volume_structure <- plot_structure_comparison(
  dominant_species_2015, dominant_species_2025,
  parameter = "volume",
  title = "Volume Distribution",
  unit = "[m3/ha]"
)

# Analiza powierzchniowa i dystrybucja wieku dla różnych gatunków

plot_area_change <- plot_species_area_change(
  dominant_species_2015, dominant_species_2025, forest_layer_2015, forest_layer_2025
)

plot_age_by_species <- plot_structure_by_species(
  dominant_species_2015, dominant_species_2025, "age", "[years]"
)

# Eksport grafik

save_plot(plot_age_structure, "age_structure.png", DIR_PLOTS)
save_plot(plot_height_structure, "height_structure.png", DIR_PLOTS)
save_plot(plot_volume_structure, "volume_structure.png", DIR_PLOTS)
save_plot(plot_area_change, "species_area_change.png", DIR_PLOTS)
save_plot(plot_age_by_species, "age_by_species.png", DIR_PLOTS, w = 12, h = 8)


##############################################################################
# 9. MAPY PORÓWNAWCZE --------------------------------------------------------
##############################################################################

# Generowanie i eksport map różnic cech na podstawie warstwy geometrycznej
# Wykorzystanie własnych funkcji: functions/spatial_tools.R

project_maps <- create_comparison_maps(forest_layer_2025, comparison_table)

# Eksport map do katalogu DIR_MAPS

save_plot(project_maps$height, "height_difference.png", DIR_MAPS, h = 8)
save_plot(project_maps$volume, "volume_difference.png", DIR_MAPS, h = 8)
save_plot(project_maps$dbh, "dbh_difference.png", DIR_MAPS, h = 8)
save_plot(project_maps$species_change, "species_change.png", DIR_MAPS, h = 8)
