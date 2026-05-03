# # Przetwarzanie danych dla 2015
# zestawienie_2015 <- fss_2015 %>%
#   filter(storey_cd == "DRZEW", sp_rank_order_act == 1) %>%
#   select(arodes_int_num, 
#          gat_2015 = species_cd, 
#          wiek_2015 = species_age, 
#          wys_2015 = height, 
#          bhd_2015 = bhd, 
#          vol_2015 = volume)

prepare_forest_data <- function(df, year_suffix) {
  
  df_clean <- df %>%
    # 1. Czyszczenie tekstów i wymuszenie typów
    mutate(
      storey_cd = trimws(as.character(storey_cd)),
      sp_rank_order_act = as.numeric(sp_rank_order_act)
    ) %>%
    # 2. Filtracja
    filter(storey_cd == "DRZEW", sp_rank_order_act == 1)
  
  # 3. Wybór kolumn i ujednolicenie ID do tekstu
  df_clean <- df_clean %>%
    select(
      id = arodes_int_num,
      gat = species_cd,
      wiek = species_age,
      wys = height,
      bhd = bhd,
      vol = volume
    ) %>%
    mutate(id = as.character(id))

  colnames(df_clean)[2:6] <- paste0(colnames(df_clean)[2:6], "_", year_suffix)
  
  return(df_clean)
}


create_comparison_table <- function(df_early, df_late) {
  
  # 1. Łączenie tabel po kolumnie 'id'
  # inner_join zostawia tylko te wydzielenia, które są w obu latach
  comparison <- df_early %>%
    inner_join(df_late, by = "id")
  
  # 2. Obliczanie różnic i sprawdzanie zmian
  comparison <- comparison %>%
    mutate(
      # Obliczamy przyrost wysokości
      diff_wys = wys_2025 - wys_2015,
      
      # Obliczamy przyrost miąższości (wolumenu)
      diff_vol = vol_2025 - vol_2015,
      
      # Sprawdzamy czy kod gatunku jest taki sam
      # if_else(warunek, prawda, fałsz)
      zmiana_gatunku = if_else(gat_2015 != gat_2025, "TAK", "NIE")
    )
  return(comparison)
}

get_subarea_areas <- function(wydz_layer) {
  # Wyciągamy ID i powierzchnię. 
  # st_drop_geometry() zamienia mapę w zwykłą tabelę (usuwa geometrię), co przyspiesza pracę.
  areas <- wydz_layer %>%
    st_drop_geometry() %>%
    select(id = arodes_int_num, powierzchnia = area) %>% 
    mutate(id = as.character(id))
  
  return(areas)
}

create_comparison_table <- function(df_early, df_late) {
  comparison <- df_early %>%
    inner_join(df_late, by = "id") %>%
    mutate(
      diff_wys = wys_2025 - wys_2015,
      diff_vol = vol_2025 - vol_2015,
      diff_bhd = bhd_2025 - bhd_2015, # DODAJEMY TO
      zmiana_gatunku = if_else(gat_2015 != gat_2025, "TAK", "NIE")
    )
  return(comparison)
}