# Analysis protocol – one package

Procedure for the `experiment-analyst` agent (and for people doing the same by hand). Produces
`report.md` and `tests.csv` in the package folder in the format of `docs/output_schema.md`, at the
depth of `docs/examples/report_example.md`.

Read first: `docs/methods.md` (what the numbers are), `docs/interpretation.md` (how to read them),
`docs/analysis_plan.md` (tests), the package `config.yaml` (`experiment` block).

## General rules
- Every number comes from a named output file, or from a command in the appendix of the report
  (see "Extra computations"). Never estimate in text.
- Results first, then meaning: a finding says what the number means, not only what it is.
- Causes are hypotheses unless checked on the clouds; each part ends with what to check.
- Look at the figures (`matched_predictions/*.png`, `stem_profile.png`) – they often show what the
  table hides (clusters of FP, edge effects, noisy heights).
- Before ranking scanners, check `n` and `ref_mean`: different n = different trees.
- Short: 3–6 findings per part.

## Part 0 – Setup and sanity checks
1. `experiment` block: what changed, reference type, clip / region, read fraction.
2. Inputs: all files present; X/Y ranges of reference, Arbor and 3DFin files overlap; Arbor status
   counts per file (`measured`, W2, W3, other) – table in the report.
3. Run `python run.py --config experiments/<package>/config.yaml`. On an error: report and stop.
4. I1–I3 (`docs/analysis_plan.md`). A failure: report and stop.

## Part 1 – Tree detection
Files: `outputs/sensitivity/detection_variants.csv`, `outputs/matching/arbor/match_details.csv`,
`outputs/matching/3dfin/detection_summary.csv`, maps in `outputs/matching/arbor/matched_predictions/`.
1. Table of the three filter variants per scanner (`main` = W3, `no_filter`, `measured_only`) and the
   small table "Filter – what it measures – reference trees".
2. main: does recall separate the scanners? FP split into duplicates and extras.
3. no_filter: duplicates per scanner (also per reference tree) = over-segmentation; FN here come from
   fragments in the reference – say so.
4. measured_only: recall = share of trees with a measurable DBH; name the scanner where it drops.
5. 3DFin: recall and FP per dataset, including TLS.
6. Open 3–5 FP in `match_details.csv` (status, height, nearest tree) and name what they are.
7. Causes: link detection, over-segmentation and DBH measurability when they point to the same
   part of the stem.

## Part 2 – Measurement agreement (Arbor)
Files: `outputs/accuracy/arbor/accuracy_summary.csv`, `accuracy_summary_no_outliers.csv`,
`accuracy_summary_common_trees.csv`, `paired_differences.csv`.
1. Main table (n, bias, RMSE, z, bias %, RMSE %) and controls table.
2. DBH per scanner: direction; systematic or random (RMSE vs |bias|, SD, share of trees with the same
   sign); does the difference grow with stem size (correlation of d with ref_value); is it the same on
   the common trees.
3. Height: with and without outlier pairs; which pairs are outliers (→ Part 2c).
4. Volume: does it follow DBH; if not, say it is a model effect and treat V as secondary.
5. Position: mean offset vs max_dist.
6. Causes per scanner; link them to Part 1 where it fits.

## Part 2b – Selected trees (only if `accuracy.tree_subset: selected`)
1. How the selected trees differ from all trees (ref_mean of DBH and H, from a run with `all` or an
   extra computation).
2. Same table as Part 2; bias all → selected; SE per scanner; changes smaller than SE are not changes.

## Part 2c – Per-tree cases
File: `outputs/accuracy/arbor/paired_differences.csv`.
1. All outlier pairs and the 2–3 largest |d| per scanner for DBH and H: ref_id, test_id, values, statuses.
2. Classify each case (`docs/interpretation.md`, per-tree cases): reference suspect (two scanners agree
   with each other, not with TLS), segmentation error on one cloud (fragment, cut crown), tree top not
   visible from the ground (all HLS lower).
3. Statistics without these cases (n / bias / RMSE) – shows how much one tree drives the result.
4. 2–4 candidates for figures: tree, view (cross-section at 1.3 m, segment, vertical profile), what it shows.

## Part 3 – Stem profiles (3DFin)
Files: `outputs/stem_profiles/stem_profile_summary.csv`, `stem_profile_bands.csv`, `stem_profile.png`.
1. Table at selected heights (0.3, 1.3, 3.1, 5.1, 8.1, 10.1, 12.1 m): bias / bias % / n; band table
   with reach.
2. Pattern per scanner: constant, growing with height (absolute values, not only per cent),
   near-ground only; RMSE vs |bias|; reach order.
3. Arbor vs 3DFin at breast height: Arbor DBH bias (n) next to 3DFin bias at 1.3 m (n) per scanner;
   same sign? which tool measures more trees?
4. Causes per scanner.

## Tests
Evaluate every test of `docs/analysis_plan.md` literally and write `tests.csv` (format in
`docs/output_schema.md`). Keep the status even with a small margin – lower `confidence` instead.
New findings worth checking in other packages: `N1`, `N2`, … with a precise criterion.

## Limitations and "For the report"
Limitations: reference type, sample size, matching by XY only, hypotheses not checked on the clouds,
settings of this package. "For the report": which table or figure of this package is worth using.

## Extra computations (allowed, quote the command in the appendix)
Run from the repo root; `P` = package folder.

```python
import pandas as pd
P = "experiments/P01_clip_rf02"
d = pd.read_csv(f"{P}/outputs/accuracy/arbor/paired_differences.csv", dtype={"ref_id": str, "test_id": str})

# median, SD, share of positive differences, correlation with the reference value
g = d.groupby(["dataset", "parameter"])
print(g["diff"].agg(n="count", median="median", sd="std", share_pos=lambda s: (s > 0).mean()))
print(g.apply(lambda x: x["diff"].corr(x["ref_value"])))

# statistics without some trees
x = d[~d["ref_id"].isin(["454", "136"])]
print(x.groupby(["dataset", "parameter"])["diff"].agg(
    n="count", bias="mean", rmse=lambda s: (s ** 2).mean() ** 0.5))

# largest differences
print(d.loc[d["diff"].abs().sort_values(ascending=False).index].groupby(["dataset", "parameter"]).head(3))

# stem profile at selected heights
s = pd.read_csv(f"{P}/outputs/stem_profiles/stem_profile_summary.csv")
print(s[s["height"].round(1).isin([0.3, 1.3, 3.1, 5.1, 8.1, 10.1, 12.1])])
```
