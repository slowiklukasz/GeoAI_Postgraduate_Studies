# Funkcja pomocnicza do ujednoliconego zapisu grafik
zapisz_wykres <- function(wykres_obj, nazwa_pliku, folder = DIR_WYKRESY, w = 10, h = 6) {
  
  # Tworzymy pełną ścieżkę do pliku
  pelna_sciezka <- file.path(folder, nazwa_pliku)
  
  # Zapisujemy grafikę za pomocą ggsave
  ggsave(
    filename = pelna_sciezka, 
    plot = wykres_obj, 
    width = w, 
    height = h, 
    dpi = 300,
    bg = "white"
  )
  
  # Komunikat w konsoli (odpowiednik logowania)
  message("Eksportowano: ", nazwa_pliku)
}

# Funkcja do wykresu porównawczego (Histogramy/Boxploty)
plot_structure_comparison <- function(df_2015, df_2025, variable_name, title) {
  
  # 1. Przygotowanie danych do wykresu (łączymy lata jeden pod drugim)
  # Wybieramy ID i konkretną kolumnę, ujednolicamy nazwy
  d1 <- df_2015 %>% select(id, wartosc = starts_with(variable_name)) %>% mutate(rok = "2015")
  d2 <- df_2025 %>% select(id, wartosc = starts_with(variable_name)) %>% mutate(rok = "2025")
  
  plot_data <- bind_rows(d1, d2)
  
  # 2. Tworzenie wykresu
  ggplot(plot_data, aes(x = wartosc, fill = rok)) +
    geom_histogram(position = "identity", alpha = 0.5, bins = 30, color = "white") +
    labs(title = title, x = variable_name, y = "Liczba wydzieleń", fill = "Rok") +
    theme_minimal() +
    scale_fill_manual(values = c("2015" = "steelblue", "2025" = "darkgreen"))
}

# Funkcja do porównania liczności gatunków
plot_species_change <- function(df_2015, df_2025) {
  
  g1 <- df_2015 %>% count(gat_2015) %>% rename(gat = gat_2015, n_2015 = n)
  g2 <- df_2025 %>% count(gat_2025) %>% rename(gat = gat_2025, n_2025 = n)
  
  g_compare <- full_join(g1, g2, by = "gat") %>%
    replace_na(list(n_2015 = 0, n_2025 = 0)) %>%
    pivot_longer(cols = starts_with("n_"), names_to = "rok", values_to = "liczba") %>%
    mutate(rok = str_remove(rok, "n_"))
  
  ggplot(g_compare, aes(x = reorder(gat, -liczba), y = liczba, fill = rok)) +
    geom_bar(stat = "identity", position = "dodge") +
    labs(title = "Zmiana liczności gatunków panujących", x = "Gatunek", y = "Liczba wydzieleń") +
    theme_minimal() +
    scale_fill_brewer(palette = "Paired")
}

plot_species_area_change <- function(df_2015, df_2025, wydz_2015, wydz_2025) {
  
  # Przygotowanie powierzchni z mapy (używamy a_i_num zamiast arodes_int_num)
  pow_15 <- wydz_2015 %>% 
    mutate(area_ha = as.numeric(st_area(.)) / 10000) %>% 
    st_drop_geometry() %>% 
    # Tutaj zmiana: a_i_num to ID w mapach BDL
    select(id = a_i_num, area_ha) %>% 
    mutate(id = as.character(id))
  
  pow_25 <- wydz_2025 %>% 
    mutate(area_ha = as.numeric(st_area(.)) / 10000) %>% 
    st_drop_geometry() %>% 
    select(id = a_i_num, area_ha) %>% 
    mutate(id = as.character(id))
  
  # Reszta bez zmian
  a1 <- df_2015 %>% left_join(pow_15, by = "id") %>% group_by(gat = gat_2015) %>% 
    summarise(area = sum(area_ha, na.rm = TRUE)) %>% mutate(rok = "2015")
  
  a2 <- df_2025 %>% left_join(pow_25, by = "id") %>% group_by(gat = gat_2025) %>% 
    summarise(area = sum(area_ha, na.rm = TRUE)) %>% mutate(rok = "2025")
  
  plot_data <- bind_rows(a1, a2)
  
  ggplot(plot_data, aes(x = reorder(gat, -area), y = area, fill = rok)) +
    geom_bar(stat = "identity", position = "dodge") +
    labs(title = "Zmiana powierzchniowa gatunków dominujących", 
         x = "Gatunek", y = "Suma powierzchni [ha]", fill = "Rok") +
    theme_minimal() + 
    scale_fill_manual(values = c("2015" = "#feb24c", "2025" = "#f03b20"))
}

plot_structure_comparison <- function(df_2015, df_2025, variable_prefix, title, unit) {
  
  # Przygotowanie danych (wybieramy kolumny zaczynające się od np. "wiek")
  d1 <- df_2015 %>% 
    select(id, wartosc = starts_with(variable_prefix)) %>% 
    mutate(rok = "2015")
  
  d2 <- df_2025 %>% 
    select(id, wartosc = starts_with(variable_prefix)) %>% 
    mutate(rok = "2025")
  
  plot_data <- bind_rows(d1, d2)
  
  # Tworzenie wykresu
  ggplot(plot_data, aes(x = wartosc, fill = rok)) +
    geom_histogram(position = "identity", alpha = 0.5, bins = 30, color = "white") +
    labs(
      title = title, 
      x = paste(variable_prefix, unit), # Tutaj doklejamy jednostkę do osi X
      y = "Liczba wydzieleń", 
      fill = "Rok"
    ) +
    theme_minimal() +
    scale_fill_manual(values = c("2015" = "steelblue", "2025" = "darkgreen"))
}

plot_structure_by_species <- function(df_2015, df_2025, variable_prefix, unit) {
  
  # 1. Wybieramy 5 najczęstszych gatunków, żeby wykres był czytelny
  top_species <- df_2025 %>% 
    count(gat_2025) %>% 
    top_n(5, n) %>% 
    pull(gat_2025)
  
  # 2. Przygotowanie danych
  d1 <- df_2015 %>% 
    filter(gat_2015 %in% top_species) %>%
    select(id, gat = gat_2015, wartosc = starts_with(variable_prefix)) %>% 
    mutate(rok = "2015")
  
  d2 <- df_2025 %>% 
    filter(gat_2025 %in% top_species) %>%
    select(id, gat = gat_2025, wartosc = starts_with(variable_prefix)) %>% 
    mutate(rok = "2025")
  
  plot_data <- bind_rows(d1, d2)
  
  # 3. Wykres z podziałem na panele (facet_wrap)
  ggplot(plot_data, aes(x = wartosc, fill = rok)) +
    geom_histogram(position = "identity", alpha = 0.5, bins = 20) +
    facet_wrap(~gat, scales = "free_y") + # Osobny wykres dla każdego gatunku
    labs(title = paste("Struktura", variable_prefix, "dla głównych gatunków"),
         x = paste(variable_prefix, unit), y = "Liczba wydzieleń") +
    theme_light() +
    scale_fill_manual(values = c("2015" = "orange", "2025" = "purple"))
}