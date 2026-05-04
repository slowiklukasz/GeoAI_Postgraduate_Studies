##############################################################################
# 1. SKRÓTY KLAWISZOWE -------------------------------------------------------
##############################################################################

# ctrl+shift+c  - komentowanie/odkomentowanie kodu
# ctrl+shift+r  - tworzenie nowej sekcji kodu
# ctrl+alt+r    - uruchomienie całego skryptu


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
DIR_PLOTS  <- "output/plots"
DIR_MAPS   <- "output/maps"


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
if (!dir.exists(DIR_TABLES)) { dir.create(DIR_TABLES, recursive = TRUE) }
if (!dir.exists(DIR_PLOTS))  { dir.create(DIR_PLOTS, recursive = TRUE) }
if (!dir.exists(DIR_MAPS))   { dir.create(DIR_MAPS, recursive = TRUE) }


##############################################################################
# 6. IMPORT DANYCH -----------------------------------------------------------
##############################################################################

# Import danych taksacyjnych (atrybuty) oraz geometrycznych (granice wydzieleń)

storey_species_2015 <- read.table(
  file.path(DIR_IN_2015, "f_storey_species.txt"), sep='\t', header = TRUE)

storey_species_2025 <- read.table(
  file.path(DIR_IN_2025, "f_storey_species.txt"), sep='\t', header = TRUE)

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
  dominant_species_2015, dominant_species_2025, "age", "Age Distribution", "[years]")

plot_height_structure <- plot_structure_comparison(
  dominant_species_2015, dominant_species_2025, "height", "Height Distribution", "[m]")

plot_volume_structure <- plot_structure_comparison(
  dominant_species_2015, dominant_species_2025, "volume", "Volume Distribution", "[m3/ha]")

# Analiza powierzchniowa i struktura szczegółowa

plot_area_change <- plot_species_area_change(
  dominant_species_2015, dominant_species_2025, forest_layer_2015, forest_layer_2025)

plot_age_by_species <- plot_structure_by_species(
  dominant_species_2015, dominant_species_2025, "age", "[years]")

# Eksport produktów graficznych

save_plot(plot_age_structure, "1_age_structure.png", DIR_PLOTS)
save_plot(plot_height_structure, "2_height_structure.png", DIR_PLOTS)
save_plot(plot_volume_structure, "3_volume_structure.png",DIR_PLOTS)
save_plot(plot_area_change, "4_species_area_change.png", DIR_PLOTS)
save_plot(plot_age_by_species,"5_age_by_species.png", DIR_PLOTS, w = 12, h = 8)


##############################################################################
# 9. MAPY PORÓWNAWCZE --------------------------------------------------------
##############################################################################

# Generowanie i eksport map różnic cech na podstawie warstwy geometrycznej
# Wykorzystanie własnych funkcji: functions/spatial_tools.R
project_maps <- create_comparison_maps(forest_layer_2025, comparison_table)

# Eksport map do katalogu DIR_MAPS
save_plot(project_maps$height, "map_height_diff.png", DIR_MAPS, h = 8)
save_plot(project_maps$volume, "map_volume_diff.png", DIR_MAPS, h = 8)
save_plot(project_maps$dbh,"map_dbh_diff.png", DIR_MAPS, h = 8)
save_plot(project_maps$species_change, "map_species_change.png", DIR_MAPS, h = 8)


