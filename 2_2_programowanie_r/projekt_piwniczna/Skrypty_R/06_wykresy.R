# ============================================================
# 06_wykresy.R
# WYKRESY STRUKTURY DRZEWOSTANU (POPRAWIONE)
# ============================================================

library(tidyverse)

# ============================================================
# 0. GŁÓWNE GATUNKI
# ============================================================

top_gatunki <- drzew %>%
  group_by(species_cd) %>%
  summarise(
    volume = sum(volume, na.rm = TRUE),
    .groups = "drop"
  ) %>%
  slice_max(volume, n = 5) %>%
  pull(species_cd)

# dane tylko dla głównych gatunków
cechy_top <- drzew %>%
  filter(species_cd %in% top_gatunki) %>%
  mutate(rok = factor(a_year))

# ============================================================
# 1. WIEK – średni dla gatunków
# ============================================================

wiek_gatunki <- cechy_top %>%
  group_by(species_cd, rok) %>%
  summarise(
    avg_age = mean(species_age, na.rm = TRUE),
    .groups = "drop"
  )

p_wiek <- ggplot(wiek_gatunki,
                 aes(x = species_cd, y = avg_age, fill = rok)) +
  geom_col(position = "dodge") +
  labs(
    title = "Średni wiek głównych gatunków (2015 vs 2025)",
    x = "Gatunek",
    y = "Wiek [lata]",
    fill = "Rok"
  ) +
  theme_minimal()

ggsave("Wyniki/wykresy/01_struktura_wiekowa.png", p_wiek, width = 10, height = 6)

# ============================================================
# 2. WYSOKOŚĆ – średnia dla gatunków
# ============================================================

wys_gatunki <- cechy_top %>%
  group_by(species_cd, rok) %>%
  summarise(
    avg_height = mean(height, na.rm = TRUE),
    .groups = "drop"
  )

p_height <- ggplot(wys_gatunki,
                   aes(x = species_cd, y = avg_height, fill = rok)) +
  geom_col(position = "dodge") +
  labs(
    title = "Średnia wysokość głównych gatunków (2015 vs 2025)",
    x = "Gatunek",
    y = "Wysokość [m]",
    fill = "Rok"
  ) +
  theme_minimal()

ggsave("Wyniki/wykresy/02_struktura_wysokosciowa.png", p_height, width = 10, height = 6)

# ============================================================
# 3. PIERŚNICA – średnia dla gatunków
# ============================================================

bhd_gatunki <- cechy_top %>%
  group_by(species_cd, rok) %>%
  summarise(
    avg_bhd = mean(bhd, na.rm = TRUE),
    .groups = "drop"
  )

p_bhd <- ggplot(bhd_gatunki,
                aes(x = species_cd, y = avg_bhd, fill = rok)) +
  geom_col(position = "dodge") +
  labs(
    title = "Średnia pierśnica głównych gatunków (2015 vs 2025)",
    x = "Gatunek",
    y = "Pierśnica [cm]",
    fill = "Rok"
  ) +
  theme_minimal()

ggsave("Wyniki/wykresy/03_struktura_piersnicowa.png", p_bhd, width = 10, height = 6)

# ============================================================
# 4. MIĄŻSZOŚĆ – suma gatunków
# ============================================================

miazszosc_gatunki <- cechy_top %>%
  group_by(species_cd, rok) %>%
  summarise(
    total_volume = sum(volume, na.rm = TRUE),
    .groups = "drop"
  )

p_volume <- ggplot(miazszosc_gatunki,
                   aes(x = species_cd, y = total_volume, fill = rok)) +
  geom_col(position = "dodge") +
  labs(
    title = "Miąższość głównych gatunków (2015 vs 2025)",
    x = "Gatunek",
    y = "Miąższość",
    fill = "Rok"
  ) +
  theme_minimal()

ggsave("Wyniki/wykresy/04_miazszosc_gatunki.png", p_volume, width = 10, height = 6)

# ============================================================
# 5. STRUKTURA GATUNKOWA (CAŁOŚCIOWA)
# ============================================================

p_gatunki <- gatunki_struktura %>%
  ggplot(aes(x = reorder(species_cd, volume),
             y = volume,
             fill = factor(rok))) +
  geom_col(position = "dodge") +
  coord_flip() +
  labs(
    title = "Struktura gatunkowa drzewostanu",
    x = "Gatunek",
    y = "Miąższość",
    fill = "Rok"
  ) +
  theme_minimal()

ggsave("Wyniki/wykresy/05_struktura_gatunkowa.png", p_gatunki, width = 10, height = 7)

# ============================================================
# 6. ZMIANA MIĄŻSZOŚCI GATUNKÓW
# ============================================================

zmiana_gatunkow <- gatunki_struktura %>%
  select(species_cd, rok, volume) %>%
  pivot_wider(names_from = rok, values_from = volume) %>%
  mutate(zmiana = `2025` - `2015`)

p_zmiana <- ggplot(zmiana_gatunkow,
                   aes(x = reorder(species_cd, zmiana),
                       y = zmiana,
                       fill = zmiana > 0)) +
  geom_col(show.legend = FALSE) +
  coord_flip() +
  labs(
    title = "Zmiana miąższości gatunków (2025 vs 2015)",
    x = "Gatunek",
    y = "Zmiana miąższości"
  ) +
  theme_minimal()

ggsave("Wyniki/wykresy/06_zmiana_gatunkow.png", p_zmiana, width = 10, height = 7)