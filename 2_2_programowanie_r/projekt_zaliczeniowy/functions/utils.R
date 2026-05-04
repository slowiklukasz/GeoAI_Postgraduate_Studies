# =========================================================================
# UTILS - NARZĘDZIA POMOCNICZE (I/O)
# =========================================================================

#' Uniwersalny eksport produktów graficznych, zaróno Wykresów jak i map
#' @description Zapewnia spójność techniczną plików PNG (DPI, tło, wymiary).
#' @param obj Obiekt typu ggplot.
#' @param filename Nazwa pliku.
#' @param target_dir Folder docelowy.
#' @param w Szerokość.
#' @param h Wysokość.
save_plot <- function(obj, filename, target_dir, w = 10, h = 6) {
  
  full_path <- file.path(target_dir, filename)

  ggsave(
    filename = full_path, 
    plot = obj, 
    width = w, 
    height = h, 
    dpi = 300, 
    bg = "white"
  )
}