# MAPY GATUNKÓW DOMINUJĄCYCH I RÓŻNIC CECH DRZEWOSTANU
# ============================================================

library(tidyverse)
library(sf)
library(RColorBrewer)

# ============================================================
# 1. UJEDNOLICENIE ID W GEOMETRII
# ============================================================

geom2015 <- bdl2015$geom %>%
  mutate(a_i_num = as.character(a_i_num))

geom2025 <- bdl2025$geom %>%
  mutate(a_i_num = as.character(a_i_num))

# ============================================================
# 2. POŁĄCZENIE GEOMETRII Z GATUNKIEM DOMINUJĄCYM
# ============================================================

geom_2015 <- geom2015 %>%
  left_join(dom2015, by = c("a_i_num" = "arodes_int_num")) %>%
  mutate(dom_2015 = as.factor(dom_2015))

geom_2025 <- geom2025 %>%
  left_join(dom2025, by = c("a_i_num" = "arodes_int_num")) %>%
  mutate(dom_2025 = as.factor(dom_2025))

# ============================================================
# 3. MAPA GATUNKU DOMINUJĄCEGO 2015
# ============================================================

map_2015 <- ggplot(geom_2015) +
  geom_sf(aes(fill = dom_2015), color = NA) +
  scale_fill_brewer(palette = "Set3", na.value = "grey90") +
  labs(
    title = "Gatunek dominujący – 2015",
    fill = "Gatunek"
  ) +
  theme_minimal() +
  theme(
    legend.position = "bottom",
    axis.text = element_blank(),
    axis.ticks = element_blank()
  )

ggsave(
  "Wyniki/mapy/map_gatunek_2015.png",
  map_2015,
  width = 10,
  height = 6,
  dpi = 300
)

# ============================================================
# 4. MAPA GATUNKU DOMINUJĄCEGO 2025
# ============================================================

map_2025 <- ggplot(geom_2025) +
  geom_sf(aes(fill = dom_2025), color = NA) +
  scale_fill_brewer(palette = "Set3", na.value = "grey90") +
  labs(
    title = "Gatunek dominujący – 2025",
    fill = "Gatunek"
  ) +
  theme_minimal() +
  theme(
    legend.position = "bottom",
    axis.text = element_blank(),
    axis.ticks = element_blank()
  )

ggsave(
  "Wyniki/mapy/map_gatunek_2025.png",
  map_2025,
  width = 10,
  height = 6,
  dpi = 300
)

# ============================================================
# 5. MAPA ZMIANY GATUNKU DOMINUJĄCEGO
# ============================================================

map_change <- geom2025 %>%
  left_join(dom_compare, by = c("a_i_num" = "arodes_int_num")) %>%
  mutate(change = as.factor(change))

map_change_plot <- ggplot(map_change) +
  geom_sf(aes(fill = change), color = NA) +
  scale_fill_manual(
    values = c("FALSE" = "grey85", "TRUE" = "#d73027"),
    na.value = "grey95",
    name = "Zmiana gatunku",
    labels = c("FALSE" = "Brak zmiany", "TRUE" = "Zmiana")
  ) +
  labs(
    title = "Zmiana gatunku dominującego 2015–2025"
  ) +
  theme_minimal() +
  theme(
    legend.position = "bottom",
    axis.text = element_blank(),
    axis.ticks = element_blank()
  )

ggsave(
  "Wyniki/mapy/map_gatunek_zmiana.png",
  map_change_plot,
  width = 10,
  height = 6,
  dpi = 300
)

# ============================================================
# 6. DANE DO MAP RÓŻNIC
# ============================================================

map_delta <- geom2025 %>%
  left_join(delta, by = c("a_i_num" = "arodes_int_num")) %>%
  left_join(dom_compare, by = c("a_i_num" = "arodes_int_num"))

# ============================================================
# 7. FUNKCJA DO MAP RÓŻNIC
# ============================================================

plot_mapa_roznic <- function(data, zmienna, tytul, plik) {
  
  p <- ggplot(data) +
    geom_sf(aes(fill = .data[[zmienna]]), color = NA) +
    geom_sf(
      data = data %>% filter(change == TRUE),
      fill = NA,
      color = "black",
      linewidth = 0.25
    ) +
    scale_fill_gradient2(
      low = "blue",
      mid = "white",
      high = "red",
      midpoint = 0,
      na.value = "grey90"
    ) +
    labs(
      title = tytul,
      subtitle = "Czarny obrys oznacza wydzielenia ze zmianą gatunku dominującego",
      fill = "Różnica"
    ) +
    theme_minimal() +
    theme(
      axis.text = element_blank(),
      axis.ticks = element_blank()
    )
  
  ggsave(
    plik,
    p,
    width = 10,
    height = 6,
    dpi = 300
  )
}

# ============================================================
# 8. MAPY RÓŻNIC WYSOKOŚCI, PIERŚNICY I MIĄŻSZOŚCI
# ============================================================

plot_mapa_roznic(
  map_delta,
  "diff_height",
  "Różnica wysokości drzewostanu 2025–2015",
  "Wyniki/mapy/map_roznica_wysokosci.png"
)

plot_mapa_roznic(
  map_delta,
  "diff_bhd",
  "Różnica pierśnicy drzewostanu 2025–2015",
  "Wyniki/mapy/map_roznica_piersnicy.png"
)

plot_mapa_roznic(
  map_delta,
  "diff_volume",
  "Różnica miąższości drzewostanu 2025–2015",
  "Wyniki/mapy/map_roznica_miazszosci.png"
)

# ============================================================
# 9. ZAPIS WARSTWY Z RÓŻNICAMI
# ============================================================

st_write(
  map_delta,
  "Wyniki/tabele/mapa_roznice.gpkg",
  delete_dsn = TRUE
)