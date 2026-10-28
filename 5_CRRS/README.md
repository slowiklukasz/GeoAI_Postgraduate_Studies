# scanner-benchmark

Compares tree detection and tree measurements from handheld laser scanners (HLS) with a TLS reference, using Arbor and 3DFin outputs.

## Run

```
python run.py --config configs/config.yaml               # all steps
python run.py --config configs/config.yaml --step matching
python run.py --config configs/config.yaml --step accuracy
python run.py --config configs/config.yaml --step stem_profiles
python run.py --config configs/config.yaml --step sensitivity
```

- `accuracy` and `stem_profiles` read the link tables saved by `matching` – run `matching` first.
- Full specification of every step: `docs/methods.md`; how to read the outputs: `docs/interpretation.md`.
- Every run copies the config to `output_dir/config_used.yaml`.
- All config keys are required; a missing key stops the run with its name.

## Inputs (`reference`, `inputs`)

- `reference.csv` – Arbor `tree_list.csv` of the TLS cloud (raw in analysis packages, corrected in SegFix in the final run); master key for all analyses.
- `inputs.arbor_csv_dir` – Arbor `tree_list_<dataset>.csv` per scanner; dataset name = file name without `tree_list_`.
- `inputs.threedfin_xlsx_dir` – 3DFin `<dataset>.xlsx` per scanner, including TLS; dataset name = file name.
- All clouds must share one coordinate system – in CloudCompare load every cloud without global shift ("No" in the shift dialog) before running Arbor / 3DFin.

## Filtering (`arbor`)

- Applied to the reference **and** to every Arbor file in the same way.
- `exclude_status` – statuses removed before matching; default `W3 allometry` (short segments, mostly stem-base fragments).
- `W2 no valid measure` is kept – real trees without a valid DBH fit.
- `max_root_above_bh` – removes segments whose root lies more than this [m] above their breast-height point (crown fragments).
- Removed trees take no part in matching, metrics or plots.
- `sensitivity` – extra detection runs with other status filters (step `sensitivity`), e.g.
  `no_filter: []` (all segments → over-segmentation) and `measured_only: [W3, W2]` (DBH measurability).
- Optional `region: {x, y, radius}` – reference trees inside the circle, compared trees inside
  radius + `max_dist`; unmatched trees outside the radius are not counted.
- 3DFin: DBH = 0 → missing; sections with diameter 0 (no fit) are ignored.

## Step 1 – matching (`matching`)

- Pairs trees of each dataset with the reference by XY position (Arbor: root; 3DFin: stem at 1.3 m).
- One-to-one (Hungarian algorithm): maximum number of pairs, then minimum total distance; pairs farther than `max_dist` are not allowed.
- Only XY is used – status, DBH and height do not influence pairing.
- TP = matched pair, FN = reference tree without a pair, FP = test tree without a pair.
- precision = TP / (TP + FP), recall = TP / (TP + FN), F1 = harmonic mean of both.
- Error types:
  - FN `too_far` – no test tree within `max_dist`; FN `taken` – nearby test tree matched to another reference tree.
  - FP `duplicate` – within `duplicate_dist` of a matched test tree (over-segmentation); FP `extra` – stand-alone detection.
- Two runs, both against the same Arbor reference: `arbor` (Arbor results) and `3dfin` (3DFin results) → one common reference ID.
- Outputs per run (`matching/<run>/`):
  - `link_table.csv` – one row per reference tree; matched ID and distance per dataset (empty = missed).
  - `detection_summary.csv` – TP / FN / FP (duplicate / extra), precision, recall, F1 per dataset.
  - `match_details.csv` – one row per tree and dataset: match type, error type, nearest tree, status and height of both sides.
  - `matched_predictions/ref-<reference>_test-<dataset>.png` – map per dataset (if `save_plot`).

## Step 2 – accuracy (`accuracy`, Arbor)

- Only matched pairs (TP); unmatched trees are covered by the detection metrics.
- Difference per pair: d = test − reference.
- bias = mean(d) – sign shows over- (+) or underestimation (−) relative to the reference.
- RMSE = √mean(d²) – typical size of the difference, regardless of sign.
- sd, se = sd/√n, z = bias/se – |z| ≥ 2: bias clearly different from zero at this n.
- ref_mean = mean reference value of the same pairs; bias_pct and rmse_pct = bias / ref_mean and RMSE / ref_mean × 100.
- Parameters (`accuracy.parameters`):
  - `dbh` [cm] – only pairs where both trees are `measured`.
  - `h` [m] – all pairs.
  - `v` [m³] – only pairs where both trees are `measured`.
  - `xy_offset` [m] – pair distance from the link table; bias = mean offset, no percentages.
- Trees (`accuracy.tree_subset`): `selected` = IDs in `selected_trees` (empty list → all matched trees, with a warning); `all` = every matched tree.
- `n` can differ between datasets and parameters (missed trees, DBH not measured).
- Outputs (`accuracy/arbor/`):
  - `paired_differences.csv` – one row per pair and parameter, with statuses, pair distance and
    `outlier_pair` (|ΔH| > `accuracy.outlier_dh`, usually a reference tree matched to a fragment).
  - `accuracy_summary.csv` – n, bias, RMSE, sd, se, z, ref_mean, bias_pct, rmse_pct per dataset and parameter.
  - `accuracy_summary_no_outliers.csv` – the same without outlier pairs.
  - `accuracy_summary_common_trees.csv` – DBH and V on reference trees compared in every dataset.

## Step 3 – stem profiles (`stem_profiles`, 3DFin)

- Reference = 3DFin dataset named in `stem_profiles.reference_dataset` (TLS).
- Pairs come from the `3dfin` link table: reference ID → 3DFin TLS tree and 3DFin test tree.
- Only sections fitted in both trees, at the same height, are compared; diameters in cm.
- bias / RMSE / percentages as in step 2, computed per dataset and section height.
- Same tree selection as step 2 (`tree_subset`, `selected_trees`).
- Plot skips heights with fewer than `min_pairs` compared trees.
- Outputs (`stem_profiles/`):
  - `stem_profile_differences.csv` – one row per pair and common section.
  - `stem_profile_summary.csv` – n, bias, RMSE, sd, se, z, percentages per dataset and height.
  - `stem_profile_bands.csv` – mean bias / RMSE per height band (`stem_profiles.bands`) over heights
    with n ≥ `min_pairs`, and the reach (highest such height).
  - `stem_profile.png` – bias, RMSE and number of trees vs. height.

## Step 4 – filter sensitivity (`arbor.sensitivity`)

- Repeats the Arbor detection for the main filter (`main`) and every variant in `arbor.sensitivity`.
- Outputs (`sensitivity/`): `<variant>/detection_summary.csv`, `<variant>/match_details.csv`,
  `detection_variants.csv` (all variants, with `n_reference`).

## Helper – tree selection (`select_trees.py`)

```
python select_trees.py --config configs/config.yaml --n 10 --min-height-quantile 0.5
```

- Proposes trees for `selected_trees`; reads the link tables from `matching` – run it first.
- Candidates: reference status `measured`, matched to a 3DFin stem with fitted DBH in the profile reference (`stem_profiles.reference_dataset`), height ≥ the given quantile of the reference (dominant / co-dominant).
- Detection by the HLS scanners is not required (shown in `detected_*` columns only).
- Lower-stem visibility index: mean 3DFin sector occupancy (sheet `Q2(Sector Occupancy)`) of sections 0.3–2.5 m, averaged over all 3DFin clouds; sections without a fit count as 0.
- Selection: candidates sorted by visibility, split into `n` equal groups, tallest tree of each group → covers occluded to well-visible stems.
- Not checked automatically: whether a tree needed a SegFix correction – review the proposed trees visually.
- Outputs (`tree_selection/`): `tree_candidates.csv`, `selected_trees.csv`, `selected_trees_map.png`; the console prints a `selected_trees: [...]` line for the config.

## Analysis packages (`experiments/`)

- One package = one processing variant (clip, read fraction, Arbor parameter) with its own
  `config.yaml`, input data and outputs. Plan and rules: `docs/experiment_plan.md`.
- New package: copy `experiments/_template/`, fill the `experiment` block and paths, add data,
  run `python run.py --config experiments/<package>/config.yaml`.
- Optional `region: {x, y, radius}` in the config limits all analyses to a circle (clipped packages:
  radius ≈ clip radius − 3 m, so trees cut by the clip edge are ignored).
- `python scripts/compare_experiments.py` collects all packages into `experiments/comparison/` and
  evaluates the tests of `docs/analysis_plan.md` per package (`tests.csv`, `tests_matrix.csv`).
- Claude Code agents (`.claude/agents/`): `experiment-analyst` analyses one package
  (`report.md`, `tests.csv`) following `docs/analysis_protocol.md`; `experiment-comparer` compares
  packages. Formats: `docs/output_schema.md`; agent verdicts are cross-checked with the automatic ones.
- Guide for people: `docs/analysis_guide.md` and `.xlsx` (auxiliary Polish version in `docs/pl/`).

## Interpretation

- The reference is TLS, not ground truth – results are differences from TLS, not errors.
- Detection (step 1) and measurement accuracy (steps 2–3) are separate questions; report both.
- Compare datasets on the same trees where possible – check `n` and `ref_mean` before comparing rows.
- Large height differences can come from a pair matched to a fragment – check `test_status` and the pair in `paired_differences.csv`.

## Layout

```
run.py                 CLI: config path + step
select_trees.py        helper: proposes trees for selected_trees
CLAUDE.md              instructions for Claude Code
.claude/agents/        experiment-analyst, experiment-comparer
docs/                  methods, interpretation, analysis plan (tests), protocol, output schema,
                       experiment plan, analysis guide (md + xlsx), examples/, pl/ (Polish guide)
experiments/           _template/, one folder per package, comparison/
scripts/
  compare_experiments.py   cross-package tables and automatic test evaluation
configs/config.yaml    all parameters
pcbench/
  config.py            config loading and validation
  loaders.py           Arbor CSV / 3DFin xlsx -> common trees tables
  matching.py          pairing, link table, detection metrics, match details
  accuracy.py          paired differences, bias / RMSE, stem profiles
  plotting.py          matching maps, stem profile plot
  pipeline.py          steps: run_matching, run_accuracy, run_stem_profiles, run_detection_variants
```
