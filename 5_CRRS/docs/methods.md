# Methods – what the pipeline computes

Specification of every step of `run.py`. Changes together with the code. Config keys in `code`.

## 0. Inputs and filters

| Input | Format | Position used |
|---|---|---|
| Arbor tree list per cloud | `tree_list_<dataset>.csv` | stem root (`X_root`, `Y_root`) |
| 3DFin output per cloud | `<dataset>.xlsx`, sheets `Plot metrics`, `Diameters`, `Sections` | stem at 1.3 m |
| Reference (`reference.csv`) | Arbor tree list of TLS – raw in packages, SegFix-corrected in the final run | stem root |

Filters, applied in the same way to the reference and to every Arbor file:
- `arbor.exclude_status` (main: `W3 allometry`) – removes short segments, mostly stem-base fragments.
  `W2 no valid measure` stays: real trees without a valid DBH fit.
- `arbor.max_root_above_bh` (1.0 m) – removes segments whose root lies above their breast-height
  point (crown fragments).
- `region` (optional `{x, y, radius}`) – reference trees inside the circle; compared datasets inside
  radius + `matching.max_dist`, so edge trees can still be matched; unmatched trees outside the
  radius are not counted.
- 3DFin: DBH = 0 → missing; sections with diameter 0 (no fit) are dropped.

## 1. Matching and detection (`--step matching`, `--step sensitivity`)

- Each dataset is matched with the reference one-to-one by XY distance (Hungarian algorithm):
  maximum number of pairs with minimum total distance; pairs farther than `matching.max_dist`
  (0.5 m) are not allowed. Only XY is used – status and size play no role.
- TP = matched pair; FN = reference tree without a pair; FP = test tree without a pair.
- precision = TP / (TP + FP); recall = TP / (TP + FN); F1 = 2·P·R / (P + R).
- Error types: FN `too_far` (no test tree within max_dist) or `taken` (the nearby test tree was
  matched to another reference tree); FP `duplicate` (within `matching.duplicate_dist`, 0.3 m, of a
  matched test tree = over-segmentation) or `extra` (stand-alone).
- Two runs against the same reference: `arbor` and `3dfin` (3DFin includes the TLS cloud, which
  links 3DFin trees to the reference ID).
- Sensitivity step: the Arbor detection is repeated for filter variants from `arbor.sensitivity`.

| Variant | `exclude_status` | Role | Question |
|---|---|---|---|
| `main` | `["W3 allometry"]` | main result, declared in advance | tree detection |
| `no_filter` | `[]` | sensitivity | over-segmentation (all segments) |
| `measured_only` | `["W3 allometry", "W2 no valid measure"]` | sensitivity | trees with a measurable DBH |

Outputs:
- `outputs/matching/<tool>/link_table.csv` – one row per reference tree, matched ID and distance per dataset.
- `outputs/matching/<tool>/detection_summary.csv` – TP, FN, FP, FP_duplicate, FP_extra, precision, recall, F1.
- `outputs/matching/<tool>/match_details.csv` – one row per tree: match, error type, nearest tree, status and height.
- `outputs/matching/<tool>/matched_predictions/*.png` – map per dataset.
- `outputs/sensitivity/detection_variants.csv` – all variants in one table (`variant`, `n_reference`, metrics).

## 2. Measurement agreement, Arbor (`--step accuracy`)

- Only matched pairs (TP) of the `arbor` run. Difference per pair d = test − reference.
- Parameters (`accuracy.parameters`): `dbh` [cm] and `v` [m³] only for pairs where both trees are
  `measured`; `h` [m] for all pairs; `xy_offset` [m] = pair distance.
- Per dataset and parameter: n, bias = mean(d), RMSE = √mean(d²), SD of d, SE = SD/√n,
  z = bias/SE, ref_mean (mean reference value of the same pairs), bias % and RMSE % = value / ref_mean.
- Trees: `accuracy.tree_subset` = `all` (every matched tree) or `selected` (`selected_trees`).
- Outlier pairs: pairs with |ΔH| > `accuracy.outlier_dh` (3 m) are flagged – usually a reference
  tree matched to a fragment.

Outputs (`outputs/accuracy/arbor/`):
- `paired_differences.csv` – one row per pair and parameter, statuses, pair distance, `outlier_pair`.
- `accuracy_summary.csv` – main result.
- `accuracy_summary_no_outliers.csv` – the same without outlier pairs.
- `accuracy_summary_common_trees.csv` – DBH and V on reference trees compared in every dataset.

## 3. Stem profiles, 3DFin (`--step stem_profiles`)

- Reference = 3DFin result of TLS (`stem_profiles.reference_dataset`). Pairs from the `3dfin` link table.
- Per pair, only sections fitted in both trees at the same height; d = test − reference diameter [cm].
- Per dataset and section height: n, bias, RMSE, SD, SE, z, percentages (as in step 2).
- Bands (`stem_profiles.bands`, default lower 1–3 m, upper 6–9 m, all 1–9 m): mean of the per-height
  values over heights with n ≥ `stem_profiles.min_pairs` (5). Reach = highest section with
  n ≥ min_pairs (lower sections may still have fewer pairs).

Outputs (`outputs/stem_profiles/`): `stem_profile_differences.csv`, `stem_profile_summary.csv`,
`stem_profile_bands.csv`, `stem_profile.png` (bias, RMSE and n vs. height).

## 4. Comparison of packages (`scripts/compare_experiments.py`)

Collects the outputs of all packages and evaluates the sanity checks and tests of
`docs/analysis_plan.md`. Outputs in `experiments/comparison/`: `experiments.csv`, `detection.csv`,
`detection_variants.csv`, `accuracy.csv`, `stem_profile_bands.csv`, `tests.csv`, `tests_matrix.csv`.
