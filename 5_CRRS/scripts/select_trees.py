"""Helper: propose trees for the per-tree analysis.

python select_trees.py --config configs/config.yaml [--n 10] [--min-height-quantile 0.5]

Run the matching step first – the script reads its link tables.

Candidates are reference trees that
  - have status "measured" in the reference (valid DBH),
  - are matched to a 3DFin stem in the profile reference cloud with a fitted DBH,
  - are at least as tall as the given height quantile of the reference (dominant / co-dominant).
Candidates are then sorted by a stem visibility index and split into n equal groups;
the tallest tree of each group is selected, so the selection covers the whole range
from occluded to well-visible stems.

Stem visibility index: mean 3DFin sector occupancy (sheet "Q2(Sector Occupancy)", 0–1)
of the sections between 0.3 and 2.5 m, averaged over all 3DFin clouds in which the tree
is matched. Sections without a fit count as 0.

Not checked automatically: whether the tree needed a correction in SegFix – review the
proposed trees visually before copying them into the config.
"""

from __future__ import annotations

import argparse
import logging
from pathlib import Path

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt
import numpy as np
import pandas as pd

from pcbench.config import load_config
from pcbench.loaders import dataset_name, load_3dfin_plot_metrics, load_arbor_tree_list
from pcbench.pipeline import load_link_table

OCCUPANCY_SHEET = "Q2(Sector Occupancy)"
LOWER_STEM = (0.3, 2.5)  # [m] section heights used for the visibility index

logger = logging.getLogger("select_trees")


def lower_stem_visibility(path: Path) -> pd.Series:
    """Mean sector occupancy of the lower stem sections per 3DFin tree (index: tree label)."""
    sections = pd.read_excel(path, sheet_name="Sections", header=None)
    heights = pd.Series(sections.iloc[2].astype(float).round(2).to_numpy(),
                        index=sections.iloc[1].astype(str))
    occupancy = pd.read_excel(path, sheet_name=OCCUPANCY_SHEET, header=1).iloc[:, 1:]
    occupancy = occupancy.rename(columns={occupancy.columns[0]: "id"}).dropna(subset=["id"])
    lower = heights[(heights >= LOWER_STEM[0]) & (heights <= LOWER_STEM[1])].index
    values = occupancy.set_index(occupancy["id"].astype(str))[list(lower)].fillna(0)
    return values.mean(axis=1)


def main() -> None:
    parser = argparse.ArgumentParser(description="Propose trees for the per-tree analysis.")
    parser.add_argument("--config", required=True, help="path to the YAML config")
    parser.add_argument("--n", type=int, default=10, help="number of trees to select")
    parser.add_argument("--min-height-quantile", type=float, default=0.5,
                        help="minimum reference height as a quantile of all reference trees")
    args = parser.parse_args()
    logging.basicConfig(level=logging.INFO, format="%(levelname)s  %(message)s")

    config = load_config(args.config)
    out_dir = config.output_dir / "tree_selection"
    out_dir.mkdir(parents=True, exist_ok=True)

    reference_df = load_arbor_tree_list(config.reference_csv, config.exclude_status,
                                        config.max_root_above_bh)
    reference_df["id"] = reference_df["id"].astype(str)
    link_3dfin = load_link_table(config.output_dir / "matching" / "3dfin" / "link_table.csv")
    link_arbor = load_link_table(config.output_dir / "matching" / "arbor" / "link_table.csv")

    # Stem visibility per reference tree, averaged over all matched 3DFin clouds.
    xlsx_paths = {dataset_name(p): p for p in sorted(config.threedfin_xlsx_dir.glob("*.xlsx"))
                  if not p.name.startswith("~$")}
    visibility = pd.DataFrame({"ref_id": link_3dfin["ref_id"].astype(str)})
    for name, path in xlsx_paths.items():
        tree_ids = link_3dfin[f"{name}_id"].astype("string")
        visibility[f"visibility_{name}"] = tree_ids.map(lower_stem_visibility(path)).astype(float)
    visibility_columns = [c for c in visibility.columns if c.startswith("visibility_")]
    visibility["visibility"] = visibility[visibility_columns].mean(axis=1)

    # 3DFin DBH in the profile reference cloud (stem must be fitted).
    profile_path = xlsx_paths[config.profile_reference]
    profile_dbh = load_3dfin_plot_metrics(profile_path).assign(id=lambda d: d["id"].astype(str))
    profile_column = f"{config.profile_reference}_id"
    visibility["profile_dbh"] = (link_3dfin[profile_column].astype("string")
                                 .map(profile_dbh.set_index("id")["dbh"]).astype(float))

    # Which Arbor scanners detected the tree (information only, not a criterion).
    detected = link_arbor.filter(like="_id").drop(columns="ref_id").notna()
    detected.columns = [f"detected_{c.removesuffix('_id')}" for c in detected.columns]
    detected["ref_id"] = link_arbor["ref_id"].astype(str)

    min_height = reference_df["h"].quantile(args.min_height_quantile)
    trees_df = (reference_df.rename(columns={"id": "ref_id"})
                .merge(visibility, on="ref_id", how="left")
                .merge(detected, on="ref_id", how="left"))
    trees_df["candidate"] = ((trees_df["status"] == "measured")
                             & trees_df["profile_dbh"].notna()
                             & (trees_df["h"] >= min_height)
                             & trees_df["visibility"].notna())
    candidates = trees_df[trees_df["candidate"]].sort_values("visibility")
    logger.info("Reference trees: %d, candidates: %d (H >= %.1f m)",
                len(trees_df), len(candidates), min_height)
    if len(candidates) < args.n:
        raise SystemExit(f"Only {len(candidates)} candidates – lower --min-height-quantile.")

    # One tree per visibility group: the tallest one.
    groups = np.array_split(np.arange(len(candidates)), args.n)
    selected = pd.concat([candidates.iloc[g].nlargest(1, "h") for g in groups])
    trees_df["selected"] = trees_df["ref_id"].isin(selected["ref_id"])

    trees_df.to_csv(out_dir / "tree_candidates.csv", index=False)
    selected.to_csv(out_dir / "selected_trees.csv", index=False)

    fig, ax = plt.subplots(figsize=(7, 7), facecolor="white")
    ax.scatter(trees_df["x"], trees_df["y"], s=40, color="#0b0b0b",
               label=f"reference trees ({len(trees_df)})")
    ax.scatter(selected["x"], selected["y"], s=120, color="#e34948", edgecolors="white",
               linewidths=1.2, label=f"selected trees ({len(selected)})", zorder=3)
    for _, tree in selected.iterrows():
        ax.annotate(tree["ref_id"], (tree["x"], tree["y"]), xytext=(7, 7),
                    textcoords="offset points", fontsize=8, color="#e34948")
    ax.set_aspect("equal")
    ax.set_xlabel("X [m]")
    ax.set_ylabel("Y [m]")
    ax.set_title(f"Selected trees – reference: {config.reference_name}", loc="left")
    ax.legend(loc="upper left", bbox_to_anchor=(0, -0.08), ncol=2, frameon=False)
    ax.grid(color="#e4e3df", linewidth=0.6)
    fig.tight_layout()
    fig.savefig(out_dir / "selected_trees_map.png", dpi=200, bbox_inches="tight")

    selected = selected.assign(dbh_cm=selected["dbh"] * 100)
    columns = ["ref_id", "h", "dbh_cm", "visibility", *detected.columns.drop("ref_id")]
    print(selected[columns].round(2).to_string(index=False))
    print(f"\nselected_trees: [{', '.join(selected['ref_id'])}]")


if __name__ == "__main__":
    main()
