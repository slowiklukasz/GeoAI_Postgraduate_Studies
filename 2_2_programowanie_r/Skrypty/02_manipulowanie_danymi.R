# ==========================================================================
# Instalacja pakietów -----------------------------------------------------
# ==========================================================================

#install.packages("tidyverse", method = "wininet")
#install.packages("readxl", method = "wininet")

library(tidyverse)
library(readxl)

# ==========================================================================
# FOLDER PROJEKTU ---------------------------------------------------------
# ==========================================================================

# Sprawdza aktualną ścieżkę roboczą
getwd() 
# Ustawia nową ścieżkę roboczą na podany folder
setwd('D:/ProgramowanieR/')
getwd()

# ==========================================================================
# WCZYTANIE DANYCH --------------------------------------------------------
# ==========================================================================

# Wczytanie pliku Excel
meteo <- read_xlsx("./Data/meteo.xlsx")

# Wczytanie pliku tekstowego za pomocą read.table
# sep='\t' oznacza, że kolumny są rozdzielone tabulatorem
# header = T (lub TRUE) informuje R, że pierwszy wiersz zawiera nazwy kolumn
fss <- read.table("./Data/BDL_01_02_BIALOWIEZA_2025/f_storey_species.txt",sep='\t',header = T)

# Alternatywne wczytanie tego samego pliku za pomocą read.csv
# Uwaga: domyślnie read.csv zakłada przecinek jako separator, 
# dlatego tutaj parametr sep='\t' nadpisuje to zachowanie
fss <- read.csv("./Data/BDL_01_02_BIALOWIEZA_2025/f_storey_species.txt",sep='\t')

trees <- read.csv("./Data/trees.txt",sep=';')
class(trees$h)

trees <- read.csv("./Data/trees.txt",sep=';',dec=',')
class(trees$h)

# ==========================================================================
# FILTROWANIE -------------------------------------------------------------
# ==========================================================================

# Wyświetla nazwy wszystkich kolumn w ramce danych fss
colnames(fss)

filter(fss,fss$species_age > 100)

fss %>% filter(species_age > 100)
fss %>% filter(species_age > 100,sp_rank_order_act == 1)
fss$storey_cd =  gsub(" ","",fss$storey_cd)
fss %>% filter(species_age > 100,sp_rank_order_act == 1,storey_cd == 'DRZEW')

fss %>% filter(species_age > 100 & sp_rank_order_act == 1)
fss %>% filter(!is.na(species_age) & (species_age > 100 | sp_rank_order_act == 1))

fss$species_cd = str_trim(fss$species_cd)
fss %>% filter(species_cd %in% c('SO','ŚW'))

unique(fss[["species_cd"]])

# ==========================================================================
# WYBIERANIE --------------------------------------------------------------
# ==========================================================================

fss %>%
  filter(species_age > 100,sp_rank_order_act == 1,storey_cd == 'DRZEW') %>%
  select(arodes_int_num,species_cd,species_age)

fss %>%
  filter(species_age > 100,sp_rank_order_act == 1,storey_cd == 'DRZEW') %>%
  select(-a_year,-storey_cd)

fss %>%
  filter(species_age > 100,sp_rank_order_act == 1,storey_cd == 'DRZEW') %>%
  select(-c(storey_cd,a_year))

fss %>%
  filter(species_age > 100,sp_rank_order_act == 1,storey_cd == 'DRZEW') %>%
  select(-c(part_cd_act:volume))

fss %>%
  filter(species_age > 100,sp_rank_order_act == 1,storey_cd == 'DRZEW') %>%
  select(wydz_id = arodes_int_num,gatunek = species_cd, wiek = species_age)

# ==========================================================================
# NOWE ZMIENNE ------------------------------------------------------------
# ==========================================================================

fss %>% mutate(centries = species_age/100)
fss %>% transmute(centries = species_age/100)
fss %>% transmute(centries = round(species_age/100,1))

fss %>% mutate(iglaste = if_else(species_cd %in% c('SO','SW'),TRUE,FALSE))

# ==========================================================================
# PODSUMOWANIE ------------------------------------------------------------
# ==========================================================================

fss %>%
  filter(species_age > 100,sp_rank_order_act == 1,storey_cd == 'DRZEW',species_cd == 'SO') %>%
  summarise(srednia_wysokosc=mean(height),
            sredni_wiek=mean(species_age))

# ==========================================================================
# GRUPOWANIE --------------------------------------------------------------
# ==========================================================================

fss %>%
  filter(species_age > 100,sp_rank_order_act == 1,storey_cd == 'DRZEW') %>%
  group_by(species_cd) %>%
    summarise(srednia_wysokosc=mean(height),
            sredni_wiek=mean(species_age))


fss %>%
  filter(species_age > 100,sp_rank_order_act == 1,storey_cd == 'DRZEW') %>%
  group_by(species_cd) %>%
  summarise(liczebnosc=n(),
            srednia_wysokosc=mean(height),
            sredni_wiek=mean(species_age))


fss %>%
  filter(storey_cd == 'DRZEW',sp_rank_order_act<=3) %>%
  group_by(species_cd,sp_rank_order_act) %>%
  summarise(liczebnosc=n(),
            srednia_wysokosc=mean(height,na.rm=T),
            sredni_wiek=mean(species_age))

fss %>%
  filter(storey_cd == 'DRZEW',sp_rank_order_act<=3) %>%
  group_by(species_cd,sp_rank_order_act) %>%
  count()


fss %>%
  filter(sp_rank_order_act == 1,storey_cd == 'DRZEW') %>%
  mutate(iglaste = if_else(species_cd %in% c('SO','SW'),TRUE,FALSE)) %>%
  group_by(iglaste) %>%
  count()

# ==========================================================================
# SORTOWANIE --------------------------------------------------------------
# ==========================================================================

dom <- fss %>%  filter(sp_rank_order_act == 1,storey_cd == 'DRZEW')

dom %>% arrange(species_cd)
dom %>% arrange(species_cd,species_age)
dom %>% arrange(species_cd,desc(species_age))

sum_dom <- dom %>%
  group_by(gatunek = species_cd) %>%
  summarise(liczebnosc=n(),
            srednia_wysokosc=mean(height,na.rm=T),
            sredni_wiek=mean(species_age)) %>% arrange(desc(liczebnosc))

# ==========================================================================
# ŁĄCZENIE ----------------------------------------------------------------
# ==========================================================================

dom100 = dom %>% filter(species_age >= 100)

sum_dom100 <- dom100 %>%
  group_by(gatunek = species_cd) %>%
  summarise(liczebnosc=n(),
            srednia_wysokosc=mean(height,na.rm=T),
            sredni_wiek=mean(species_age)) %>% arrange(desc(liczebnosc))

inner_join(sum_dom,sum_dom100,by="gatunek")
result <- left_join(sum_dom,sum_dom100,by="gatunek")

# ==========================================================================
# ZAPIS -------------------------------------------------------------------
# ==========================================================================

getwd()
dir.exists("Wyniki")
dir.create("Wyniki")

write.table(result,'./Wyniki/results.txt',sep = ';',row.names = F)

install.packages("writexl", method = "wininet")
library(writexl)

write_xlsx(result,'./Wyniki/results.xlsx')