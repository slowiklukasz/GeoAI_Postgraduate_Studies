# Import danych BDL dla jednego roku

wczytaj_bdl <- function(folder, rok){
  
  gatunki <- read_delim(
    file.path(folder, "f_storey_species.txt"),
    delim = "\t",
    locale = locale(encoding = "UTF-8"),
    show_col_types = FALSE
  )
  
  subarea <- read_delim(
    file.path(folder, "f_subarea.txt"),
    delim = "\t",
    locale = locale(encoding = "UTF-8"),
    show_col_types = FALSE
  )
  
  arodes <- read_delim(
    file.path(folder, "f_arodes.txt"),
    delim = "\t",
    locale = locale(encoding = "UTF-8"),
    show_col_types = FALSE
  )
  
  geom <- st_read(
    file.path(folder, "G_SUBAREA.shp"),
    quiet = TRUE,
    options = "ENCODING=WINDOWS-1250"
  )
  
  list(
    gatunki = gatunki,
    subarea = subarea,
    arodes = arodes,
    geom = geom,
    rok = rok
  )
}

bdl2015 <- wczytaj_bdl(dir_2015, 2015)
bdl2025 <- wczytaj_bdl(dir_2025, 2025)