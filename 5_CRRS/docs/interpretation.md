# Interpretation guide – how to read the outputs

General patterns, not results. For each pattern: what it means, what can mislead, what to check
on the point clouds. Grows with experience – add patterns that recur across packages.

## General
- The reference is TLS (raw Arbor or SegFix-corrected), not ground truth: write "difference from
  TLS", never "error". A test tree that disagrees with TLS can be the better one (occlusion in TLS).
- Always read `n` first. Different `n` between scanners usually means different trees – compare
  `ref_mean` and use the common-trees table before ranking scanners.
- |z| < 2: the bias cannot be told apart from zero at this n. Differences between scanners smaller
  than their SEs are not differences.

## 1. Detection
| Pattern | Reading | Watch out |
|---|---|---|
| recall ≈ 1 for every scanner | detection does not separate the scanners in this plot | large trees dominate the reference |
| FP mostly `duplicate` | over-segmentation: one tree cut into several segments | a duplicate can take the pair instead of the full tree – see step 2 outliers |
| FP mostly `extra` | detections absent from the reference: understorey, noise or trees missed by TLS | check a few in the cloud before calling them false |
| FN `taken` | dense trees: the nearby detection was matched to a neighbour | usually a duplicate in the reference |
| FN `too_far` | the scanner (or the tool on its cloud) did not find the tree | check stem visibility in the cloud |
| recall drops a lot in `measured_only` | DBH could not be fitted for many trees – DBH measurability, not detection | the same tree can be `measured` in TLS and W2 in HLS |
| many `duplicate` in `no_filter` | stem-base fragments (W3) next to trees | compare per scanner; reference fragments become FN in this variant |
| 3DFin finds extra stems also in TLS | the reference lacks some stems (filters, SegFix) – not a scanner error | |

## 2. Measurement agreement
| Pattern | Reading | Watch out |
|---|---|---|
| RMSE ≈ \|bias\| | systematic shift (scanner consistently over/under) | can be corrected; look for a cause in the cloud |
| RMSE ≫ \|bias\| | random scatter in both directions | check per-tree differences |
| DBH bias > 0 | stem looks thicker: range noise widens the stem edge | |
| DBH bias < 0 | circle fitted to a partial arc or sparse points | low DBH n for the same scanner points the same way |
| low n(DBH) / n(H) | DBH rarely measurable for this scanner | itself a result – report it |
| large H RMSE with small bias | a few outlier pairs (fragment matched instead of tree) | compare with `accuracy_summary_no_outliers.csv` |
| H bias < 0 on tall trees for all HLS | tree tops not captured from the ground | small effect – needs \|z\| ≥ 2 |
| V follows DBH | volume grows roughly with DBH² | V bias with unbiased DBH = volume model effect; treat V as secondary |
| xy_offset larger for one scanner | less stable positions (e.g. SLAM drift) | all values far below max_dist = matching unaffected |

Per-tree cases (from `paired_differences.csv`):
- Two scanners agree with each other but not with TLS → suspect the reference tree or the stem
  itself (fork, neighbour attached, one-sided TLS coverage).
- One scanner far off on one tree → segmentation error on that cloud (fragment, cut crown).
- All scanners lower than TLS on the same tree → visibility of that tree top from the ground.

## 3. Stem profiles
| Pattern | Reading | Watch out |
|---|---|---|
| constant bias along the stem | systematic effect of the scanner (noise or partial coverage) | |
| bias growing with height | effect grows with distance from the scanner (beam footprint, sparser points) | per cent grows anyway because the stem tapers – compare absolute values |
| larger bias near the ground only | understorey / root flare | needs n near the ground; often fewer fitted sections there |
| reach differs between scanners | how high stems are fitted in that cloud | reach depends on n ≥ min_pairs |
| sign differs from Arbor DBH bias | the tools measure the stem differently | report as tool dependence (C1) |

## 4. Across packages
- A finding is robust only if it holds in every package with data. A status change is a setting
  effect only if the packages differ in that one setting and the values change beyond their SEs.
- 3DFin results must not change when only Arbor settings change – if they do, the inputs differ.
