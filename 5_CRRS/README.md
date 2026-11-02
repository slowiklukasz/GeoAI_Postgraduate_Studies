# Benchmarking handheld laser scanners against TLS in a forest plot

Compares individual-tree results from three handheld laser scanners (GeoSLAM ZEB Horizon, LiGrip and a
low-cost device) with terrestrial laser scanning (TLS, Trimble X7) on one forest plot with dense understorey.
Inputs are Arbor instance-segmentation results (tree detection, DBH, height, volume)
and 3DFin stem profiles; outputs are tables and figures for a short benchmarking report.

TLS is a relative reference, not ground truth: all results are **differences from TLS**, not errors.

![The same tree in four point clouds](assets/tree_side_view.png)
*The same tree extracted from the TLS, GeoSLAM, LiGrip and low-cost point clouds (`scripts/extract_tree.py`).*

![Stem diameter differences along the stem](assets/stem_profiles.png)
*Stem diameter differences from TLS along the stem, 3DFin (`run.py`, step `stem_profiles`).*

## What it does

1. **Detection** – pairs the trees of each scanner with the TLS reference by position (one-to-one,
   Hungarian algorithm) and reports TP / FN / FP, precision, recall and F1. Additional detections close to a
   matched tree are flagged as duplicates (over-segmentation).
2. **Tree measurements** – for matched trees: bias and RMSE of DBH, height and volume (also in % of the TLS
   mean), on all trees or on a selected subset.
3. **Stem profiles** – bias and RMSE of stem diameter per section height (3DFin), with the height reach of
   each scanner.
4. **Filter sensitivity** – repeats detection with other Arbor status filters.

## Installation

```
pip install -r requirements.txt
```

If an existing environment reports a NumPy 1.x / 2.x conflict, install `numpy<2` or use a fresh environment.

## Run

```
python run.py --config configs/config.yaml                       # all steps
python run.py --config configs/config.yaml --step matching
python run.py --config configs/config.yaml --step accuracy
python run.py --config configs/config.yaml --step stem_profiles
python run.py --config configs/config.yaml --step sensitivity
```

- `accuracy` and `stem_profiles` read the link tables saved by `matching` – run `matching` first.
- Every run copies the config to `output_dir/config_used.yaml`; a missing config key stops the run with its name.

## Inputs and config (`configs/config.yaml`)

- `reference.csv` – Arbor `tree_list.csv` of the TLS cloud (e.g. corrected in SegFix); master key for all analyses.
- `inputs.arbor_csv_dir` – Arbor `tree_list_<dataset>.csv` per scanner.
- `inputs.threedfin_xlsx_dir` – 3DFin `<dataset>.xlsx` per scanner, including TLS.
- All clouds must share one coordinate system (in CloudCompare: load without global shift before Arbor / 3DFin).
- `arbor.exclude_status` – statuses removed from the reference and all scanners alike (default `W3 allometry`:
  short stem fragments); `max_root_above_bh` removes segmentation artefacts.
- `matching.max_dist` (0.5 m), `matching.duplicate_dist` (0.3 m).
- `accuracy.tree_subset` – `selected` (IDs in `selected_trees`) or `all`; DBH and volume use only pairs with a
  measured DBH in both clouds.
- `stem_profiles.min_pairs` – heights with fewer compared trees are not plotted.
- Optional `region: {x, y, radius}` limits all analyses to a circle.

## Outputs (`output_dir`)

| Folder | Main files |
|---|---|
| `matching/<arbor or 3dfin>/` | `link_table.csv`, `detection_summary.csv`, `match_details.csv`, detection maps |
| `accuracy/arbor/` | `paired_differences.csv`, `accuracy_summary.csv` (n, bias, RMSE, %) |
| `stem_profiles/` | `stem_profile_summary.csv`, `stem_profile_bands.csv`, `stem_profile.png` |
| `sensitivity/` | `detection_variants.csv` |

## Helper scripts (`scripts/`)

**Tree selection** – proposes trees for `selected_trees`, from occluded to well-visible stems
(visibility from 3DFin sector occupancy); run `matching` first.

```
python scripts/select_trees.py --config configs/config.yaml --n 10 --min-height-quantile 0.5
```
**Same tree in several clouds** – extracts one tree from instance-segmented LAZ files (reference tree by ID,
the others matched by stem position), saves one LAZ per cloud and plots side views from four directions.

```
python scripts/extract_tree.py --clouds TLS=tls.laz GeoSLAM=geoslam.laz LiGrip=ligrip.laz low-cost=low_cost.laz \
    --reference TLS --ref-id 10 --out-dir tree_10
```

## Interpretation

- Detection and measurement agreement are separate questions; report both.
- Compare scanners on the same trees where possible – check `n` before comparing rows.
- RMSE close to |bias| means a consistent offset; RMSE much larger than |bias| means scatter or single outlying pairs.
- Large height differences usually come from a pair matched to a fragment – check `paired_differences.csv`.

## Layout

```
run.py                  CLI: config path + step
configs/config.yaml     all parameters
pcbench/                loaders, matching, accuracy, plotting, pipeline
scripts/
  select_trees.py       proposes trees for selected_trees
  extract_tree.py       same tree from several LAZ clouds + side-view plots
assets/                 figures for this README
requirements.txt
```

## Data

The point clouds and Arbor / 3DFin results are not included in this repository.

## About

Course project *Benchmarking forest point clouds* (2026), Łukasz Słowik and Michał Kajetanek.
