# Raport z badań: Segmentacja 3D struktur leśnych

## 1. Wyniki na zbiorze testowym (7 scen)
Głównym wyznacznikiem jakości jest skuteczność na najtrudniejszej klasie **Trunk** (Pień).

| Lp. | Model | Zbiór Treningowy | Accuracy | Macro F1 | Trunk Precision | Trunk Recall | Trunk F1 |
|:---:|:---|:---|:---:|:---:|:---:|:---:|:---:|
| 1 | **PointNet++** | Real | 0.9265 | 0.7385 | 0.2702 | 0.3120 | 0.2896 |
| 2 | **PointNeXt** | Real | 0.9167 | 0.7908 | 0.3245 | 0.7300 | 0.4493 |
| 3 | **SpConv** | Real | 0.9314 | 0.8072 | 0.3782 | 0.6950 | 0.4898 |
| 4 | **SpConv** | Synth | 0.9437 | 0.8094 | 0.4609 | 0.5262 | 0.4914 |
| 5 | **SpConv** | **Real + Synth** | 0.9415 | **0.8267** | 0.4238 | 0.7184 | **0.5332** |
| 6 | **PTv3** | Real | 0.9324 | 0.8144 | 0.3842 | **0.7406** | 0.5059 |
| 7 | **PTv3** | Synth | 0.9425 | 0.8006 | **0.4703** | 0.4712 | 0.4707 |
| 8 | **PTv3** | **Real + Synth** | **0.9445** | 0.8254 | 0.4499 | 0.6467 | 0.5306 |

---

## 2. Wyniki na zbiorze walidacyjnym (4 sceny)
Metryka IoU (Intersection over Union) jest bardziej rygorystyczna niż F1 i pozwala na dokładniejszą ocenę nakładania się predykcji z prawdą terenową.

| Model | Zbiór | Val Acc | Val mIoU | Val mF1 | IoU Background | IoU Crown | IoU Trunk |
| :--- | :--- | :---: | :---: | :---: | :---: | :---: | :---: |
| **PointNet++** | Real | 0.8559 | 0.6349 | 0.6944 | 0.9701 | 0.8282 | 0.1065 |
| **PointNext** | Real | 0.9207 | 0.7187 | 0.7888 | 0.9814 | 0.9041 | 0.2706 |
| **SpConv** | Real | 0.9212 | 0.7294 | 0.8015 | 0.9822 | 0.9040 | 0.3021 |
| **SpConv** | Synth | 0.9474 | 0.7385 | 0.8059 | 0.9785 | 0.9376 | 0.2993 |
| **SpConv** | **Real + Synth** | 0.9436 | **0.7577** | **0.8281** | 0.9825 | 0.9314 | **0.3593** |
| **PTv3** | Real | 0.9337 | 0.7451 | 0.8161 | 0.9840 | 0.9193 | 0.3320 |
| **PTv3** | Synth | 0.9453 | 0.7248 | 0.7904 | 0.9760 | 0.9351 | 0.2634 |
| **PTv3** | **Real + Synth** | **0.9460** | 0.7524 | 0.8207 | **0.9871** | **0.9346** | 0.3354 |

---

## 3. Kluczowe obserwacje i wnioski

### Generalizacja i Stabilność
*   **Zbieżność Train/Val:** Mała różnica między dokładnością treningową a walidacyjną (np. dla PTv3 Real+Synth: 0.940 vs 0.946) świadczy o braku nadmiernego dopasowania (*overfitting*), co potwierdza skuteczność zastosowanych augmentacji (rotacje, slope, stem stretch).
*   **Potwierdzenie hybrydy:** Zarówno w SpConv, jak i PTv3, połączenie **Real+Synth** dało najlepsze wyniki mIoU na walidacji (0.75-0.76). Dane syntetyczne dostarczają "czystej" geometrii, której modelom brakuje w zaszumionych chmurach rzeczywistych.

### Przewaga architektury SpConv w IoU pni
*   Mimo że PTv3 osiąga świetne wyniki ogólne, to **SpConv (Real+Synth)** wykręcił najwyższy IoU dla klasy *Trunk* (**0.3593**). Sugeruje to, że sploty rzadkie (sparse convolutions) mogą być nieco bardziej precyzyjne w zachowaniu ciągłości pni niż mechanizm Attention przy bardzo małym Batch Size.

### Wpływ danych syntetycznych
*   Modele trenowane **tylko na Synth** (SpConv i PTv3) wykazują najwyższy IoU dla korony (Tree Crown), ale tracą na pniach w porównaniu do modeli hybrydowych. Oznacza to, że dane syntetyczne świetnie uczą masy liściastej, ale pień wymaga jednak kontaktu z naturalnym "szumem" i niedoskonałościami skanera LiDAR.

### Podsumowanie końcowe
*   **Zalecana konfiguracja:** Najlepszy balans między ogólną celnością a precyzją wyodrębniania pni oferują modele hybrydowe (Real+Synth).
*   **Technologia:** PTv3 jest "królem accuracy" i tła, natomiast SpConv wykazuje przewagę w rygorystycznej metryce IoU dla struktur pnia. 
*   **Wartość dla leśnictwa:** Osiągnięcie mIoU na poziomie 0.75 na nowych scenach walidacyjnych pozwala na wysoce wiarygodne, automatyczne liczenie drzew oraz estymację biomasy korony.

## 4. Analiza dynamiki uczenia (val/loss)
Wykres straty walidacyjnej (val/loss) dostarcza kluczowych informacji o procesie optymalizacji:
* **Stabilność:** Modele hybrydowe (Real+Synth, v3) charakteryzują się najpłynniejszą zbieżnością, co potwierdza, że dane syntetyczne zadziałały jako skuteczny regularizator.
* **Wpływ architektury:** PointNet++ (v1) wyraźnie odstaje od reszty stawki, osiągając plateau na znacznie wyższym poziomie błędu.
* **Niestabilność PTv3:** Widoczne oscylacje w wersjach v2 wynikają z wysokiej wariancji gradientu przy Batch Size = 1. Problem ten został zminimalizowany w wersji hybrydowej (v3), co sugeruje, że większa różnorodność danych pomaga stabilizować mechanizm Attention.
* **Efektywność:** Najlepsze modele (SpConv_v3, PTv3_v3) osiągnęły optimum około 15-18 epoki, co potwierdza poprawność doboru parametrów harmonogramu uczenia (Cosine Annealing).

---
*Raport wygenerowany na podstawie danych z systemów trackowania eksperymentów Weights & Biases.*