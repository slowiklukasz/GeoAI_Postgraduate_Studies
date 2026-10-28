# Output schema

Language: **English**. Numbers: DBH and diameters in cm with 2 decimals (1 in short tables),
H and positions in m with 2 decimals, rates with 3 decimals, z with 1 decimal, per cent with
1 decimal. Signs always shown (+2.24 / −5.93). Missing data: "no data" – never estimate.

Depth and tone: see `docs/examples/report_example.md` (P00 exploratory notes). Its numbers
belong to that run only.

## `experiments/<package>/report.md`

Every part uses the same blocks, in this order (omit a block only if it would be empty):
- **Results** – the table(s), with the source file under each table.
- **Findings** – bold lead-in per topic, then 1–3 bullets; each bullet has a number and says what it
  means ("…does not separate the scanners", "…is a matching error, not a measurement error").
- **Possible causes** – hypotheses, bold scanner or effect first; the last bullet says what would
  confirm them.
- **To check** – concrete checks on the clouds or in files (which tree, which view).

```markdown
# <ID> – <name>

Reference: <tls_raw | tls_segfix> (<file>). One-to-one matching by XY, max. <max_dist> m.
TLS is a relative reference, not ground truth.

## Part 0 – Setup and data checks
- Change vs. P00: …
- Area: whole plot | x = …, y = …, r = … m
- Reference trees after filters: … (Arbor); statuses per file: <table: file × measured / W2 / W3 / other>
- Checks I1–I3: <status + value>; data problems: …

## Part 1 – Tree detection (Arbor)
| Filter | What it measures | Reference trees |
| Scanner | Filter | TP | FN | FP | FP dupl. | FP extra | Precision | Recall | F1 |
source: outputs/sensitivity/detection_variants.csv
Findings: **Tree detection (W3 filter)**, **Over-segmentation (no filter)**,
**DBH measurability (W3 + W2 filter)**, **Detection in 3DFin** (recall / FP, also for TLS)
Possible causes, To check

## Part 2 – Tree measurements (Arbor, W3 filter)
| Scanner | Parameter | n | Bias | RMSE | z | Bias % | RMSE % |
source: outputs/accuracy/arbor/accuracy_summary.csv
Controls:
| Scanner | DBH on common trees: n / bias / RMSE [cm] | H without outlier pairs: n / bias / RMSE [m] |
sources: accuracy_summary_common_trees.csv, accuracy_summary_no_outliers.csv
Findings: **DBH**, **Height**, **Volume**, **Stem position**
Possible causes, To check

## Part 2b – Selected trees          (only if accuracy.tree_subset = selected)
Selected vs. all trees: ref_mean of DBH and H; table as in Part 2; bias all → selected; SE per scanner.

## Part 2c – Individual trees
| Tree (ref_id) | What happens | Scanner | Difference |
| Scanner | <parameter> without trees …: n / bias / RMSE |
source: outputs/accuracy/arbor/paired_differences.csv
Findings
Candidates for figures (the same situation in four clouds): tree – view – what it shows

## Part 3 – Stem profiles (3DFin)
| Height | <scanner 1> | <scanner 2> | <scanner 3> |     cells: bias [cm] / bias % / n
(heights 0.3, 1.3, 3.1, 5.1, 8.1, 10.1, 12.1 m – "–" if n < min_pairs)
| Scanner | Bias 1–3 m | Bias 6–9 m | Bias 1–9 m | Reach [m] |
sources: outputs/stem_profiles/stem_profile_summary.csv, stem_profile_bands.csv
Findings
### Arbor vs 3DFin at breast height
| Scanner | Arbor DBH bias (n) | 3DFin bias at 1.3 m (n) |
Possible causes

## Tests
| ID | Status | Evidence | Confidence |
(same content as tests.csv)

## Limitations
## For the report
2–4 points: which table / figure from this package is worth using and why.

## Appendix – extra computations
Commands used for numbers that are not in the output files.
```

## `experiments/<package>/tests.csv`

| Column | Values |
|---|---|
| `test` | `I1`–`I3`, `D1` … `C1`, or new `N1`, `N2`, … |
| `status` | `confirmed`, `inconclusive`, `not_confirmed`, `no_data`, `not_assessed` |
| `evidence` | the numbers that decided the status, e.g. `LiGrip=0.067, GeoSLAM=0, low_cost=0` |
| `confidence` | `high`, `medium`, `low` (small n or margin within noise) |
| `note` | short comment; for new tests: the criterion |

## `experiments/comparison/report.md`

```markdown
# Comparison of packages

## Packages
| Package | Change vs. P00 | Reference | Area | Reference trees |

## Robust findings
Tests confirmed in every package with data – one bullet each, values per package.

## Setting-dependent findings
Tests whose status changes – which setting changes them and how (values, SE).

## Weak or contradicted findings
`inconclusive` in at least half of the packages; significant opposite sign anywhere.

## Predictions
Each prediction of analysis_plan.md: met / not met, with values.

## Agent vs. automatic disagreements
Rows with agreement = NO and the resolution.

## New observations
N… tests from package reports and whether they recur in other packages.

## Conclusions for the final report
3–5 points.
```
