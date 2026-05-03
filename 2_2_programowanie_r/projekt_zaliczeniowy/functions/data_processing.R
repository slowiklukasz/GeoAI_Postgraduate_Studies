# =========================================================================
# DATA PROCESSING - MODUŁ PRZETWARZANIA DANYCH
# =========================================================================

# 1. Przygotowanie danych jednostkowych dla konkretnego roku
# Filtruje dane do gatunku panującego i zmienia nazwy na angielskie (SOTA)
prepare_forest_data <- function(df_input, year_suffix) {
  
  processed <- df_input %>%
    # Czyszczenie tekstów i konwersja typów (zabezpieczenie przed błędami BDL)
    mutate(
      storey_cd = trimws(as.character(storey_cd)),
      sp_rank_order_act = as.numeric(sp_rank_order_act)
    ) %>%
    # Filtrowanie: tylko drzewostan główny i gatunek dominujący (Ranga 1)
    filter(storey_cd == "DRZEW", sp_rank_order_act == 1) %>%
    # Wybór kolumn i ujednolicenie nazw na angielski (dla spójności z wizualizacją)
    select(
      id = arodes_int_num,
      species = species_cd,
      age = species_age,
      height = height,
      dbh = bhd,
      volume = volume
    ) %>%
    # Konwersja ID na tekst, aby Join w kolejnym kroku był bezpieczny
    mutate(id = as.character(id))
  
  # Dynamiczne dodanie roku do nazw kolumn (np. height_2015)
  # Pozwala na uniknięcie konfliktów po złączeniu tabel
  colnames(processed)[2:6] <- paste0(colnames(processed)[2:6], "_", year_suffix)
  
  return(processed)
}

# 2. Tworzenie tabeli porównawczej (Master Table)
# Łączy dwa lata i oblicza przyrosty (Deltas)
create_comparison_table <- function(df_early, df_late) {
  
  # Łączenie tabel po unikalnym kluczu ID (Inner Join zostawia tylko wspólne rekordy)
  comparison <- df_early %>%
    inner_join(df_late, by = "id")
  
  # Obliczanie różnic (Deltas) i flagowanie zmian gatunkowych
  # Zakładamy, że sufiksy to 2015 i 2025 (zgodnie z main.R)
  comparison <- comparison %>%
    mutate(
      diff_height = height_2025 - height_2015,
      diff_volume = volume_2025 - volume_2015,
      diff_dbh    = dbh_2025 - dbh_2015,
      # Sprawdzenie czy nastąpiła zmiana gatunku panującego
      species_change = if_else(species_2015 != species_2025, "YES", "NO")
    )
  
  return(comparison)
}

# 3. Pobieranie powierzchni z warstwy geometrycznej (Helper)
# Przydatne do szybkich analiz przestrzennych poza ggplot
get_subarea_areas <- function(wydz_layer) {
  
  areas <- wydz_layer %>%
    st_drop_geometry() %>%
    # BDL w plikach SHP skraca nazwę arodes_int_num do a_i_num
    select(id = a_i_num, area_ha = area) %>% 
    mutate(id = as.character(id))
  
  return(areas)
}