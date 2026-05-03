library(sf)
library(ggplot2)

create_comparison_maps <- function(wydz_layer, zestawienie_data) {
  
  # 1. Przygotowanie danych przestrzennych (łączenie tabeli z mapą)
  map_data <- wydz_layer %>%
    mutate(id = as.character(a_i_num)) %>% # ID w mapie to a_i_num
    left_join(zestawienie_data, by = "id")
  
  # Funkcja pomocnicza do tworzenia mapy (żeby nie pisać 3 razy tego samego)
  make_map <- function(data, variable, title, scale_name, palette = "viridis") {
    ggplot(data) +
      geom_sf(aes(fill = .data[[variable]]), color = "black", size = 0.05) +
      scale_fill_viridis_c(option = palette, name = scale_name, na.value = "gray90") +
      labs(title = title) +
      theme_void() +
      theme(legend.position = "right")
  }
  
  # 2. Generowanie 3 map różnic cech
  m_wys <- make_map(map_data, "diff_wys", "Różnica wysokości (2015-2025)", "metry [m]")
  m_vol <- make_map(map_data, "diff_vol", "Różnica miąższości (2015-2025)", "m3/ha", "magma")
  m_bhd <- make_map(map_data, "diff_bhd", "Różnica pierśnicy (2015-2025)", "cm", "plasma")
  
  # 3. Mapa zmiany gatunku dominującego
  m_gat <- ggplot(map_data) +
    geom_sf(aes(fill = zmiana_gatunku), color = "black", size = 0.05) +
    scale_fill_manual(values = c("TAK" = "#e41a1c", "NIE" = "#4daf4a"), 
                      name = "Zmiana gatunku") +
    labs(title = "Zmiana gatunku dominującego",
         subtitle = "Czerwony kolor oznacza zmianę gatunku panującego w wydzieleniu") +
    theme_void()
  
  return(list(wys = m_wys, vol = m_vol, bhd = m_bhd, gat = m_gat))
}