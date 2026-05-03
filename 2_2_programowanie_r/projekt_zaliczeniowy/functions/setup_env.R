# =========================================================================
# SETUP ENVIRONMENT - MODUŁ KONFIGURACJI ŚRODOWISKA
# =========================================================================

#' Automatyczne ładowanie i instalacja brakujących pakietów R
#' @description Sprawdza listę wymaganych bibliotek, instaluje te których brakuje, 
#' a następnie importuje je wszystkie do bieżącej sesji.
#' @param packages Wektor tekstowy z nazwami pakietów (np. c("tidyverse", "sf"))

safe_library <- function(packages) {
  missing <- packages[!(packages %in% installed.packages()[,"Package"])]
  
  if(length(missing) > 0) {
    message("Installing missing packages: ", paste(missing, collapse = ", "))
    install.packages(missing)
  }
  
  for(p in packages) {
    library(p, character.only = TRUE)
  }
}