# Raport z badań: Segmentacja 3D struktur leśnych

## 1. Zbiorcze zestawienie wyników
Porównanie wydajności modeli na zbiorze testowym. Skupienie na klasie **Trunk** (Pień), która jest kluczowa dla oceny jakości inwentaryzacji.

| Lp. | Model | Zbiór Treningowy | Accuracy | Macro F1 | Trunk Precision | Trunk Recall | Trunk F1 |
|:---:|:---|:---|:---:|:---:|:---:|:---:|:---:|
| 1 | **PointNet++** | Real | 0.9265 | 0.7385 | 0.2702 | 0.3120 | 0.2896 |
| 2 | **PointNeXt** | Real | 0.9167 | 0.7908 | 0.3245 | 0.7300 | 0.4493 |
| 3 | **SpConv** | Real | 0.9314 | 0.8072 | 0.3782 | 0.6950 | 0.4898 |
| 4 | **SpConv** | Synth | 0.9437 | 0.8094 | 0.4609 | 0.5262 | 0.4914 |
| 5 | **SpConv** | **Real + Synth** | 0.9415 | **0.8267** | 0.4238 | 0.7184 | **0.5332** |
| 6 | **PTv3** | Real | 0.9324 | 0.8144 | 0.3842 | **0.7406** | 0.5059 |
| 7 | **PTv3** | Synth | **0.9425** | 0.8006 | **0.4703** | 0.4712 | 0.4707 |
| 8 | **PTv3** | Real + Synth | *TBD* | - | - | - | - |

---

## 2. Kluczowe obserwacje i wnioski

### Wpływ Architektury
*   **Ewolucja Baseline:** PointNet++ wykazuje najniższą skuteczność w detekcji pni. Przejście na nowsze architektury (PointNeXt, SpConv, PTv3) pozwoliło na skokowy wzrost czułości (Recall) pnia z poziomu ~31% do ponad 70%.
*   **PTv3 vs SpConv:** PTv3 na danych rzeczywistych oferuje najwyższą zdolność wykrywania pni (Recall 0.74). Jednak SpConv wykazuje większą stabilność procesu uczenia przy ograniczonych zasobach sprzętowych (Batch Size).

### Rola Danych Syntetycznych
*   **Poprawa Precyzji:** Trening na danych syntetycznych drastycznie redukuje błędy typu *False Positive* dla pni. Precyzja (Precision) wzrosła z poziomu ~38% do ~47%. Dane syntetyczne dostarczają modelowi czystych wzorców geometrycznych pnia, których brakuje w zaszumionych danych leśnych.
*   **Synergia Real+Synth:** Najlepszy ogólny wynik (Macro F1: 0.8267) uzyskano łącząc oba typy danych. Dane syntetyczne działają jako regularizator, który uczy model geometrii, podczas gdy dane rzeczywiste uczą radzenia sobie z naturalnym szumem i gęstością chmury punktów.

### Trudność klasy "Trunk"
*   Niska precyzja klasy *Trunk* we wszystkich modelach (poniżej 50%) wynika z ogromnej dysproporcji klasowej (koron jest ~16x więcej niż pni) oraz fizycznego podobieństwa punktów w strefie przejściowej między pieńem a koroną.
*   Zastosowanie wag w funkcji straty (np. 6x dla pnia) wymusza na modelu priorytetyzację wykrywania pni, co jest pożądanym efektem w inwentaryzacji leśnej.

---

## 3. Uwagi techniczne do optymalizacji
*   **Niestabilność PTv3:** Przy treningu PTv3 na danych syntetycznych zaobserwowano oscylacje straty (Loss), co wynika z konieczności użycia małego Batch Size (BS=1). Architektura oparta na *Attention* jest bardziej wrażliwa na szum gradientu niż modele splotowe (SpConv).
*   **Zalecenie:** Dla stabilizacji wyników PTv3 przy małym batchu zaleca się stosowanie akumulacji gradientu (*Gradient Accumulation*).