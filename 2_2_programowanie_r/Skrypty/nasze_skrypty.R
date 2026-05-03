nasza_f <- function(d)
{
  # Tworzenie pełnej ścieżki do pliku w danym podfolderze
  file_path  <- paste0(d,'/',ffs_file)
  print(file_path) 
  
  # Sprawdzenie, czy plik fizycznie istnieje w danej lokalizacji
  if(file.exists(file_path))
  {
    # Wczytanie danych z pliku
    df <- read.table(file_path,header=T,sep='\t')
    # Dodanie nowej kolumny 'name' przechowującej nazwę folderu
    df$name <- basename(d)
    # Dołączenie wczytanych danych do zbiorczej tabeli
    fin_df <- rbind(fin_df,df)
    return(fin_df)
  } else {
    return(NULL)
  }
}
