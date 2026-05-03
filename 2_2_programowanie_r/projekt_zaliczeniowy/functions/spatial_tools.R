# =========================================================================
# SPATIAL TOOLS - MODUŁ ANALIZ PRZESTRZENNYCH I MAP
# =========================================================================

#' Generowanie map porównawczych dla nadleśnictwa
#' @param forest_layer Warstwa geometryczna wydzieleń (sf object)
#' @param comparison_data Tabela z obliczonymi różnicami (comparison_table)
create_comparison_maps <- function(forest_layer, comparison_data) {
  
  # 1. Przygotowanie danych
  map_data <- forest_layer %>%
    mutate(id = as.character(a_i_num)) %>%
    left_join(comparison_data, by = "id")
  
  # Funkcja pomocnicza z WYMUSZONYM BIAŁYM TŁEM
  make_map <- function(data, variable, title, scale_name, palette = "viridis") {
    ggplot(data) +
      geom_sf(aes(fill = .data[[variable]]), color = "black", size = 0.05) +
      scale_fill_viridis_c(option = palette, name = scale_name, na.value = "gray95") +
      labs(title = title) +
      theme_void() +
      theme(
        plot.background = element_rect(fill = "white", color = NA),
        panel.background = element_rect(fill = "white", color = NA),
        legend.position = "right"
      )
  }
  
  # 2. Generowanie map różnic
  m_height <- make_map(map_data, "diff_height", "Height Difference (2015-2025)", "meters [m]")
  m_volume <- make_map(map_data, "diff_volume", "Volume Difference (2015-2025)", "m3/ha", "magma")
  m_dbh    <- make_map(map_data, "diff_dbh",    "DBH Difference (2015-2025)",    "cm", "plasma")
  
  # 3. Mapa zmiany gatunku z BIAŁYM TŁEM
  m_species <- ggplot(map_data) +
    geom_sf(aes(fill = species_change), color = "black", size = 0.05) +
    scale_fill_manual(
      values = c("YES" = "#e41a1c", "NO" = "#4daf4a"), 
      name = "Species Change",
      na.value = "gray95"
    ) +
    labs(title = "Dominant Species Shift") +
    theme_void() +
    theme(
      plot.background = element_rect(fill = "white", color = NA),
      panel.background = element_rect(fill = "white", color = NA)
    )
  
  return(list(
    height = m_height, 
    volume = m_volume, 
    dbh = m_dbh, 
    species_change = m_species
  ))
}