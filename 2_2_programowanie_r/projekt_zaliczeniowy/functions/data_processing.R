# =========================================================================
# DATA PROCESSING - MODUŁ PRZETWARZANIA DANYCH
# =========================================================================

#' Przygotowanie danych leśnych (Pre-processing)
#' 
#' @description Filtruje surowe dane taksacyjne BDL do poziomu drzewostanu głównego.
#' 
#' @param df_input Surowa tabela wczytana z pliku f_storey_species.txt.
#' @param year_suffix Rok danych (np. "2015"), używany jako sufiks kolumn.
#' 
#' @return Obiekt klasy data.frame z ujednoliconymi nazwami i unikalnym kluczem ID.
prepare_forest_data <- function(df_input, year_suffix) {
  
  processed <- df_input %>%
    # mutate() modyfikuje lub tworzy nowe kolumny
    mutate(
      # storey_cd: Kod warstwy lasu (np. "DRZEW" - drzewostan, "NAL" - nalot).
      # as.character(): Rzutowanie na string; zapobiega błędom typu 'factor'.
      # trimws(): Odpowiednik Pythona .strip(); usuwa spacje, np. zamienia "DRZEW " na "DRZEW".
      storey_cd = trimws(as.character(storey_cd)),
      
      # sp_rank_order_act: Ranga gatunku (1 = panujący/dominujący, 2,3... = domieszkowe).
      # as.numeric(): Konwersja na liczbę; gwarantuje, że filtr (== 1) zadziała matematycznie.
      sp_rank_order_act = as.numeric(sp_rank_order_act)
    ) %>%
    # Filtracja: tylko piętro główne (DRZEW) i gatunek dominujący (Ranga 1)
    filter(storey_cd == "DRZEW", sp_rank_order_act == 1) %>%
    # Mapowanie technicznych nazw BDL na czytelne nazwy angielskie
    select(
      id = arodes_int_num,      # Numer porządkowy wydzielenia
      species = species_cd,     # Kod gatunku (np. SO = sosna, BK = buk)
      age = species_age,        # Wiek drzewostanu dla danego gatunku
      height = height,          # Przeciętna wysokość [m]
      dbh = bhd,                # Przeciętna pierśnica (średnica) [cm]
      volume = volume           # Miąższość (zasobność) [m3/ha]
    ) %>%
    # Konwersja ID na tekst (niezbędne do poprawnego działania Inner Join)
    mutate(id = as.character(id))
  
  # Dynamiczne dodanie roku do nazw kolumn (np. height -> height_2015)
  # Unikamy dzięki temu konfliktów nazw po złączeniu tabel z obu lat
  colnames(processed)[2:6] <- paste0(colnames(processed)[2:6], "_", year_suffix)
  
  return(processed)
}


#' Tworzenie zestawienia porównawczego (Calculation of Deltas)
#' 
#' @description Łączy dane z dwóch lat i oblicza zmiany cech taksacyjnych.
#' 
#' @param df_2015 Przetworzone dane z roku 2015.
#' @param df_2025 Przetworzone dane z roku 2025.
#' 
#' @return Tabela porównawcza (Master Table) zawierająca wartości bazowe i różnice.
create_comparison_table <- function(df_2015, df_2025) {
  
  # Łączenie tabel po unikalnym ID (Inner Join zostawia tylko wspólne rekordy)
  comparison <- df_2015 %>%
    inner_join(df_2025, by = "id")
  
  # Obliczanie różnic (Deltas) i flagowanie zmian składu
  comparison <- comparison %>%
    mutate(
      diff_height = height_2025 - height_2015,   # Przyrost wysokości
      diff_volume = volume_2025 - volume_2015,   # Zmiana zasobności
      diff_dbh    = dbh_2025 - dbh_2015,         # Przyrost grubości (pierśnicy)
      # Logiczna weryfikacja czy kod gatunku uległ zmianie (YES/NO)
      species_change = if_else(species_2015 != species_2025, "YES", "NO")
    )
  
  return(comparison)
}


#' Ekstrakcja danych o powierzchniach z warstwy SHP
#' 
#' @description Przygotowuje tabelę powierzchni do analiz statystycznych (bez geometrii).
#' 
#' @param wydz_layer Obiekt klasy sf wczytany z pliku .shp.
#' 
#' @return Dataframe zawierający ID wydzielenia oraz jego powierzchnię [ha].
get_subarea_areas <- function(wydz_layer) {
  
  areas <- wydz_layer %>%
    # Usunięcie geometrii - zamiana obiektu mapowego na zwykłą tabelę (jak w Pandas)
    st_drop_geometry() %>%
    # a_i_num to skrócona przez system SHP nazwa pola arodes_int_num
    select(
      id = a_i_num,     # ID zgodne z kluczem w plikach tekstowych
      area_ha = area    # Powierzchnia wydzielenia wyrażona w hektarach
    ) %>% 
    mutate(id = as.character(id))
  
  return(areas)
}