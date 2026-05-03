# --- ŁADOWANIE BIBLIOTEK -------------------------------------------------

#install.packages("sf", method = "wininet")
#install.packages("proxy")
#install.packages("mapview", method = "wininet")

library(tidyverse)
library(sf)
library(mapview)

# USTAWIENIA PROJEKTU -----------------------------------------------------
setwd("d:/ProgramowanieR/")

# PRZETWARZANIE DANYCH TABELARYCZNYCH -------------------------------------
# Wczytanie danych o gatunkach
df <- read.csv("./Data/BDL_01_02_BIALOWIEZA_2025/f_storey_species.txt",sep = '\t')

# Czyszczenie danych
df$species_cd = str_trim(df$species_cd)
df$part_cd_act = as.integer(df$part_cd_act)

# Agregacja: obliczenie udziału gatunków dla wydzieleń w warstwie "DRZEW"
sp_wydz <-  df %>% filter(str_trim(storey_cd) == "DRZEW",!is.na(part_cd_act)) %>% 
    group_by(arodes_int_num,species_cd) %>%
    summarise(procent = sum(part_cd_act)) %>%
    pivot_wider(names_from = species_cd,values_from = procent)

# OPERACJE NA WARSTWACH WEKTOROWYCH (SHP) ----------------------------------
# Wczytanie warstwy wydzieleń
wydz <- read_sf("./Data/BDL_01_02_BIALOWIEZA_2025/G_SUBAREA.shp")

# Podstawowe wizualizacje geometrii i atrybutów
plot(wydz$geometry)
plot(wydz["species_cd"])

# Analiza przestrzenna: wybór wydzieleń z Sosną (SO) i ich centra
select_dom <- wydz %>% filter(species_cd == "SO")
plot(st_centroid(select_dom))

# ŁĄCZENIE DANYCH GEOMETRYCZNYCH I OPISOWYCH ------------------------------
# Połączenie mapy z obliczonymi udziałami gatunków z BDL
wydz_new <- wydz %>% left_join(sp_wydz,by = join_by(a_i_num == arodes_int_num))

# Filtrowanie i wizualizacja punktów środkowych dla wybranych wydzieleń
select <- wydz_new %>% filter(!is.na(SO))
plot(st_geometry(st_centroid(select)))
plot(st_geometry(st_centroid(select_dom)))

# Interaktywny podgląd ogólny
mapview(wydz)

# XY na punkty ------------------------------------------------------------

# Wczytanie danych punktowych drzew
trees <- read.csv("./Data/trees_rs.txt",sep=";",dec=',')
# Konwersja tabeli na obiekt przestrzenny SF (układ 1992)
trees <- st_as_sf(trees, coords = c("x", "y"), crs = 2180)

# Wizualizacja wysokości i gatunków pojedynczych drzew
plot(trees["h"],pch=20)
trees$species <- as.factor(trees$species)
plot(trees["species"],pch=20)

# INTERAKTYWNE MAPY ZŁOŻONE -----------------------------------------------
# Podgląd wysokości drzew
mapview(trees,zcol = "h")

# Podgląd gatunków drzew
count <- length(unique(wydz$species_cd))
mapview(trees,zcol = "species", col.regions = rainbow(count))

# Nałożenie warstw: wydzielenia (poligony) + pojedyncze drzewa (punkty)
mapview(wydz,zcol="species_cd") + mapview(trees,zcol="species",cex = 3)
