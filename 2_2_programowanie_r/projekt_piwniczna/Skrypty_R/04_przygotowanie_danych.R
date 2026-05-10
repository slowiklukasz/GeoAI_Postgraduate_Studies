# 1. Połączenie danych z obu lat
gatunki_all <- bind_rows(
  bdl2015$gatunki,
  bdl2025$gatunki
)

# 2. Filtr tylko warstwy DRZEW
drzew <- gatunki_all %>%
  filter(trimws(storey_cd) == "DRZEW")

# 3. Wybór tylko potrzebnych zmiennych
drzew <- drzew %>%
  select(
    arodes_int_num,
    a_year,
    species_cd,
    part_cd_act,
    species_age,
    height,
    bhd,
    volume
  )

# 4. Czyszczenie i konwersja typów
drzew <- drzew %>%
  mutate(
    arodes_int_num = as.character(arodes_int_num),
    species_cd = stringr::str_squish(species_cd),
    part_cd_act = as.numeric(part_cd_act),
    species_age = as.numeric(species_age),
    height = as.numeric(height),
    bhd = as.numeric(bhd),
    volume = as.numeric(volume),
    a_year = as.integer(a_year)
  )

# dane do analizy per rok (KLUCZ)
dane2015 <- drzew %>% filter(a_year == 2015)
dane2025 <- drzew %>% filter(a_year == 2025)