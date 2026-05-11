# =========================================================================
# VISUALIZATION TOOLS - MODUŁ WIZUALIZACJI
# =========================================================================

#' Histogramy rozkładów cech taksacyjnych
#'
#' @description Generuje nakładane na siebie histogramy dla dwóch lat, pozwalając na
#' wizualną ocenę przesunięcia trendów wtbranych cech drzewostanu.
#'
#' @param df_2015 Dane przetworzone z roku 2015.
#' @param df_2025 Dane przetworzone z roku 2025.
#' @param parameter Nazwa cechy taksacyjnej (np. "height", "age").
#' @param title Tytuł wykresu.
#' @param unit Jednostka miary do wyświetlenia na osi X.
#' @return Obiekt klasy ggplot.
plot_structure_comparison <- function(df_2015, df_2025, parameter, title, unit) {
  # 1. Przygotowanie danych
  # w procesie przygotowania danych (prepare_forest_data) każda cecha została
  # wzbogacona o prefix określający rok, stąd użycie starts_with
  distribution_2015 <- df_2015 %>%
    select(id, value = starts_with(parameter)) %>%
    mutate(year = "2015")

  distribution_2025 <- df_2025 %>%
    select(id, value = starts_with(parameter)) %>%
    mutate(year = "2025")

  # Połączenie wierszowe
  plot_data <- bind_rows(distribution_2015, distribution_2025)

  # 2. Budowa wykresu
  ggplot(plot_data, aes(x = value, fill = year)) +
    # position = "identity" pozwala na nakładanie słupków na siebie
    geom_histogram(position = "identity", alpha = 0.5, bins = 30, color = "white") +
    labs(
      title = title,
      x = paste(str_to_title(parameter), unit),
      y = "Number of Subareas", # Liczba wydzieleń
      fill = "Year"
    ) +
    theme_minimal() +
    # Ujednolicenie kolorystyki
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
#' @return Obiekt klasy ggplot.
plot_species_area_change <- function(df_2015, df_2025, map_2015, map_2025) {
  # 1. Obliczanie realnej powierzchni [ha] z geometrii (st_area)
  gdf_area_2015 <- map_2015 %>%
    mutate(area_ha = as.numeric(st_area(.)) / 10000) %>%
    st_drop_geometry() %>%
    select(id = a_i_num, area_ha) %>%
    mutate(id = as.character(id))

  gdf_area_2025 <- map_2025 %>%
    mutate(area_ha = as.numeric(st_area(.)) / 10000) %>%
    st_drop_geometry() %>%
    select(id = a_i_num, area_ha) %>%
    mutate(id = as.character(id))

  # 2. Agregacja powierzchni wg gatunków (2015)
  area_per_species_2015 <- df_2015 %>%
    left_join(gdf_area_2015, by = "id") %>%
    select(species_code = starts_with("species"), area_ha) %>%
    group_by(species_code) %>%
    summarise(total_area = sum(area_ha, na.rm = TRUE)) %>%
    mutate(year = "2015")

  # 3. Agregacja powierzchni wg gatunków (2025)
  area_per_species_2025 <- df_2025 %>%
    left_join(gdf_area_2025, by = "id") %>%
    select(species_code = starts_with("species"), area_ha) %>%
    group_by(species_code) %>%
    summarise(total_area = sum(area_ha, na.rm = TRUE)) %>%
    mutate(year = "2025")

  # 4. Wykres słupkowy - reorder sortuje gatunki od najliczniejszego
  ggplot(
    bind_rows(area_per_species_2015, area_per_species_2025),
    aes(x = reorder(species_code, -total_area), y = total_area, fill = year)
  ) +
    geom_bar(stat = "identity", position = "dodge") +
    labs(
      title = "Dominant Species Area Change",
      x = "Species Code",
      y = "Total Area [ha]",
      fill = "Year"
    ) +
    theme_minimal() +
    scale_fill_manual(values = c("2015" = "#feb24c", "2025" = "#f03b20"))
}

#' Rozkład cech w rozbiciu na główne gatunki
#'
#' @description Wykonuje analizę rozkładu dla 5 najliczniejszych gatunków, prezentując
#' wyniki w formie siatki wykresów (faceting).
#'
#' @param df_2015 Dane 2015.
#' @param df_2025 Dane 2025.
#' @param parameter Nazwa cechy (np. "age").
#' @param x_axis_unit Jednostka do opisu osi X.
#' @return Obiekt klasy ggplot.
plot_structure_by_species <- function(df_2015, df_2025, parameter, x_axis_unit) {
  # 1. Wybór TOP 10 gatunków (wg liczby wydzieleń w 2025)
  top_species_list <- df_2025 %>%
    select(species_code = starts_with("species")) %>%
    count(species_code) %>%
    slice_max(n, n = 10) %>%
    pull(species_code)

  # 2. Przygotowanie danych do podziału na subploty
  top_species_distribution_2015 <- df_2015 %>%
    select(id, species_code = starts_with("species"), value = starts_with(parameter)) %>%
    filter(species_code %in% top_species_list) %>%
    mutate(year = "2015")

  top_species_distribution_2025 <- df_2025 %>%
    select(id, species_code = starts_with("species"), value = starts_with(parameter)) %>%
    filter(species_code %in% top_species_list) %>%
    mutate(year = "2025")

  # 3. Wykres z użyciem facet_wrap (tworzy sub-ploty dla każdego gatunku)
  ggplot(bind_rows(top_species_distribution_2015, top_species_distribution_2025), aes(x = value, fill = year)) +
    geom_histogram(position = "identity", alpha = 0.5, bins = 20, color = "white") +
    # 'free_y' dopasowuje skalę Y do każdego gatunku
    facet_wrap(~species_code, scales = "free_y") +
    labs(
      title = paste(str_to_title(parameter), "Distribution by Species"),
      x = x_axis_unit,
      y = "Number of Subareas" # Liczba wydzieleń
    ) +
    theme_light() +
    scale_fill_manual(values = c("2015" = "orange", "2025" = "purple"))
}
