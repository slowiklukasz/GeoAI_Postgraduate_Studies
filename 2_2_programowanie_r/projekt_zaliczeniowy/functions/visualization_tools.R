# =========================================================================
# VISUALIZATION TOOLS - MODUŁ WIZUALIZACJI
# =========================================================================

# 1. Funkcja pomocnicza do ujednoliconego eksportu wykresów
# Domyślnie zapisuje w DIR_PLOTS zdefiniowanym w main.R
save_plot <- function(plot_obj, filename, folder = DIR_PLOTS, w = 10, h = 6) {
  full_path <- file.path(folder, filename)
  
  # Zapis za pomocą ggsave (300 DPI zapewnia jakość do druku)
  ggsave(
    filename = full_path, 
    plot = plot_obj, 
    width = w, 
    height = h, 
    dpi = 300, 
    bg = "white"
  )
  message("Eksportowano produkt graficzny: ", filename)
}

# 2. Porównanie rozkładów (Histogramy: Wiek, Wysokość, Miąższość)
plot_structure_comparison <- function(df_2015, df_2025, variable_prefix, title, unit) {
  
  # Przygotowanie danych - dynamiczne wybieranie kolumn i ujednolicanie nazw
  d1 <- df_2015 %>% 
    select(id, value = starts_with(variable_prefix)) %>% 
    mutate(year = "2015")
  
  d2 <- df_2025 %>% 
    select(id, value = starts_with(variable_prefix)) %>% 
    mutate(year = "2025")
  
  plot_data <- bind_rows(d1, d2)
  
  # Tworzenie histogramu z nałożonymi kolorami (alpha = 0.5)
  ggplot(plot_data, aes(x = value, fill = year)) +
    geom_histogram(position = "identity", alpha = 0.5, bins = 30, color = "white") +
    labs(
      title = title, 
      x = paste(variable_prefix, unit), 
      y = "Liczba wydzieleń", 
      fill = "Rok"
    ) +
    theme_minimal() +
    scale_fill_manual(values = c("2015" = "steelblue", "2025" = "darkgreen"))
}

# 3. Zmiana powierzchniowa gatunków dominujących (w hektarach)
plot_species_area_change <- function(df_2015, df_2025, map_2015, map_2025) {
  
  # Obliczanie powierzchni z geometrii (przeliczenie na ha)
  # Używamy a_i_num jako klucza ID dla warstw wektorowych
  area_15 <- map_2015 %>% 
    mutate(area_ha = as.numeric(st_area(.)) / 10000) %>% 
    st_drop_geometry() %>% 
    select(id = a_i_num, area_ha) %>% 
    mutate(id = as.character(id))
  
  area_25 <- map_2025 %>% 
    mutate(area_ha = as.numeric(st_area(.)) / 10000) %>% 
    st_drop_geometry() %>% 
    select(id = a_i_num, area_ha) %>% 
    mutate(id = as.character(id))
  
  # Przetwarzanie 2015 - selekcja kolumn przed grupowaniem (naprawa błędu starts_with)
  s1 <- df_2015 %>% 
    left_join(area_15, by = "id") %>% 
    select(species = starts_with("species"), area_ha) %>% 
    group_by(species) %>% 
    summarise(total_area = sum(area_ha, na.rm = TRUE)) %>% 
    mutate(year = "2015")
  
  # Przetwarzanie 2025
  s2 <- df_2025 %>% 
    left_join(area_25, by = "id") %>% 
    select(species = starts_with("species"), area_ha) %>% 
    group_by(species) %>% 
    summarise(total_area = sum(area_ha, na.rm = TRUE)) %>% 
    mutate(year = "2025")
  
  # Wykres słupkowy (Bar Chart) porównujący sumy powierzchni
  ggplot(bind_rows(s1, s2), aes(x = reorder(species, -total_area), y = total_area, fill = year)) +
    geom_bar(stat = "identity", position = "dodge") +
    labs(
      title = "Zmiana powierzchniowa gatunków dominujących", 
      x = "Kod gatunku", 
      y = "Suma powierzchni [ha]", 
      fill = "Rok"
    ) +
    theme_minimal() + 
    scale_fill_manual(values = c("2015" = "#feb24c", "2025" = "#f03b20"))
}

# 4. Szczegółowa struktura dla 5 głównych gatunków (Panele / Faceting)
plot_structure_by_species <- function(df_2015, df_2025, variable_prefix, unit) {
  
  # Identyfikacja 5 najliczniejszych gatunków z roku 2025
  top_species_list <- df_2025 %>% 
    select(sp = starts_with("species")) %>% 
    count(sp) %>% 
    slice_max(n, n = 5) %>% 
    pull(sp)
  
  # Filtrowanie i przygotowanie danych do facetingu
  d1 <- df_2015 %>% 
    select(id, species = starts_with("species"), value = starts_with(variable_prefix)) %>% 
    filter(species %in% top_species_list) %>% 
    mutate(year = "2015")
  
  d2 <- df_2025 %>% 
    select(id, species = starts_with("species"), value = starts_with(variable_prefix)) %>% 
    filter(species %in% top_species_list) %>% 
    mutate(year = "2025")
  
  # Wykres panelowy (facet_wrap) - osobny histogram dla każdego gatunku
  ggplot(bind_rows(d1, d2), aes(x = value, fill = year)) +
    geom_histogram(position = "identity", alpha = 0.5, bins = 20, color = "white") +
    facet_wrap(~species, scales = "free_y") +
    labs(
      title = paste("Rozkład", variable_prefix, "dla głównych gatunków"), 
      x = unit, 
      y = "Liczba wydzieleń"
    ) +
    theme_light() + 
    scale_fill_manual(values = c("2015" = "orange", "2025" = "purple"))
}