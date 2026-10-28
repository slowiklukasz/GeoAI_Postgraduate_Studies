# Analysis plan – hypotheses, decision rules, predictions

Status: **draft – freeze before packages P01+ are run.** After that, criteria are not changed;
new ideas are added as new tests (`N…`) and recorded in the change log. This file wins over code
and agents; `scripts/compare_experiments.py` implements it (thresholds at the top of the script).

P00 is exploratory: the hypotheses below come from its results (run with the SegFix-corrected
TLS reference; Arbor: all matched trees, except C1 where Arbor values are for the same 10 selected
trees as the 3DFin profiles). P00 must be re-run with the raw TLS reference before it is compared
with other packages; packages use all matched trees in both tools.

## Decision rules
- d = HLS − reference, matched pairs only. SE = SD/√n, z = bias/SE (columns of the summaries).
- Clearly non-zero bias: |z| ≥ 2. Indistinguishable from zero: |z| < 2.
- n < 5 → `no_data`; 5 ≤ n < 10 → status allowed, confidence `low`.
- Band values and reach: `stem_profile_bands.csv` (heights with n ≥ min_pairs).
- Rates instead of counts where tree numbers differ between packages.

| Status | Meaning |
|---|---|
| `confirmed` | criterion met |
| `inconclusive` | direction as expected but \|z\| < 2 |
| `not_confirmed` | criterion not met |
| `no_data` | file, scanner or minimum n missing |

## Sanity checks (a failure stops the package analysis)
| ID | Check | Criterion | Source |
|---|---|---|---|
| I1 | Same coordinate frame | median pair distance < 0.2 m for every dataset in both tools | link tables |
| I2 | Complete inputs | three HLS in Arbor and 3DFin, TLS in 3DFin | detection summaries |
| I3 | 3DFin TLS linked to the reference | recall ≥ 0.9 | matching/3dfin/detection_summary.csv |

## Tests
| ID | Hypothesis | Criterion | Source | P00 value | P00 |
|---|---|---|---|---|---|
| D1 | All HLS detect nearly all reference trees | recall ≥ 0.95 for all HLS | matching/arbor/detection_summary.csv | 1.00 / 1.00 / 1.00 | ✓ |
| D2 | LiGrip is the most over-segmented | FP_duplicate per reference tree: LiGrip highest and ≥ 0.05 | same | 0.067 vs 0 / 0 | ✓ |
| A1 | low-cost overestimates DBH | bias > 0, z ≥ 2 | accuracy_summary.csv | +2.24 cm, z = 6.4 | ✓ |
| A2 | LiGrip underestimates DBH | bias < 0, z ≤ −2 | accuracy_summary.csv | −5.93 cm, z = −8.6 | ✓ |
| A3 | GeoSLAM DBH agrees with TLS | \|z\| < 2 | accuracy_summary.csv | −0.31 cm, z = −1.1 | ✓ |
| A4 | LiGrip DBH is hardest to measure | n(DBH)/n(H): LiGrip lowest and < 0.5 | accuracy_summary.csv | 0.30 vs 0.93 / 0.93 | ✓ |
| A5 | Height agrees for GeoSLAM and low-cost | \|z\| < 2 for both | accuracy_summary.csv | z = −0.1 / −0.8 | ✓ |
| A6 | LiGrip height bias comes from outlier pairs | \|bias\| < 0.5 m without outlier pairs | accuracy_summary_no_outliers.csv | −0.23 m | ✓ |
| A7 | LiGrip stem positions shift most | LiGrip highest mean xy_offset | accuracy_summary.csv | 0.11 vs 0.05 / 0.06 m | ✓ |
| S1 | low-cost overestimates diameter, more higher up | 0 < lower < upper | stem_profile_bands.csv | +2.61 < +4.92 cm | ✓ |
| S2 | LiGrip underestimates diameter along the stem | lower < 0 and upper < 0 | stem_profile_bands.csv | −1.90 / −2.40 cm | ✓ |
| S3 | GeoSLAM profile is closest to TLS | smallest \|bias\| in band `all` | stem_profile_bands.csv | −0.40 vs −2.14 / +3.96 cm | ✓ |
| S4 | Stem reach GeoSLAM ≥ low-cost ≥ LiGrip | order of reach | stem_profile_bands.csv | 14.5 / 12.3 / 10.7 m | ✓ |
| C1 | Arbor and 3DFin agree on the sign of DBH bias | same sign of Arbor DBH bias and 3DFin bias at 1.3 m, LiGrip and low-cost | accuracy_summary.csv, stem_profile_summary.csv | −6.2 / −2.0; +2.5 / +2.0 cm | ✓ |

Exploratory (promote to a test if it recurs): E1 GeoSLAM volume lower than TLS despite unbiased
DBH (−11 %, z = −6.8). Dropped: "GeoSLAM has the best F1" (ties at 1.0).

## Replication across packages
| Class | Rule |
|---|---|
| robust | `confirmed` in every package with data |
| setting-dependent | `confirmed` in some and `not_confirmed` in others, aligned with the one factor that differs |
| fragile | `inconclusive` in at least half of the packages with data |
| contradicted | significant opposite sign (\|z\| ≥ 2) in any package – always reported |

## Predictions (written before P01+)
| Comparison | Factor | Prediction |
|---|---|---|
| P01 vs P00 | clip / region | same statuses; some may become `inconclusive` (smaller n) |
| P02 vs P01 | Arbor READ_FRACTION 0.2 → 1.0 | A4: DBH share rises, most for LiGrip (≥ +0.10); A2: \|LiGrip DBH bias\| decreases; D2: open |
| P02 vs P01 | control | 3DFin results (S1–S4, 3DFin part of C1) unchanged |

## Change log
| Date | Change | Reason |
|---|---|---|
| 2026-10-28 | First draft from P00 results | – |
