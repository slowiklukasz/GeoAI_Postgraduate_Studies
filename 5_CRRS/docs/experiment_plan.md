# Experiment plan

Goal: check which findings about the scanners are robust to processing choices, and which
depend on them. Each package changes **one factor** against `P00_baseline`.

## Packages

| ID | Name | What changes vs. baseline | Reference | Status |
|---|---|---|---|---|
| P00 | baseline | – (full plot, Arbor READ_FRACTION 0.2) | TLS raw Arbor, same settings | planned |
| P01 | clip_rf02 | clipped plot (radius r), READ_FRACTION 0.2 | TLS raw Arbor, same clip and settings | planned |
| P02 | clip_rf10 | clipped plot (radius r), READ_FRACTION 1.0 | TLS raw Arbor, same clip and settings | planned |
| P03 | … | one Arbor segmentation parameter | TLS raw Arbor, same settings | optional |
| F00 | final | final settings | TLS corrected in SegFix | last |

P01 vs. P02 isolates the effect of READ_FRACTION (same area, only the read fraction differs).
P00 vs. P01 shows the effect of the clip / plot size.

Fill the `experiment` block of each package config with the real values (radius, centre,
read fraction, Arbor parameters) – it is the only record of how the inputs were produced.

## What stays constant
- Matching, filters and accuracy settings (`arbor`, `matching`, `accuracy`, `stem_profiles`
  sections of the config) – copy them from the template, do not tune them per package.
- 3DFin settings, unless the package is explicitly about 3DFin.
- Dataset file names (see below).

## Reference
- Packages P00–P0x use the **raw Arbor result of TLS processed with the same settings** as the
  HLS clouds of that package. Findings are then compared across packages as trends.
- Only the final package (F00) uses the TLS corrected in SegFix.
- Reference tree IDs differ between packages – never compare tree IDs across packages.
  Per-tree analyses (`selected_trees`) are used only in F00; packages use `tree_subset: all`.

## Clipped packages
- Clip all four clouds with the same centre and radius before Arbor / 3DFin.
- Set `region` in the config to the same centre with a radius about 3 m smaller than the clip:
  trees cut by the clip edge (partial crowns, unstable segments) are then ignored everywhere.

## Package folder

```
experiments/P01_clip_rf02/
├── config.yaml            copy of experiments/_template/config.yaml, edited
├── data/
│   ├── arbor/             tree_list_TLS.csv, tree_list_HLS_GeoSLAM.csv, tree_list_HLS_LiGrip.csv,
│   │                      tree_list_HLS_low_cost.csv
│   └── 3dfin/             TLS.xlsx, HLS_GeoSLAM.xlsx, HLS_LiGrip.xlsx, HLS_low_cost.xlsx
├── outputs/               written by run.py
├── report.md              written by the experiment-analyst agent
└── tests.csv              written by the experiment-analyst agent
```

File names: the scanner must be recognisable from the name (`GeoSLAM`, `LiGrip`, `low_cost`);
the comparison script maps names containing `geoslam`/`geomslam`, `ligrip`, `low_cost`/`lowcost`.
