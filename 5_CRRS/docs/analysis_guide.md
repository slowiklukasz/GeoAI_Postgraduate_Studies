# Analysis guide – handheld scanners vs TLS

For people: how one package is analysed, what each step computes, how to read the results and which tests are evaluated. It summarises the agent documents in docs/. Numerical thresholds are set in docs/analysis_plan.md and scripts/compare_experiments.py. An auxiliary Polish version is in docs/pl/; if they differ, this version applies.

## Rules

- TLS is a relative reference, not ground truth: write "difference from TLS", never "error".
- Every number in a report has a source: an output file or a command in the report appendix.
- Read n first: different n between scanners usually means different trees – check ref_mean and the common-trees table.
- |z| < 2: the bias cannot be told apart from zero at this n. Differences smaller than the SE are not differences.
- Results are kept apart from causes; causes are hypotheses until checked on the point clouds.
- The analysis plan is frozen before P01+; new ideas become new tests N… in the change log.

## Document map

Where things are and when they change.

| File | For | Content | Changes when |
|---|---|---|---|
| README.md | everyone | running, inputs, steps, output files | the code changes |
| CLAUDE.md | Claude Code | rules for working in the repo, document map, agent workflow | the rules change |
| docs/methods.md | agent | what each step computes, config keys, files and columns | the code changes |
| docs/interpretation.md | agent | how to read the results: patterns and pitfalls | a pattern recurs across packages |
| docs/analysis_plan.md | agent and people | tests, decision rules, predictions | after freezing: only new tests N… and the change log |
| docs/analysis_protocol.md | agent | procedure for one package, allowed extra computations | the procedure changes |
| docs/output_schema.md | agent | format of report.md, tests.csv and the comparison report | the format changes |
| docs/experiment_plan.md | people and agent | list of packages, what stays constant, package folder layout | a package is added |
| docs/examples/report_example.md | agent | example report: depth and style (numbers from another run) | – |
| .claude/agents/*.md | Claude Code | instructions of experiment-analyst and experiment-comparer | the procedure changes |
| docs/analysis_guide.md, .xlsx | people | this guide | together with the files above |
| docs/pl/przewodnik_analizy.md, .xlsx | people (Polish) | auxiliary Polish version of this guide | together with this guide |

## Workflow of one package

From data to the comparison report.

| No. | Stage | Who | What to do | Result |
|---|---|---|---|---|
| 1 | Preparation | person | Copy experiments/_template to experiments/<ID>_<name>, fill the experiment block and paths, put the data into data/arbor and data/3dfin. Clip: set region (clip radius − 3 m). | package folder |
| 2 | Run | person or agent | python run.py --config experiments/<package>/config.yaml | outputs/ |
| 3 | Analysis | experiment-analyst agent (one per package, in parallel) | In Claude Code: "Use experiment-analyst for experiments/<package>". The agent follows docs/analysis_protocol.md. | report.md, tests.csv |
| 4 | Review | person | Does every number have a source, are causes marked as hypotheses, do the findings say what a number means? Look at the maps and the stem profile. | comments on the report |
| 5 | Comparison | experiment-comparer agent | After all packages: "Use experiment-comparer". It runs scripts/compare_experiments.py and writes the report. | experiments/comparison/report.md, tests_matrix.csv |
| 6 | Verification | person | Agent vs. automatic disagreements, predictions, "To check" items on the clouds. | decisions for the final report |

## Pipeline steps

What run.py computes (details: docs/methods.md).

| Step | Command | What it computes | Output files | How to read | Pitfall |
|---|---|---|---|---|---|
| 0. Inputs and filters | in every step | Removes statuses in exclude_status (W3), artefacts (root > 1 m above the 1.3 m point) and trees outside the region – the same for the reference and the scanners. 3DFin: 0 = no fit. | – | The number of reference trees after filters is the denominator of detection. | W2 stays: real trees without a DBH. |
| 1. Matching and detection | --step matching | One-to-one matching by XY (Hungarian algorithm, max. 0.5 m); TP, FN, FP, precision, recall, F1; error types. Two runs: Arbor and 3DFin against the same reference. | matching/<arbor\|3dfin>/link_table.csv, detection_summary.csv, match_details.csv, matched_predictions/*.png | Recall: share of reference trees found. Precision: share of detections that are trees. FP duplicate = over-segmentation. | Matching uses XY only – a fragment can take the pair of the full tree. |
| 2. Filter sensitivity | --step sensitivity | Arbor detection repeated for the variants main, no_filter, measured_only. | sensitivity/detection_variants.csv, <variant>/… | Each variant answers a different question (sheet Filters and statuses). | FN in no_filter are fragments in the reference, not missed trees. |
| 3. Measurements (Arbor) | --step accuracy | d = scanner − TLS per pair; n, bias, RMSE, SD, SE, z, % for DBH, H, V and position; controls without outlier pairs and on common trees. | accuracy/arbor/paired_differences.csv, accuracy_summary.csv, accuracy_summary_no_outliers.csv, accuracy_summary_common_trees.csv | RMSE ≈ \|bias\| → systematic shift. \|z\| ≥ 2 → clear bias. | DBH and V only for measured–measured pairs; different n = different trees. |
| 4. Stem profiles (3DFin) | --step stem_profiles | Diameter differences at common heights (sections every 0.2 m); bands 1–3, 6–9 and 1–9 m; reach. | stem_profiles/stem_profile_summary.csv, stem_profile_bands.csv, stem_profile_differences.csv, stem_profile.png | Constant bias or growing with height; reach = how high stems are fitted. | Per cent grows with height just because the stem tapers – look at cm. |
| 5. Comparison of packages | python scripts/compare_experiments.py | Summary tables, automatic test evaluation, agreement with the agent verdicts. | experiments/comparison/*.csv | Robust test = confirmed in every package with data. | A status change is a setting effect only if the packages differ in one factor and the change exceeds the SE. |

## Filter variants and Arbor statuses

Each filter variant answers a different question.

| Variant | Excluded statuses | Role | Question | Pitfall |
|---|---|---|---|---|
| main | W3 allometry | main result (declared in advance) | tree detection | – |
| no_filter | none | sensitivity analysis | over-segmentation – all segments | FN are fragments in the reference |
| measured_only | W3 + W2 | sensitivity analysis | DBH measurability | a drop in recall is a missing DBH, not a missing tree |

Arbor statuses:

| Status | What it is | Used for |
|---|---|---|
| measured | DBH measured | detection, DBH, H, V |
| W2 no valid measure | real tree, DBH not measured (implausibly small) | detection and H; no DBH or V |
| W3 allometry | short segments, mostly stem-base fragments | excluded in the main variant |
| other: Diameter anomaly | unusual diameter | detection and H; no DBH or V |

## Metrics

Glossary – all values are in the output files.

| Metric | Formula | Unit | Meaning | Note |
|---|---|---|---|---|
| TP | matched pair | – | reference tree found |  |
| FN | reference tree without a pair | – | too_far: no tree within 0.5 m; taken: pair taken by a neighbour |  |
| FP | scanner tree without a pair | – | duplicate: ≤ 0.3 m from a matched tree (over-segmentation); extra: stand-alone | check extras in the cloud before calling them false |
| Precision | TP / (TP + FP) | 0–1 | share of detections that are reference trees |  |
| Recall | TP / (TP + FN) | 0–1 | share of reference trees detected |  |
| F1 | 2·P·R / (P + R) | 0–1 | one number combining precision and recall |  |
| d | scanner − TLS | cm, m, m³ | difference per pair; positive = scanner gives more |  |
| n | number of pairs | – | always read first | different n = different trees |
| Bias | mean(d) | as d | systematic shift; sign = direction |  |
| RMSE | √mean(d²) | as d | typical size of the difference, without sign | RMSE ≈ \|bias\|: shift; RMSE ≫ \|bias\|: scatter |
| SD | standard deviation of d | as d | scatter around the bias |  |
| SE | SD / √n | as d | uncertainty of the bias |  |
| z | bias / SE | – | \|z\| ≥ 2: bias clearly different from zero | n < 5: no data; n < 10: low confidence |
| Bias %, RMSE % | value / ref_mean × 100 | % | comparison across parameters |  |
| ref_mean | mean reference value of the same pairs | as parameter | are we comparing the same trees? |  |
| DBH share | n(DBH) / n(H) | 0–1 | DBH measurability (test A4) |  |
| Duplicates per tree | FP_duplicate / reference trees | – | over-segmentation (test D2) |  |
| Outlier pair | \|ΔH\| > 3 m | – | usually the reference matched to a fragment | control: accuracy_summary_no_outliers.csv |
| Band | mean bias over heights in the interval with n ≥ 5 | cm | lower 1–3 m, upper 6–9 m, all 1–9 m |  |
| Reach | highest section with n ≥ 5 | m | how high the stem is fitted |  |

## How to read the results – patterns

General patterns, not results. Extend when a pattern recurs across packages.

| Step | Pattern | What it means | Note / what to check |
|---|---|---|---|
| Detection | recall ≈ 1 for every scanner | detection does not separate the scanners on this plot | large trees dominate the reference |
| Detection | FP mostly duplicate | over-segmentation: a tree cut into several segments | a duplicate can take the pair of the full tree – see outlier pairs |
| Detection | FP mostly extra | understorey, noise or trees missed by TLS | inspect a few in the cloud |
| Detection | FN taken | dense trees: the detection was matched to a neighbour | usually a duplicate in the reference |
| Detection | FN too_far | the scanner (or the tool) did not find the tree | stem visibility in the cloud |
| Detection | large recall drop in measured_only | DBH measurability, not detection | the same tree can be measured in TLS and W2 in HLS |
| Detection | many duplicates in no_filter | stem-base fragments (W3) next to trees | compare between scanners |
| Detection | 3DFin finds extra stems also in TLS | the reference lacks some stems (filters, SegFix) | not a scanner error |
| Measurements | RMSE ≈ \|bias\| | systematic shift | look for the cause in the cloud |
| Measurements | RMSE ≫ \|bias\| | random scatter in both directions | check per-tree differences |
| Measurements | DBH bias > 0 | stem looks thicker: range noise widens the edge |  |
| Measurements | DBH bias < 0 | circle fitted to a partial arc or sparse points | low n(DBH) of the same scanner points the same way |
| Measurements | low n(DBH) / n(H) | DBH rarely measurable for the scanner | a result in itself |
| Measurements | large H RMSE with a small bias | a few outlier pairs (fragment instead of tree) | compare with accuracy_summary_no_outliers.csv |
| Measurements | H bias < 0 on tall trees for all HLS | tree tops not visible from the ground | small effect – needs \|z\| ≥ 2 |
| Measurements | V bias with unbiased DBH | volume model effect | treat V as secondary |
| Measurements | larger stem offset of one scanner | less stable positions (e.g. SLAM drift) | values ≪ 0.5 m do not affect matching |
| Individual trees | two scanners agree with each other, not with TLS | reference or the stem itself is suspect | fork, attached neighbour, one-sided TLS coverage |
| Individual trees | one scanner far off on one tree | segmentation error in that cloud | fragment, cut crown |
| Individual trees | all HLS lower than TLS on the same tree | tree top not visible from the ground |  |
| Stem profiles | constant bias along the stem | systematic effect of the scanner |  |
| Stem profiles | bias growing with height | effect grows with distance from the scanner | look at cm, not only % |
| Stem profiles | larger bias near the ground only | understorey, root flare | often fewer sections near the ground |
| Stem profiles | different reach | how high stems are fitted in the cloud | depends on the n ≥ 5 threshold |
| Stem profiles | sign differs from the Arbor DBH bias | the tools measure the stem differently | tool dependence (test C1) |
| Across packages | test confirmed everywhere | robust finding |  |
| Across packages | 3DFin changes when only Arbor settings change | the 3DFin inputs differ | check the xlsx files |

## Tests (analysis plan)

Criteria from docs/analysis_plan.md; P00 values from the exploratory run (SegFix reference).

| ID | Hypothesis | Criterion | Source file | P00 value | P00 |
|---|---|---|---|---|---|
| I1 | Same coordinate frame (check) | median pair distance < 0.2 m for every dataset | matching/*/link_table.csv | – | check |
| I2 | Complete inputs (check) | 3 HLS in Arbor and 3DFin, TLS in 3DFin | matching/*/detection_summary.csv | – | check |
| I3 | 3DFin TLS linked to the reference (check) | recall ≥ 0.9 | matching/3dfin/detection_summary.csv | – | check |
| D1 | All HLS detect nearly all reference trees | recall ≥ 0.95 for all HLS | matching/arbor/detection_summary.csv | 1.00 / 1.00 / 1.00 | ✓ |
| D2 | LiGrip is the most over-segmented | duplicates per tree: LiGrip highest and ≥ 0.05 | matching/arbor/detection_summary.csv | 0.067 vs 0 / 0 | ✓ |
| A1 | low-cost overestimates DBH | bias > 0, z ≥ 2 | accuracy_summary.csv | +2.24 cm, z = 6.4 | ✓ |
| A2 | LiGrip underestimates DBH | bias < 0, z ≤ −2 | accuracy_summary.csv | −5.93 cm, z = −8.6 | ✓ |
| A3 | GeoSLAM DBH agrees with TLS | \|z\| < 2 | accuracy_summary.csv | −0.31 cm, z = −1.1 | ✓ |
| A4 | LiGrip DBH is hardest to measure | DBH share: LiGrip lowest and < 0.5 | accuracy_summary.csv | 0.30 vs 0.93 / 0.93 | ✓ |
| A5 | Height agrees for GeoSLAM and low-cost | \|z\| < 2 for both | accuracy_summary.csv | z = −0.1 / −0.8 | ✓ |
| A6 | LiGrip height bias comes from outlier pairs | \|bias\| < 0.5 m without outlier pairs | accuracy_summary_no_outliers.csv | −0.23 m | ✓ |
| A7 | LiGrip stem positions shift most | LiGrip highest mean offset | accuracy_summary.csv | 0.11 vs 0.05 / 0.06 m | ✓ |
| S1 | low-cost overestimates diameter, more higher up | 0 < lower band < upper band | stem_profile_bands.csv | +2.61 < +4.92 cm | ✓ |
| S2 | LiGrip underestimates diameter along the stem | lower band < 0 and upper band < 0 | stem_profile_bands.csv | −1.90 / −2.40 cm | ✓ |
| S3 | GeoSLAM profile is closest to TLS | smallest \|bias\| in band 1–9 m | stem_profile_bands.csv | −0.40 vs −2.14 / +3.96 cm | ✓ |
| S4 | Reach GeoSLAM ≥ low-cost ≥ LiGrip | order of reach | stem_profile_bands.csv | 14.5 / 12.3 / 10.7 m | ✓ |
| C1 | Arbor and 3DFin agree on the sign of DBH bias | same sign of Arbor DBH bias and 3DFin bias at 1.3 m (LiGrip, low-cost) | accuracy_summary.csv, stem_profile_summary.csv | −6.2 / −2.0; +2.5 / +2.0 cm | ✓ |

## Statuses, replication and predictions

How a test is judged in one package and across packages.

| Class | Rule |
|---|---|
| robust | confirmed in every package with data |
| setting-dependent | confirmed in some packages, not_confirmed in others, in line with the one factor that differs |
| fragile | inconclusive in at least half of the packages with data |
| contradicted | significant opposite sign (\|z\| ≥ 2) in any package – always reported |

Test status in one package:

| Status | Meaning |
|---|---|
| confirmed | criterion met |
| inconclusive | direction as expected, but \|z\| < 2 |
| not_confirmed | criterion not met |
| no_data | file or scanner missing, or n < 5 |

Predictions (written before P01+):

| Comparison | Factor | Prediction |
|---|---|---|
| P01 vs P00 | clip / region | same statuses; some may become inconclusive (smaller n) |
| P02 vs P01 | Arbor READ_FRACTION 0.2 → 1.0 | A4: DBH share rises, most for LiGrip (≥ +0.10); A2: \|LiGrip DBH bias\| decreases; D2: open question |
| P02 vs P01 | control | 3DFin results (S1–S4, 3DFin part of C1) unchanged |

## Structure of a package report (report.md)

In English, example: docs/examples/report_example.md. Each part: Results → Findings → Possible causes → To check.

| Part | Tables | Source files | Findings – about | Review questions |
|---|---|---|---|---|
| 0 – Setup and data checks | Arbor statuses per file | config.yaml, input files | what changed, reference trees, I1–I3 | Are the data complete and in one frame? |
| 1 – Tree detection | 3 filter variants × scanner; filter – what it measures | sensitivity/detection_variants.csv, match_details.csv, matching/3dfin/detection_summary.csv | detection, over-segmentation, DBH measurability, 3DFin | Does recall separate the scanners? What are the FP? Are FN in no_filter reference fragments? |
| 2 – Tree measurements | n, bias, RMSE, z, %; controls | accuracy_summary.csv, _no_outliers, _common_trees | DBH, height, volume, position | Is the bias systematic? Does it hold on common trees and without outlier pairs? |
| 2b – Selected trees | as Part 2; all → selected | accuracy_summary.csv (tree_subset: selected) | does the picture from all trees hold | Is the change larger than the SE? (F00 only) |
| 2c – Individual trees | cases; statistics without them | paired_differences.csv | which trees drive the statistics and why; candidates for figures | Suspect reference, segmentation error or hidden tree top? |
| 3 – Stem profiles | selected heights; bands and reach; Arbor vs 3DFin | stem_profile_summary.csv, stem_profile_bands.csv, stem_profile.png | pattern of each scanner, reach, agreement of the tools | Constant or growing with height (in cm)? Same sign as Arbor? |
| Tests | ID, status, evidence, confidence | tests.csv | – | Was each criterion applied literally? |
| Limitations, For the report | – | – | reference type, n, XY-only matching; what to use in the final report | Are hypotheses marked as hypotheses? |
