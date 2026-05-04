# =========================================================================
# VISUALIZATION TOOLS - MODUŁ WIZUALIZACJI
# =========================================================================

#' Hitogramy rozkładów cech taksacyjnych
#' 
#' @description Generuje nakładane na siebie histogramy dla dwóch lat, pozwalając na 
#' wizualną ocenę przesunięcia trendów wtbranych cech drzewostanu.
#' 
#' @param df_2015 Dane przetworzone z roku 2015.
#' @param df_2025 Dane przetworzone z roku 2025.
#' @param variable_prefix Nazwa cechy taksacyjnej (np. "height", "age").
#' @param title Tytuł wykresu.
#' @param unit Jednostka miary do wyświetlenia na osi X.
plot_structure_comparison <- function(df_2015, df_2025, variable_prefix, title, unit) {
  
  # 1. Przygotowanie danych (Selekcja kolumn o określonym prefiksie)
  d1 <- df_2015 %>% 
    select(id, value = starts_with(variable_prefix)) %>% 
    mutate(year = "2015")
  
  d2 <- df_2025 %>% 
    select(id, value = starts_with(variable_prefix)) %>% 
    mutate(year = "2025")
  
  # Połączenie wierszowe (format 'long' idealny dla ggplot2)
  plot_data <- bind_rows(d1, d2)
  
  # 2. Budowa wykresu
  ggplot(plot_data, aes(x = value, fill = year)) +
    # position = "identity" pozwala na nakładanie słupków na siebie
    geom_histogram(position = "identity", alpha = 0.5, bins = 30, color = "white") +
    labs(
      title = title, 
      x = paste(variable_prefix, unit), 
      y = "Liczba wydzieleń", 
      fill = "Rok"
    ) +
    theme_minimal() +
    # Ujednolicona kolorystyka dla lat
    scale_fill_manual(values = c("2015" = "steelblue", "2025" = "darkgreen"))
}

#' Analiza zmian powierzchniowych gatunków dominujących
#' 
#' @description Oblicza sumaryczną powierzchnię (w ha) dla każdego gatunku na podstawie 
#' geometrii wydzieleń i porównuje ją między latami na wykresie słupkowym.
#' 
#' @param df_2015 Dane atrybutowe 2015.
#' @param df_2025 Dane atrybutowe 2025.
#' @param map_2015 Warstwa geometryczna 2015.
#' @param map_2025 Warstwa geometryczna 2025.
plot_species_area_change <- function(df_2015, df_2025, map_2015, map_2025) {
  
  # 1. Obliczanie realnej powierzchni [ha] z geometrii (st_area)
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
  
  # 2. Agregacja powierzchni wg gatunków (2015)
  s1 <- df_2015 %>% 
    left_join(area_15, by = "id") %>% 
    select(species = starts_with("species"), area_ha) %>% 
    group_by(species) %>% 
    summarise(total_area = sum(area_ha, na.rm = TRUE)) %>% 
    mutate(year = "2015")
  
  # 3. Agregacja powierzchni wg gatunków (2025)
  s2 <- df_2025 %>% 
    left_join(area_25, by = "id") %>% 
    select(species = starts_with("species"), area_ha) %>% 
    group_by(species) %>% 
    summarise(total_area = sum(area_ha, na.rm = TRUE)) %>% 
    mutate(year = "2025")
  
  # 4. Wykres słupkowy (Bar Chart) - reorder sortuje gatunki od najliczniejszego
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

#' Rozkład cech w rozbiciu na główne gatunki (Panele)
#' 
#' @description Wykonuje analizę rozkładu dla 5 najliczniejszych gatunków, prezentując 
#' wyniki w formie siatki wykresów (faceting).
#' 
#' @param df_2015 Dane 2015.
#' @param df_2025 Dane 2025.
#' @param variable_prefix Nazwa cechy (np. "age").
#' @param unit Jednostka do opisu osi X.
plot_structure_by_species <- function(df_2015, df_2025, variable_prefix, unit) {
  
  # 1. Wybór TOP 5 gatunków (wg liczby wydzieleń w 2025)
  top_species_list <- df_2025 %>% 
    select(sp = starts_with("species")) %>% 
    count(sp) %>% 
    slice_max(n, n = 5) %>% 
    pull(sp)
  
  # 2. Przygotowanie danych do podziału na panele
  d1 <- df_2015 %>% 
    select(id, species = starts_with("species"), value = starts_with(variable_prefix)) %>% 
    filter(species %in% top_species_list) %>% 
    mutate(year = "2015")
  
  d2 <- df_2025 %>% 
    select(id, species = starts_with("species"), value = starts_with(variable_prefix)) %>% 
    filter(species %in% top_species_list) %>% 
    mutate(year = "2025")
  
  # 3. Wykres z użyciem facet_wrap (tworzy sub-ploty dla każdego gatunku)
  ggplot(bind_rows(d1, d2), aes(x = value, fill = year)) +
    geom_histogram(position = "identity", alpha = 0.5, bins = 20, color = "white") +
    facet_wrap(~species, scales = "free_y") + # 'free_y' dopasowuje skalę Y do każdego gatunku
    labs(
      title = paste("Rozkład", variable_prefix, "dla głównych gatunków"), 
      x = unit, 
      y = "Liczba wydzieleń"
    ) +
    theme_light() + 
    scale_fill_manual(values = c("2015" = "orange", "2025" = "purple"))
}