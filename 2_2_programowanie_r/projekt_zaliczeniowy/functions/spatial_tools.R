# =========================================================================
# SPATIAL TOOLS - MODUŁ ANALIZ PRZESTRZENNYCH I MAP
# =========================================================================

#' Uniwersalny generator map dla wydzieleń leśnych
#' 
#' @description Funkcja tworzy mapę tematyczną na podstawie obiektu sf, wykorzystując 
#' ujednolicony styl graficzny (białe tło, czarne obramowania wydzieleń).
#' 
#' @param data Obiekt klasy sf zawierający geometrię i atrybuty.
#' @param variable Nazwa kolumny, która ma zostać zmapowana.
#' @param title Tytuł wyświetlany nad mapą.
#' @param scale_name Opis wyświetlany nad legendą.
#' @param palette Wybrana paleta kolorystyczna z pakietu viridis (domyślnie "viridis").
#' 
#' @return Obiekt ggplot przedstawiający mapę tematyczną.
make_forest_map <- function(data, variable, title, scale_name, palette = "viridis") {
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

#' Generowanie zestawu map porównawczych dla nadleśnictwa
#' 
#' @description Przygotowuje serię map przedstawiających różnice w cechach taksacyjnych 
#' (wysokość, miąższość, pierśnica) oraz zmiany gatunku dominującego między latami.
#' 
#' @param forest_layer Warstwa geometryczna wydzieleń (obiekt sf).
#' @param comparison_data Tabela z obliczonymi różnicami (comparison_table).
#' 
#' @return Lista zawierająca cztery obiekty ggplot (mapy cech i zmiany gatunku).
create_comparison_maps <- function(forest_layer, comparison_data) {
  
  # 1. Przygotowanie danych (Spatial Join po ID)
  map_data <- forest_layer %>%
    mutate(id = as.character(a_i_num)) %>%
    left_join(comparison_data, by = "id")
  
  # 2. Generowanie map przyrostów (używając zewnętrznego generatora)
  m_height <- make_forest_map(map_data, "diff_height", "Height Change (2015-2025)", "meters [m]")
  m_volume <- make_forest_map(map_data, "diff_volume", "Volume Change (2015-2025)", "m3/ha", "magma")
  m_dbh    <- make_forest_map(map_data, "diff_dbh",    "DBH Change (2015-2025)",    "cm", "plasma")
  
  # 3. Specyficzna mapa zmiany gatunku
  m_species <- ggplot(map_data) +
    geom_sf(aes(fill = species_change), color = "black", size = 0.05) +
    scale_fill_manual(
      values = c("YES" = "#e41a1c", "NO" = "#4daf4a"), 
      name = "Species Shift",
      na.value = "gray95"
    ) +
    labs(title = "Dominant Species Shift (2015-2025)") +
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