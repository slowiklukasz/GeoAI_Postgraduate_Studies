<!-- Example of the expected depth and style of report.md: P00 exploratory run with the SegFix
     reference, written before Part 0 and the tests existed. Structure: docs/output_schema.md.
     The numbers belong to that run only - never copy them into another report. -->

# Results – HLS vs TLS

Reference: Arbor TLS after SegFix. One-to-one matching by XY, max. 0.5 m. TLS is a relative reference, not ground truth.

## Part 1 – Tree detection (Arbor)

The three status-filter settings answer three different questions:

| Filter | What it measures | Reference trees |
|---|---|---|
| W3 (main) | tree detection | 60 |
| none | detection of all segments → over-segmentation | 77 |
| W3 + W2 | detection of trees with a measured DBH | 60 |

### Results

| Scanner | Filter | TP | FN | FP | FP dupl. | FP extra | Precision | Recall | F1 |
|---|---|---|---|---|---|---|---|---|---|
| GeoSLAM Horizon | W3 | 60 | 0 | 0 | 0 | 0 | 1.000 | 1.000 | 1.000 |
| | none | 69 | 8 | 3 | 0 | 3 | 0.958 | 0.896 | 0.926 |
| | W3 + W2 | 60 | 0 | 0 | 0 | 0 | 1.000 | 1.000 | 1.000 |
| LiGrip | W3 | 60 | 0 | 6 | 4 | 2 | 0.909 | 1.000 | 0.952 |
| | none | 70 | 7 | 42 | 35 | 7 | 0.625 | 0.909 | 0.741 |
| | W3 + W2 | 21 | 39 | 0 | 0 | 0 | 1.000 | 0.350 | 0.519 |
| low-cost | W3 | 60 | 0 | 0 | 0 | 0 | 1.000 | 1.000 | 1.000 |
| | none | 67 | 10 | 11 | 3 | 8 | 0.859 | 0.870 | 0.865 |
| | W3 + W2 | 60 | 0 | 0 | 0 | 0 | 1.000 | 1.000 | 1.000 |

### Findings

**Tree detection (W3 filter)**
- Every scanner detects all 60 reference trees (recall 1.0). Detection alone does not separate the scanners on this plot.
- GeoSLAM and low-cost give a clean 1:1 result. LiGrip has 6 FP, 4 of them duplicates – trees split into two segments even after removing W3.

**Over-segmentation (no filter)**
- Duplicates, i.e. extra segments right next to a matched tree: **LiGrip 35, low-cost 3, GeoSLAM 0**. For LiGrip that is about 0.6 fragments per tree – most stems are cut, mainly at the base (W3 segments).
- Stand-alone extra segments: low-cost 8, LiGrip 7, GeoSLAM 3 – more likely understorey, shrubs or noise clusters than trees.
- The FN (7–10) are not missed trees: the SegFix reference also contains 17 W3 segments (77 instead of 60), and the scanners reproduce only some of them at the same place.
- GeoSLAM is the cleanest: no duplicates and the fewest extra segments.

**DBH measurability (W3 + W2 filter)**
- LiGrip: Arbor fitted DBH for only 21 of 60 trees (35%). The other 39 are W2 – tree detected, but no valid DBH.
- GeoSLAM and low-cost: all 60 trees have a measured DBH.

### Possible causes
- **LiGrip – lower stem poorly captured.** Over-segmentation at the base and missing DBH concern the same zone, so they probably share a cause:
  - noise or "double walls" of the stem (misaligned passes due to SLAM drift) – the stem looks like two surfaces, Arbor splits it into segments and the circle at 1.3 m does not fit,
  - uneven coverage of the lower stems (scanning pattern, occlusion by understorey) – gaps break the continuity of the stem,
  - READ_FRACTION 0.2 thinning deepens both effects if the cloud is already less dense at the stem.
- **low-cost – more stand-alone segments** with almost no duplicates: stems are continuous, but the cloud has more noise and small objects that Arbor separates.
- **GeoSLAM** – continuous, well-captured stems and the least noise.
- Hypotheses to confirm on stem cross-sections (1.3 m) and segment views of the same trees in the four clouds.

### To check
- Stem cross-section at 1.3 m for 2–3 LiGrip W2 trees compared with GeoSLAM and TLS: double walls, noise or gaps?
- A few LiGrip duplicates in CloudCompare: lower stem fragments or a tree split lengthwise?

## Part 2 – Tree measurements (Arbor, W3 filter)

Difference d = scanner − TLS, matched trees only. All 60 matched trees (`selected_trees` list still empty).

### Results

| Scanner | Parameter | n | Bias | RMSE | Bias % | RMSE % |
|---|---|---|---|---|---|---|
| GeoSLAM Horizon | DBH [cm] | 56 | −0.31 | 2.15 | −0.9 | 6.2 |
| | H [m] | 60 | −0.01 | 0.79 | −0.1 | 4.5 |
| | V [m³] | 56 | −0.13 | 0.19 | −10.8 | 15.9 |
| | position [m] | 60 | 0.05 | 0.06 | – | – |
| LiGrip | DBH [cm] | 18 | −5.93 | 6.58 | −14.4 | 15.9 |
| | H [m] | 60 | −0.94 | 3.21 | −5.3 | 18.2 |
| | V [m³] | 18 | −0.56 | 0.60 | −31.5 | 33.7 |
| | position [m] | 60 | 0.11 | 0.13 | – | – |
| low-cost | DBH [cm] | 56 | +2.24 | 3.43 | +6.4 | 9.8 |
| | H [m] | 60 | −0.12 | 1.22 | −0.7 | 6.9 |
| | V [m³] | 56 | +0.14 | 0.19 | +11.9 | 15.7 |
| | position [m] | 60 | 0.06 | 0.08 | – | – |

Controls:

| Scanner | DBH on the 18 trees measured by LiGrip: bias / RMSE [cm] | H without pairs with \|d\| > 3 m: n / bias / RMSE [m] |
|---|---|---|
| GeoSLAM Horizon | −0.05 / 2.89 (n = 17) | 59 / −0.09 / 0.56 |
| LiGrip | −5.93 / 6.58 (n = 18) | 55 / −0.23 / 0.51 |
| low-cost | +1.62 / 3.83 (n = 17) | 58 / −0.25 / 1.04 |

### Findings

**DBH**
- GeoSLAM: practically no shift (bias −0.3 cm, median −0.6 cm), RMSE 2.2 cm (6%).
- low-cost: systematically overestimates by about 2.2 cm (median +2.4 cm, about +7%). The scatter (SD 2.6 cm) is similar to the bias, so a constant shift dominates.
- LiGrip: systematically underestimates by about 6 cm (−14%). SD 2.9 cm with a bias of −5.9 cm, so almost every tree is underestimated, and the difference grows with stem size (correlation with DBH −0.52).
- On the same 18 trees GeoSLAM has a bias of about 0 and low-cost +1.6 cm – the LiGrip underestimation does not come from a different set of trees.

**Height**
- Without a few outlier pairs, height agrees with TLS for all scanners: RMSE 0.5–0.6 m (GeoSLAM, LiGrip) and about 1 m (low-cost), bias from 0 to −0.25 m.
- The high LiGrip RMSE (3.2 m) comes from 3–4 pairs: the reference matched to a W2 fragment about 7 m tall instead of the full tree (differences −12 to −15 m). This is a matching error at duplicates, not a height measurement error.

**Volume**
- Follows DBH: low-cost +12%, LiGrip −31%. GeoSLAM has −11% despite an almost zero DBH bias – Arbor volume is sensitive to the model, so we treat it as secondary.

**Stem position**
- Mean offset: GeoSLAM 5 cm, low-cost 6 cm, LiGrip 11 cm (max. 36 cm). All far below the 0.5 m matching threshold.

### Possible causes
- **low-cost overestimates DBH:** range noise "thickens" the stem and the circle fits the outer edge of the cloud.
- **LiGrip underestimates DBH and measured it for only 18–21 trees:** the stem at 1.3 m is poorly captured – few points or only part of the circumference. A circle fitted to a partial arc or to sparse points comes out too small, and for most trees it cannot be fitted at all. READ_FRACTION 0.2 makes this worse for a sparse cloud.
- **LiGrip – larger stem offset (11 cm)** fits a less stable SLAM trajectory – the same possible cause as the over-segmentation in Part 1.
- **GeoSLAM:** the most consistent stems, results closest to TLS in all parameters.

### To do
- At duplicates, matching should choose the full tree, not the fragment (e.g. the taller candidate within `duplicate_dist`). After this change, recompute H for LiGrip.
- Status `other: Diameter anomaly` (3 trees in the reference, 1–3 in the scanners) – the reason DBH is computed on 56, not 60 pairs. Mention it in the methods.
- After selecting 10 trees, recompute the table for `selected_trees`.

## Part 2b – Measurements for 10 selected trees (Arbor, W3 filter)

The selected trees are larger than the plot average: mean reference DBH 41.2 cm (all trees: 34.9 cm), mean height 21.4 m (all trees: 17.7 m).

### Results

| Scanner | Parameter | n | Bias | RMSE | Bias % | RMSE % |
|---|---|---|---|---|---|---|
| GeoSLAM Horizon | DBH [cm] | 10 | +1.04 | 3.27 | +2.5 | 7.9 |
| | H [m] | 10 | −0.46 | 0.87 | −2.1 | 4.1 |
| | V [m³] | 10 | −0.22 | 0.26 | −12.3 | 14.5 |
| | position [m] | 10 | 0.06 | 0.08 | – | – |
| LiGrip | DBH [cm] | 6 | −6.17 | 7.40 | −14.2 | 17.0 |
| | H [m] | 10 | −2.48 | 4.73 | −11.6 | 22.0 |
| | V [m³] | 6 | −0.70 | 0.72 | −33.8 | 34.8 |
| | position [m] | 10 | 0.12 | 0.13 | – | – |
| low-cost | DBH [cm] | 10 | +2.54 | 4.34 | +6.2 | 10.5 |
| | H [m] | 10 | −0.56 | 1.18 | −2.6 | 5.5 |
| | V [m³] | 10 | +0.17 | 0.22 | +9.8 | 12.4 |
| | position [m] | 10 | 0.07 | 0.11 | – | – |

### Comparison with all trees (bias)

| Scanner | DBH: all → selected [cm] | H: all → selected [m] |
|---|---|---|
| GeoSLAM Horizon | −0.31 → +1.04 | −0.01 → −0.46 |
| LiGrip | −5.93 → −6.17 | −0.94 → −2.48 |
| low-cost | +2.24 → +2.54 | −0.12 → −0.56 |

With n = 10 the standard error of the bias is about SD/√n: for DBH about 1 cm (GeoSLAM, low-cost) and about 1.7 cm (LiGrip, n = 6), for H about 0.25–0.35 m (GeoSLAM, low-cost). Differences smaller than these values are not conclusive.

### Findings
- **The picture from all trees holds:** low-cost overestimates DBH (+2.5 cm, more than two standard errors), LiGrip underestimates it (−6.2 cm), GeoSLAM is closest to TLS. The change of the GeoSLAM bias from −0.3 to +1.0 cm is within the uncertainty for 10 trees.
- **LiGrip measured DBH for only 6 of the 10 selected trees** – the breast-height problem affects large, dominant trees too, not only difficult cases.
- **The height of large trees is slightly underestimated by all handheld scanners** (about −0.5 m for GeoSLAM and low-cost, against a bias of about 0 for all trees). This fits weaker coverage of tall crown tops when scanning from the ground on the move. The effect is at the edge of the uncertainty (about 2 standard errors), so we state it cautiously.
- **LiGrip H (−2.5 m, RMSE 4.7 m) is dominated by single pairs.** With 10 trees, one tree matched to a fragment (a difference of about −12 m) is enough to inflate the RMSE – the same matching problem at duplicates as in Part 2.
- **For the report:** the table for the 10 selected trees as in the scope, and the results for all matched trees as a robustness check (larger n, same picture).

### To do
- In `paired_differences.csv`, check which selected trees give a LiGrip height difference below −5 m. If these are pairs with a W2 fragment, fix matching at duplicates or replace the tree in `selected_trees`.

## Part 2c – Individual trees (10 selected)

### Cases that drive the statistics

| Tree | What happens | Scanner | Difference |
|---|---|---|---|
| 454 | DBH overestimated in two scanners that agree with each other (50.3 and 51.8 cm), while TLS and LiGrip give about 40–41 cm; also the largest stem offset (0.19–0.24 m) | GeoSLAM, low-cost | DBH +9.1 and +10.6 cm |
| 136 | Reference matched to a W2 fragment 6.9 m tall | LiGrip | H −12.0 m |
| 46 | DBH correct (−1.6 cm), but the segment is only 12.8 m tall instead of 21.5 m – the upper crown was assigned elsewhere | LiGrip | H −8.7 m |
| 2, 117 | All three handheld scanners give a lower tree than TLS | all HLS | H from −1.2 to −2.6 m |

### Statistics without these cases

| Scanner | DBH without tree 454: n / bias / RMSE [cm] | H without fragment pairs (46, 136): n / bias / RMSE [m] |
|---|---|---|
| GeoSLAM Horizon | 9 / +0.14 / 1.61 | – |
| LiGrip | – | 8 / −0.52 / 0.76 |
| low-cost | 9 / +1.64 / 2.89 | – |

### Findings
- **Apart from tree 454, GeoSLAM practically agrees with TLS:** DBH bias +0.1 cm, RMSE 1.6 cm. The whole RMSE increase on the selected trees is one tree.
- **low-cost overestimates DBH consistently:** 7 of 9 trees (without 454) have a difference of +2.4 to +3.5 cm. Such an even shift is typical of noise thickening the stem, not of random errors.
- **LiGrip underestimates DBH on all 6 measured trees** (from −1.2 to −11.5 cm), most on the thickest stems (trees 6 and 205, about 47–48 cm in TLS).
- **Tree 454 is suspect on the reference side or in the stem itself:** two independent handheld scanners agree with each other, not with TLS. Possible causes: a fork or an irregular stem at 1.3 m, a neighbouring stem attached to the segment, or one-sided stem coverage in TLS. To inspect – a good figure for the visual part.
- **LiGrip heights are spoiled by two different segmentation errors:** a stem fragment instead of the tree (136) and a tree with its upper crown cut off (46). Without them LiGrip has a height RMSE of 0.76 m, at the level of the other scanners.
- **Height underestimation concerns specific trees, not a scanner:** trees 2 and 117 are lower in all three handheld clouds. Most likely their tops are hidden from below, so ground-based scanning misses them, while TLS on a tripod sees them better.

### Candidates for figures (the same situation in four clouds)
- **454:** stem cross-section at 1.3 m – DBH disagreement between scanners.
- **136 and 46:** Arbor segments – fragment instead of the tree and cut crown in LiGrip.
- **2 or 117:** vertical profile – top visible in TLS, missing in the handheld clouds.
- **205 or 6:** cross-section at 1.3 m – underestimated LiGrip DBH on a thick stem.

## Part 3 – Stem profiles (3DFin, 10 selected trees)

Stem diameter difference d = scanner − TLS (3DFin) in sections every 0.2 m, only sections fitted in both clouds. Heights with fewer than 5 trees are left out of the plot.

### Selected heights (bias [cm] / bias % / n)

| Height | GeoSLAM Horizon | LiGrip | low-cost |
|---|---|---|---|
| 0.3 m | −1.1 / −2.3% / 8 | −1.8 / −3.5% / 6 | +1.1 / +2.2% / 7 |
| 1.3 m | −1.3 / −3.0% / 9 | −2.0 / −4.6% / 9 | +2.0 / +4.6% / 8 |
| 3.1 m | −0.8 / −2.2% / 10 | −2.1 / −5.3% / 10 | +3.2 / +8.1% / 10 |
| 5.1 m | 0.0 / 0.0% / 10 | −2.1 / −6.0% / 9 | +3.9 / +11.2% / 9 |
| 8.1 m | +0.4 / +1.2% / 10 | −2.0 / −6.0% / 9 | +5.8 / +17.8% / 9 |
| 10.1 m | −0.3 / −0.9% / 9 | −3.7 / −11.8% / 4 | +5.6 / +17.9% / 9 |
| 12.1 m | +0.1 / +0.2% / 9 | – (n < 5) | +6.4 / +21.9% / 5 |

Highest height with at least 5 compared trees: GeoSLAM about 14.5 m, low-cost about 12.3 m, LiGrip about 9.7 m.

### Findings
- **Each scanner has a different, clear pattern, and RMSE is almost equal to |bias|** – the differences are systematic, not random.
- **GeoSLAM is closest to TLS along the whole stem:** a slight underestimation of about −1 to −1.5 cm (−2 to −3%) up to about 3 m, bias around zero above about 4.5 m. RMSE usually 0.5–1.5 cm.
- **LiGrip underestimates the diameter by a constant ~2 cm over the whole height** (0.3–8 m). In per cent the difference grows with height (−4% → −6 to −9%) because the stem tapers. Above about 8.5 m stems are no longer fitted (n drops to 1–4).
- **low-cost overestimates the diameter more and more with height:** from about +1 cm near the ground, through +2 cm at 1.3 m and +4 cm at 5 m, to +6–7 cm at 9–12 m (about +20%). The increase is also in absolute terms, so it is not just constant noise on a tapering stem.
- **The upward reach of the stem also separates the scanners:** GeoSLAM up to about 14 m, low-cost up to about 12 m, LiGrip up to about 9–10 m.
- **The expected "U" shape (larger differences near the ground and near the crown) was not confirmed.** The understorey zone (0.3–2 m) does not stand out; scanner-specific effects dominate. Near the ground (0.3–0.7 m) there are only fewer fitted stems (n 6–8 instead of 10) in all clouds.

### Arbor vs 3DFin at breast height (10 trees, DBH bias)

| Scanner | Arbor | 3DFin (1.3 m) |
|---|---|---|
| GeoSLAM Horizon | +1.0 cm (n = 10) | −1.3 cm (n = 9) |
| LiGrip | −6.2 cm (n = 6) | −2.0 cm (n = 9) |
| low-cost | +2.5 cm (n = 10) | +2.0 cm (n = 8) |

- The direction agrees for LiGrip (underestimation) and low-cost (overestimation); for GeoSLAM both tools give values close to zero, and the Arbor difference comes mainly from tree 454.
- **3DFin handles the LiGrip cloud better than Arbor:** it fits breast height on 9 of 10 trees (Arbor on 6) and underestimates it by about 2 cm instead of about 6 cm. A large part of the LiGrip problem in Arbor is therefore how Arbor measures DBH, not only cloud quality.

### Possible causes
- **low-cost – increase with height:** higher up the stem the scanner is farther from the surface and the beam hits it at a sharper angle. A larger beam footprint and larger range noise blur the stem edge outwards, so the fitted circle grows. Fewer points higher up weaken the fit further.
- **LiGrip – constant underestimation:** the stem is covered unevenly or only on part of its circumference. A circle fitted to a partial arc comes out smaller. No fits above about 9 m point to weak coverage of the upper stem.
- **GeoSLAM:** even coverage around the stem and up to a large height, low noise.

### For the report
- The profile plot is the strongest quantitative figure: three different patterns (constant underestimation, growing overestimation, agreement) are visible at once.
- In the discussion: the Arbor vs 3DFin comparison for LiGrip shows that the result depends not only on the scanner but also on the tool – in line with extension 2 of the scope.
