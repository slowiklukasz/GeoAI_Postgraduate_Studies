# Przewodnik analizy – skanery ręczne vs TLS

Pomocnicza wersja polska przewodnika docs/analysis_guide.md. Wersją główną jest wersja angielska i to ona obowiązuje przy rozbieżnościach. Progi liczbowe: docs/analysis_plan.md i scripts/compare_experiments.py.

## Zasady

- TLS to odniesienie względne, nie ground truth: piszemy „różnica względem TLS”, nie „błąd”.
- Każda liczba w raporcie ma źródło: plik wyjściowy albo polecenie w załączniku raportu.
- Najpierw n: różne n między skanerami to zwykle różne drzewa – sprawdź ref_mean i tabelę wspólnych drzew.
- |z| < 2: biasu nie da się odróżnić od zera przy tym n. Różnice mniejsze niż SE to nie różnice.
- Wyniki oddzielone od przyczyn; przyczyny to hipotezy, dopóki nie sprawdzono ich w chmurach.
- Plan analizy jest zamrożony przed P01+; nowe pomysły to nowe testy N… w dzienniku zmian.

## Mapa dokumentów

Gdzie co jest i kiedy się zmienia.

| Plik | Dla kogo | Zawartość | Zmienia się, gdy |
|---|---|---|---|
| README.md | wszyscy | uruchamianie, wejścia, kroki, pliki wyjściowe | zmienia się kod |
| CLAUDE.md | Claude Code | zasady pracy w repo, mapa dokumentów, przepływ z agentami | zmieniają się zasady |
| docs/methods.md | agent | co liczy każdy krok, klucze configu, pliki i kolumny | zmienia się kod |
| docs/interpretation.md | agent | jak czytać wyniki: wzorce i pułapki | wzorzec powtarza się w paczkach |
| docs/analysis_plan.md | agent i ludzie | testy, reguły decyzji, przewidywania | po zamrożeniu tylko nowe testy N… i dziennik zmian |
| docs/analysis_protocol.md | agent | procedura analizy jednej paczki, dozwolone dodatkowe obliczenia | zmienia się procedura |
| docs/output_schema.md | agent | format report.md, tests.csv i raportu porównawczego | zmienia się format |
| docs/experiment_plan.md | ludzie i agent | lista paczek, co stałe, struktura folderu paczki | dochodzi paczka |
| docs/examples/report_example.md | agent | przykład raportu: głębia i styl (liczby z innego przebiegu) | – |
| .claude/agents/*.md | Claude Code | instrukcje agentów experiment-analyst i experiment-comparer | zmienia się procedura |
| docs/analysis_guide.md, .xlsx | ludzie | przewodnik – wersja główna (EN) | razem z dokumentami powyżej |
| docs/pl/przewodnik_analizy.md, .xlsx | ludzie (PL) | ta wersja pomocnicza | razem z przewodnikiem |

## Przebieg analizy jednej paczki

Od danych do raportu porównawczego.

| Nr | Etap | Kto | Co zrobić | Wynik |
|---|---|---|---|---|
| 1 | Przygotowanie | człowiek | Skopiować experiments/_template do experiments/<ID>_<nazwa>, uzupełnić blok experiment i ścieżki, wgrać dane do data/arbor i data/3dfin. Clip: ustawić region (promień clipu − 3 m). | folder paczki |
| 2 | Uruchomienie | człowiek lub agent | python run.py --config experiments/<paczka>/config.yaml | outputs/ |
| 3 | Analiza | agent experiment-analyst (jeden na paczkę, równolegle) | W Claude Code: „Użyj experiment-analyst dla experiments/<paczka>”. Agent działa według docs/analysis_protocol.md. | report.md, tests.csv |
| 4 | Przegląd | człowiek | Czy każda liczba ma źródło, czy przyczyny są hipotezami, czy wnioski mówią, co liczba znaczy. Obejrzeć mapy i profil pni. | uwagi do raportu |
| 5 | Porównanie | agent experiment-comparer | Po wszystkich paczkach: „Użyj experiment-comparer”. Uruchamia scripts/compare_experiments.py i pisze raport. | experiments/comparison/report.md, tests_matrix.csv |
| 6 | Weryfikacja | człowiek | Rozbieżności agent / automat, przewidywania, punkty „Do sprawdzenia” w chmurach. | decyzje do raportu końcowego |

## Kroki pipeline'u

Co liczy run.py (szczegóły: docs/methods.md).

| Krok | Polecenie | Co liczy | Pliki wyjściowe | Jak czytać | Pułapka |
|---|---|---|---|---|---|
| 0. Wejścia i filtry | w każdym kroku | Usuwa statusy z exclude_status (W3), artefakty (korzeń > 1 m nad punktem 1,3 m) i drzewa poza regionem – tak samo dla referencji i skanerów. 3DFin: 0 = brak dopasowania. | – | Liczba drzew referencji po filtrach to mianownik wykrywania. | W2 zostaje: to prawdziwe drzewa bez DBH. |
| 1. Parowanie i wykrywanie | --step matching | Parowanie 1:1 po XY (algorytm węgierski, maks. 0,5 m); TP, FN, FP, precision, recall, F1; typy błędów. Dwa przebiegi: Arbor i 3DFin względem tej samej referencji. | matching/<arbor\|3dfin>/link_table.csv, detection_summary.csv, match_details.csv, matched_predictions/*.png | Recall: ile drzew referencji znaleziono. Precision: ile wykryć to drzewa. FP duplicate = nadsegmentacja. | Parowanie tylko po XY – fragment może zabrać parę pełnemu drzewu. |
| 2. Wrażliwość filtra | --step sensitivity | Wykrywanie Arbor powtórzone dla wariantów main, no_filter, measured_only. | sensitivity/detection_variants.csv, <wariant>/… | Każdy wariant odpowiada na inne pytanie (arkusz Filtry i statusy). | FN w no_filter to fragmenty w referencji, a nie pominięte drzewa. |
| 3. Pomiary (Arbor) | --step accuracy | d = skaner − TLS dla par; n, bias, RMSE, SD, SE, z, % dla DBH, H, V i położenia; kontrole bez par odstających i na wspólnych drzewach. | accuracy/arbor/paired_differences.csv, accuracy_summary.csv, accuracy_summary_no_outliers.csv, accuracy_summary_common_trees.csv | RMSE ≈ \|bias\| → przesunięcie systematyczne. \|z\| ≥ 2 → bias wyraźny. | DBH i V tylko dla par measured–measured; różne n = różne drzewa. |
| 4. Profile pni (3DFin) | --step stem_profiles | Różnice średnic na wspólnych wysokościach (sekcje co 0,2 m); pasma 1–3, 6–9 i 1–9 m; zasięg. | stem_profiles/stem_profile_summary.csv, stem_profile_bands.csv, stem_profile_differences.csv, stem_profile.png | Stały bias czy rosnący z wysokością; zasięg = jak wysoko pnie są dopasowane. | Procent rośnie z wysokością sam przez zwężanie pnia – patrz na cm. |
| 5. Porównanie paczek | python scripts/compare_experiments.py | Tabele zbiorcze, automatyczna ocena testów, zgodność z werdyktami agenta. | experiments/comparison/*.csv | Test odporny = potwierdzony we wszystkich paczkach z danymi. | Zmiana statusu to efekt ustawienia tylko przy jednej różnicy między paczkami i zmianie większej niż SE. |

## Warianty filtra i statusy Arbor

Każdy wariant filtra odpowiada na inne pytanie.

| Wariant | Wykluczone statusy | Rola | Pytanie | Pułapka |
|---|---|---|---|---|
| main | W3 allometry | wynik główny (zadeklarowany z góry) | wykrywanie drzew | – |
| no_filter | brak | analiza wrażliwości | nadsegmentacja – wszystkie segmenty | FN to fragmenty w referencji |
| measured_only | W3 + W2 | analiza wrażliwości | mierzalność DBH | spadek recall to brak DBH, nie brak drzewa |

Statusy Arbor:

| Status | Co to jest | Używane w |
|---|---|---|
| measured | DBH zmierzone | wykrywanie, DBH, H, V |
| W2 no valid measure | prawdziwe drzewo, DBH nie zmierzone (niewiarygodnie małe) | wykrywanie i H; bez DBH i V |
| W3 allometry | krótkie segmenty, głównie fragmenty podstawy pnia | wykluczone w wariancie głównym |
| other: Diameter anomaly | nietypowa średnica | wykrywanie i H; bez DBH i V |

## Metryki

Słowniczek – wszystkie wartości są w plikach wyjściowych.

| Metryka | Wzór | Jednostka | Znaczenie | Uwaga |
|---|---|---|---|---|
| TP | sparowana para | – | drzewo referencji odnalezione |  |
| FN | drzewo referencji bez pary | – | too_far: brak drzewa w 0,5 m; taken: para zajęta przez sąsiada |  |
| FP | drzewo skanera bez pary | – | duplicate: ≤ 0,3 m od sparowanego (nadsegmentacja); extra: samotne | extra sprawdzić w chmurze, zanim nazwie się je fałszywym |
| Precision | TP / (TP + FP) | 0–1 | jaka część wykryć to drzewa z referencji |  |
| Recall | TP / (TP + FN) | 0–1 | jaka część drzew referencji została wykryta |  |
| F1 | 2·P·R / (P + R) | 0–1 | jedna liczba łącząca precision i recall |  |
| d | skaner − TLS | cm, m, m³ | różnica dla pary; dodatnia = skaner daje więcej |  |
| n | liczba par | – | czytać zawsze najpierw | różne n = różne drzewa |
| Bias | mean(d) | jak d | przesunięcie systematyczne; znak = kierunek |  |
| RMSE | √mean(d²) | jak d | typowa wielkość różnicy bez znaku | RMSE ≈ \|bias\|: przesunięcie; RMSE ≫ \|bias\|: rozrzut |
| SD | odchylenie standardowe d | jak d | rozrzut wokół biasu |  |
| SE | SD / √n | jak d | niepewność biasu |  |
| z | bias / SE | – | \|z\| ≥ 2: bias wyraźnie różny od zera | n < 5: brak danych; n < 10: niska pewność |
| Bias %, RMSE % | wartość / ref_mean × 100 | % | porównanie między parametrami |  |
| ref_mean | średnia referencji dla tych samych par | jak parametr | czy porównujemy te same drzewa |  |
| Udział DBH | n(DBH) / n(H) | 0–1 | mierzalność DBH (test A4) |  |
| Duplikaty na drzewo | FP_duplicate / drzewa referencji | – | nadsegmentacja (test D2) |  |
| Para odstająca | \|ΔH\| > 3 m | – | zwykle referencja sparowana z fragmentem | kontrola: accuracy_summary_no_outliers.csv |
| Pasmo | średnia biasu z wysokości w przedziale, n ≥ 5 | cm | lower 1–3 m, upper 6–9 m, all 1–9 m |  |
| Zasięg | najwyższa sekcja z n ≥ 5 | m | jak wysoko pień jest dopasowany |  |

## Jak czytać wyniki – wzorce

Ogólne wzorce, nie wyniki. Uzupełniać, gdy powtarzają się w paczkach.

| Krok | Wzorzec | Co znaczy | Uwaga / co sprawdzić |
|---|---|---|---|
| Wykrywanie | recall ≈ 1 dla wszystkich skanerów | wykrywanie nie różnicuje skanerów na tej działce | referencję zdominowały duże drzewa |
| Wykrywanie | FP głównie duplicate | nadsegmentacja: drzewo pocięte na segmenty | duplikat może zabrać parę pełnemu drzewu – patrz pary odstające |
| Wykrywanie | FP głównie extra | podszyt, szum albo drzewa pominięte przez TLS | obejrzeć kilka w chmurze |
| Wykrywanie | FN taken | gęste drzewa: wykrycie sparowane z sąsiadem | zwykle duplikat w referencji |
| Wykrywanie | FN too_far | skaner (albo narzędzie) nie znalazł drzewa | widoczność pnia w chmurze |
| Wykrywanie | duży spadek recall w measured_only | mierzalność DBH, nie wykrywanie | to samo drzewo może być measured w TLS i W2 w HLS |
| Wykrywanie | dużo duplicate w no_filter | fragmenty podstawy pnia (W3) przy drzewach | porównać między skanerami |
| Wykrywanie | 3DFin znajduje dodatkowe pnie także w TLS | w referencji brakuje części pni (filtry, SegFix) | to nie błąd skanera |
| Pomiary | RMSE ≈ \|bias\| | przesunięcie systematyczne | szukać przyczyny w chmurze |
| Pomiary | RMSE ≫ \|bias\| | losowy rozrzut w obie strony | sprawdzić różnice dla pojedynczych drzew |
| Pomiary | bias DBH > 0 | pień wygląda na grubszy: szum odległości poszerza krawędź |  |
| Pomiary | bias DBH < 0 | okrąg dopasowany do niepełnego łuku lub rzadkich punktów | niskie n(DBH) tego skanera wskazuje to samo |
| Pomiary | niskie n(DBH) / n(H) | DBH rzadko mierzalne dla skanera | to samo w sobie jest wynikiem |
| Pomiary | duże RMSE H przy małym biasie | kilka par odstających (fragment zamiast drzewa) | porównać z accuracy_summary_no_outliers.csv |
| Pomiary | bias H < 0 na wysokich drzewach dla wszystkich HLS | wierzchołki niewidoczne z ziemi | efekt mały – potrzebne \|z\| ≥ 2 |
| Pomiary | bias V przy nieobciążonym DBH | efekt modelu objętości | V traktować pomocniczo |
| Pomiary | większe przesunięcie pni jednego skanera | mniej stabilne położenia (np. dryf SLAM) | wartości ≪ 0,5 m nie wpływają na parowanie |
| Pojedyncze drzewa | dwa skanery zgodne ze sobą, nie z TLS | podejrzana referencja lub sam pień | rozwidlenie, doklejony sąsiad, jednostronne pokrycie w TLS |
| Pojedyncze drzewa | jeden skaner daleko na jednym drzewie | błąd segmentacji w tej chmurze | fragment, odcięta korona |
| Pojedyncze drzewa | wszystkie HLS niższe od TLS na tym samym drzewie | wierzchołek niewidoczny z ziemi |  |
| Profile pni | stały bias wzdłuż pnia | systematyczny efekt skanera |  |
| Profile pni | bias rosnący z wysokością | efekt rośnie z odległością od skanera | patrzeć na cm, nie tylko % |
| Profile pni | większy bias tylko przy gruncie | podszyt, nabiegi korzeniowe | przy gruncie często mniej sekcji |
| Profile pni | różny zasięg | jak wysoko pnie są dopasowane w chmurze | zależy od progu n ≥ 5 |
| Profile pni | znak inny niż bias DBH w Arbor | narzędzia mierzą pień inaczej | zależność od narzędzia (test C1) |
| Między paczkami | test potwierdzony wszędzie | wynik odporny |  |
| Między paczkami | 3DFin zmienia się przy zmianie ustawień Arbor | różnią się dane wejściowe 3DFin | sprawdzić pliki xlsx |

## Testy (plan analizy)

Kryteria z docs/analysis_plan.md; wartości P00 z przebiegu eksploracyjnego (referencja SegFix).

| ID | Hipoteza | Kryterium | Plik źródłowy | Wartość P00 | P00 |
|---|---|---|---|---|---|
| I1 | Wspólny układ współrzędnych (kontrola) | mediana odległości par < 0,2 m dla każdego zbioru | matching/*/link_table.csv | – | kontrola |
| I2 | Komplet danych (kontrola) | 3 HLS w Arbor i 3DFin, TLS w 3DFin | matching/*/detection_summary.csv | – | kontrola |
| I3 | 3DFin TLS połączony z referencją (kontrola) | recall ≥ 0,9 | matching/3dfin/detection_summary.csv | – | kontrola |
| D1 | Wszystkie HLS wykrywają prawie wszystkie drzewa | recall ≥ 0,95 dla wszystkich HLS | matching/arbor/detection_summary.csv | 1,00 / 1,00 / 1,00 | ✓ |
| D2 | LiGrip najbardziej nadsegmentowany | duplikaty na drzewo: LiGrip najwięcej i ≥ 0,05 | matching/arbor/detection_summary.csv | 0,067 vs 0 / 0 | ✓ |
| A1 | low-cost zawyża DBH | bias > 0, z ≥ 2 | accuracy_summary.csv | +2,24 cm, z = 6,4 | ✓ |
| A2 | LiGrip zaniża DBH | bias < 0, z ≤ −2 | accuracy_summary.csv | −5,93 cm, z = −8,6 | ✓ |
| A3 | DBH GeoSLAM zgodne z TLS | \|z\| < 2 | accuracy_summary.csv | −0,31 cm, z = −1,1 | ✓ |
| A4 | DBH LiGrip najtrudniej zmierzyć | udział DBH: LiGrip najniższy i < 0,5 | accuracy_summary.csv | 0,30 vs 0,93 / 0,93 | ✓ |
| A5 | Wysokość zgodna dla GeoSLAM i low-cost | \|z\| < 2 dla obu | accuracy_summary.csv | z = −0,1 / −0,8 | ✓ |
| A6 | Bias H LiGrip wynika z par odstających | \|bias\| < 0,5 m bez par odstających | accuracy_summary_no_outliers.csv | −0,23 m | ✓ |
| A7 | Pnie LiGrip najbardziej przesunięte | LiGrip największe średnie przesunięcie | accuracy_summary.csv | 0,11 vs 0,05 / 0,06 m | ✓ |
| S1 | low-cost zawyża średnicę, mocniej wyżej | 0 < pasmo dolne < pasmo górne | stem_profile_bands.csv | +2,61 < +4,92 cm | ✓ |
| S2 | LiGrip zaniża średnicę wzdłuż pnia | pasmo dolne < 0 i górne < 0 | stem_profile_bands.csv | −1,90 / −2,40 cm | ✓ |
| S3 | Profil GeoSLAM najbliżej TLS | najmniejszy \|bias\| w paśmie 1–9 m | stem_profile_bands.csv | −0,40 vs −2,14 / +3,96 cm | ✓ |
| S4 | Zasięg GeoSLAM ≥ low-cost ≥ LiGrip | kolejność zasięgu | stem_profile_bands.csv | 14,5 / 12,3 / 10,7 m | ✓ |
| C1 | Arbor i 3DFin zgodne co do znaku biasu DBH | ten sam znak biasu DBH Arbor i 3DFin na 1,3 m (LiGrip, low-cost) | accuracy_summary.csv, stem_profile_summary.csv | −6,2 / −2,0; +2,5 / +2,0 cm | ✓ |

## Statusy, replikacja i przewidywania

Jak oceniamy test w paczce i między paczkami.

| Klasa | Reguła |
|---|---|
| odporny | confirmed we wszystkich paczkach z danymi |
| zależny od ustawień | confirmed w części paczek, not_confirmed w pozostałych, zgodnie z jedynym czynnikiem, który je różni |
| słaby | inconclusive w co najmniej połowie paczek z danymi |
| sprzeczny | istotny przeciwny znak (\|z\| ≥ 2) w którejkolwiek paczce – zawsze raportowany |

Status testu w jednej paczce:

| Status | Znaczenie |
|---|---|
| confirmed | kryterium spełnione |
| inconclusive | kierunek zgodny, ale \|z\| < 2 |
| not_confirmed | kryterium niespełnione |
| no_data | brak pliku, skanera albo n < 5 |

Przewidywania (zapisane przed P01+):

| Porównanie | Czynnik | Przewidywanie |
|---|---|---|
| P01 vs P00 | clip / region | te same statusy; część może przejść w inconclusive (mniejsze n) |
| P02 vs P01 | READ_FRACTION Arbor 0,2 → 1,0 | A4: udział DBH rośnie, najbardziej u LiGrip (≥ +0,10); A2: \|bias DBH LiGrip\| maleje; D2: pytanie otwarte |
| P02 vs P01 | kontrola | wyniki 3DFin (S1–S4, część 3DFin w C1) bez zmian |

## Struktura raportu paczki (report.md)

Raport po angielsku, wzór: docs/examples/report_example.md. Każda część: Results → Findings → Possible causes → To check.

| Część | Tabele | Pliki źródłowe | Wnioski – o czym | Pytania kontrolne przy przeglądzie |
|---|---|---|---|---|
| 0 – Ustawienia i kontrola danych | statusy Arbor w plikach | config.yaml, pliki wejściowe | co zmieniono, drzewa referencji, I1–I3 | Czy dane są kompletne i w jednym układzie? |
| 1 – Wykrywanie drzew | 3 warianty filtra × skaner; filtr – co mierzy | sensitivity/detection_variants.csv, match_details.csv, matching/3dfin/detection_summary.csv | wykrywanie, nadsegmentacja, mierzalność DBH, 3DFin | Czy recall różnicuje skanery? Czym są FP? Czy FN w no_filter to fragmenty referencji? |
| 2 – Pomiary drzew | n, bias, RMSE, z, %; kontrole | accuracy_summary.csv, _no_outliers, _common_trees | DBH, wysokość, objętość, położenie | Czy bias jest systematyczny? Czy trzyma się na wspólnych drzewach i bez par odstających? |
| 2b – Wybrane drzewa | jak część 2; wszystkie → wybrane | accuracy_summary.csv (tree_subset: selected) | czy obraz z wszystkich drzew się potwierdza | Czy zmiana jest większa niż SE? (tylko F00) |
| 2c – Pojedyncze drzewa | przypadki; statystyki bez nich | paired_differences.csv | które drzewa ciągną statystyki i dlaczego; kandydaci na figury | Podejrzana referencja, błąd segmentacji czy niewidoczny wierzchołek? |
| 3 – Profile pni | wybrane wysokości; pasma i zasięg; Arbor vs 3DFin | stem_profile_summary.csv, stem_profile_bands.csv, stem_profile.png | wzorzec każdego skanera, zasięg, zgodność narzędzi | Stały czy rosnący z wysokością (w cm)? Czy znak zgadza się z Arbor? |
| Testy | ID, status, dowód, pewność | tests.csv | – | Czy kryterium zastosowano dosłownie? |
| Ograniczenia, Do raportu | – | – | typ referencji, n, parowanie po XY; co użyć w raporcie końcowym | Czy hipotezy są oznaczone jako hipotezy? |
