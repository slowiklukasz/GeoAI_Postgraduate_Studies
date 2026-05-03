safe_library <- function(packages) {
  missing <- packages[!(packages %in% installed.packages()[,"Package"])]
  
  if(length(missing) > 0) {
    message("Instalowanie brakujących pakietów: ", paste(missing, collapse = ", "))
    install.packages(missing)
  }
  
  for(p in packages) {
    library(p, character.only = TRUE)
  }
}