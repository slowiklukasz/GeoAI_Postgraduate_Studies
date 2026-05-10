# 05_analizy_tabele.R
# UTWORZENIE OBIEKTÓW DO WYKRESÓW I MAP
# ============================================================

analiza_struktury <- function(dane, rok) {
  
  ogol <- dane %>%
    summarise(
      avg_age = mean(species_age, na.rm = TRUE),
      avg_height = mean(height, na.rm = TRUE),
      total_volume = sum(volume, na.rm = TRUE)
    ) %>%
    mutate(rok = rok)
  
  gatunki <- dane %>%
    group_by(species_cd) %>%
    summarise(
      avg_age = mean(species_age, na.rm = TRUE),
      avg_height = mean(height, na.rm = TRUE),
      volume = sum(volume, na.rm = TRUE),
      .groups = "drop"
    ) %>%
    mutate(
      rok = rok,
      udzial = volume / sum(volume, na.rm = TRUE)
    )
  
  gatunki_wiek <- gatunki %>%
    arrange(desc(udzial))
  
  dominanta <- dane %>%
    group_by(arodes_int_num, species_cd) %>%
    summarise(
      volume = sum(volume, na.rm = TRUE),
      .groups = "drop"
    ) %>%
    group_by(arodes_int_num) %>%
    slice_max(volume, n = 1, with_ties = FALSE) %>%
    ungroup() %>%
    select(
      arodes_int_num,
      dominant_species = species_cd
    ) %>%
    mutate(rok = rok)
  
  list(
    ogol = ogol,
    gatunki = gatunki,
    gatunki_wiek = gatunki_wiek,
    dominanta = dominanta
  )
}

wyniki2015 <- analiza_struktury(dane2015, 2015)
wyniki2025 <- analiza_struktury(dane2025, 2025)

gatunki_struktura <- bind_rows(
  wyniki2015$gatunki,
  wyniki2025$gatunki
)

dom2015 <- wyniki2015$dominanta %>%
  rename(dom_2015 = dominant_species) %>%
  mutate(arodes_int_num = as.character(arodes_int_num))

dom2025 <- wyniki2025$dominanta %>%
  rename(dom_2025 = dominant_species) %>%
  mutate(arodes_int_num = as.character(arodes_int_num))

dom_compare <- dom2015 %>%
  inner_join(dom2025, by = "arodes_int_num") %>%
  mutate(change = dom_2015 != dom_2025)

delta <- drzew %>%
  group_by(arodes_int_num, a_year) %>%
  summarise(
    height = mean(height, na.rm = TRUE),
    bhd = mean(bhd, na.rm = TRUE),
    volume = sum(volume, na.rm = TRUE),
    .groups = "drop"
  ) %>%
  pivot_wider(
    names_from = a_year,
    values_from = c(height, bhd, volume)
  ) %>%
  mutate(
    diff_height = height_2025 - height_2015,
    diff_bhd = bhd_2025 - bhd_2015,
    diff_volume = volume_2025 - volume_2015
  ) %>%
  mutate(arodes_int_num = as.character(arodes_int_num))

write.csv(gatunki_struktura, "Wyniki/tabele/gatunki_struktura.csv", row.names = FALSE)
write.csv(dom_compare, "Wyniki/tabele/zmiana_gatunku_dominujacego.csv", row.names = FALSE)
write.csv(delta, "Wyniki/tabele/roznice_cech_drzewostanu.csv", row.names = FALSE)

write.xlsx(
  list(
    gatunki_struktura = gatunki_struktura,
    zmiana_gatunku_dominujacego = dom_compare,
    roznice_cech_drzewostanu = delta
  ),
  "Wyniki/tabele/wyniki_bdl.xlsx",
  overwrite = TRUE
)