
# Eksport tabel wynikowych

write_excel_csv2(
  zmiany,
  "Wyniki/tabele/porownanie_wydzielen_2015_2025.csv"
)

write_excel_csv2(
  pow_gatunki,
  "Wyniki/tabele/powierzchnia_gatunki_dominujace_long.csv"
)

write_excel_csv2(
  pow_gatunki_wide,
  "Wyniki/tabele/powierzchnia_gatunki_dominujace_2015_2025.csv"
)

wb <- createWorkbook()

addWorksheet(wb, "porownanie_wydzielen")
writeData(wb, "porownanie_wydzielen", zmiany)

addWorksheet(wb, "pow_gatunki_long")
writeData(wb, "pow_gatunki_long", pow_gatunki)

addWorksheet(wb, "pow_gatunki_2015_2025")
writeData(wb, "pow_gatunki_2015_2025", pow_gatunki_wide)

saveWorkbook(
  wb,
  "Wyniki/tabele/wyniki_bdl_piwniczna_2015_2025.xlsx",
  overwrite = TRUE
)