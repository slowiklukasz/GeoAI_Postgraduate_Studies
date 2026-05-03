# KONFIGURACJA ŚCIEŻEK I ZMIENNYCH ------------------

# Ustawienie ścieżki roboczej
wdir <- "d:/ProgramowanieR/"
setwd(wdir)

# Pobranie listy wszystkich podkatalogów w folderze './Data/'
dirs <- list.dirs('./Data/')

# Nazwa pliku docelowego, którego będziemy szukać w podfolderach
ffs_file  <- "f_storey_species.txt"

# Inicjalizacja pustej ramki danych, do której będą scalane wyniki
fin_df <- data.frame()

# PĘTLA IMPORTUJĄCA DANE ---------------------------
for(d in dirs)
{
  # Tworzenie pełnej ścieżki do pliku w danym podfolderze
  file_path <- paste0(d,'/',ffs_file)
  print(file_path) 
  
  # Sprawdzenie, czy plik fizycznie istnieje w danej lokalizacji
  if(file.exists(file_path))
  {
    print("istnieje")
    # Wczytanie danych z pliku
    df <- read.table(file_path,header=T,sep='\t')
    # Dodanie nowej kolumny 'name' przechowującej nazwę folderu
    df$name <- basename(d)
    # Dołączenie wczytanych danych do zbiorczej tabeli
    fin_df <- rbind(fin_df,df)
  } else {
    print("nie istnieje")
  }
}

# Pomocnicza pętla wypisująca przetworzone katalogi w konsoli
for(i in 1:length(dirs))
{
  d <- dirs[i]
  print(d)
}

# DEFINICJA FUNKCJI ANALITYCZNEJ-------------------------

# Funkcja obliczająca liczebność dominujących gatunków w danym stadium
liczebnosc_dom <- function(df,stadium)
{
  # Walidacja danych wejściowych
  if (!is.data.frame(df)) stop("Tabela musi być typu data frame")
  if (!is.character(stadium)) stop("Stadium musi być tekstem")
  
  # Sprawdzenie, czy podane stadium w ogóle występuje w danych
  if(!(stadium %in% unique(str_trim(df$storey_cd)))) stop("Podanego stadium nie ma w kolumnie storey_sp")
  
  # Przetwarzanie danych przy użyciu potoków
  res <- df %>%
    # Filtrowanie: wybór konkretnego stadium i tylko gatunków o randze 1
    filter(str_trim(storey_cd) == stadium,sp_rank_order_act == 1) %>%
    # Grupowanie po nazwie lokalizacji/pliku oraz kodzie gatunku
    group_by(nazwa = name, gatunek = str_trim(species_cd)) %>%
    # Zliczanie wystąpień
    summarise(liczebnosc = n())
  
  # Przekształcenie tabeli z formatu długiego na szeroki
  res <- res %>%
    pivot_wider(names_from = nazwa, values_from = liczebnosc)
  
  return(res)
}


# URUCHOMIENIE ANALIZY ------------------------

# Wywołanie funkcji dla stadium "DRZEW" i zapisanie wyniku do zmiennej
wynik <- liczebnosc_dom(fin_df,"DRZEW")


# LAPPLY, SAPPLY, MAPPLY --------------------------------------------------

source("./nasze_skrypty.R")

dirs <- list.dirs('./Data/')
out <- lapply(dirs, nasza_f)

out <- do.call(rbind,out)

ffs <- read.csv('./Data/BDL_01_02_BIALOWIEZA_2025/f_storey_species.txt',sep = '\t')
ffs <- ffs %>% select(height,bhd,volume)

apply(ffs, 1, mean)
apply(ffs, 2, mean, na.rm=T)


# HERE --------------------------------------------------------------------

install.packages("here", method = "wininet")
library(here)

ffs <- read.csv(here::here('Data','trees_rs.txt'),sep = ';',header = T,dec = ',')

# WIELOWATKOWOSC ----------------------------------------------------------

install.packages("future", method = "wininet")
install.packages("future.apply", method = "wininet")
library(future)
library(future.apply)

zadanie <- function(x) {
  Sys.sleep(1)
  return(x^2)
}

dane <- 1:10

now <- Sys.time()
wynik_par <- lapply(dane, zadanie)
Sys.time() - now

plan(multisession,workers = 4)

now <- Sys.time()
wynik_par <- future_lapply(dane, zadanie)
Sys.time() - now

plan(sequential)