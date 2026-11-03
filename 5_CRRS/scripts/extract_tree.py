"""Extract the same trees from several instance-segmented LAZ clouds and plot their side views.

Which trees: reference tree IDs from --ref-ids or from `selected_trees` in --config.
Where they are (two modes):
    --ref-csv tree_list.csv   positions (X_bh, Y_bh) from the Arbor reference tree list; every cloud,
                              including TLS, is matched by position. With --config, `reference.csv`
                              from the config is used when --ref-csv is not given.
    --reference TLS           the IDs are treeIDs in this cloud; the other clouds are matched to it.
Matching: the tree whose stem (mean XY of points 1.0-1.6 m above ground) is closest, within --max-dist.

python scripts/extract_tree.py --clouds-dir data/clouds \
    --ref-csv tree_list_TLS_SegFix.csv --ref-ids 2 61 13 --out-dir extracted_trees

    --clouds NAME=path.laz    clouds given one by one instead of --clouds-dir
    --clouds-dir DIR          LAZ/LAS files found by scanner name in the file name
                              (tls/trimble, geoslam, ligrip, low_cost/lowcost)
    --id-field treeID         instance field (default: treeID, auto-detected if empty)
    --max-dist 0.5            max stem distance for matching [m]
    --plots-only              no LAZ files; one board per tree (all directions) directly in --out-dir
    --all-trees               every tree of the reference tree list instead of --ref-ids / selected_trees
    --exclude-status ...      statuses skipped with --all-trees (default: "W3 allometry"; none: --exclude-status)

Each cloud is read once. Outputs in --out-dir:
    with --plots-only:  tree_<ID>_views.png, overview_000.png, extracted_trees.csv (one folder, no LAZ)
    otherwise:
    tree_<ID>/<cloud>_tree<id>.laz          one LAZ per cloud with the extracted tree
    tree_<ID>/profile_000.png ... 270.png    1x4 side views, rotated by 90 degrees
    tree_<ID>/profiles_all.png               all four directions
    overview_000.png                         all trees (columns) x clouds (rows), one direction
    extracted_trees.csv                      matched IDs, stem distance, points, height
Needs: pip install "laspy[lazrs]" numpy pandas matplotlib pyyaml
"""

from __future__ import annotations

import argparse
from pathlib import Path

import laspy
import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt
import numpy as np
import pandas as pd
import yaml

STEM_BAND = (1.0, 1.6)        # height above ground used for the stem position [m]
MAX_PLOT_POINTS = 150_000     # random subsample per panel to keep plotting fast
ANGLES = [0, 90, 180, 270]    # viewing directions of the side views [deg]
OVERVIEW_TREES = 10           # trees per overview figure
COLORS = {"TLS": "#3d3d3a", "GeoSLAM": "#2a78d6", "LiGrip": "#eb6834", "low-cost": "#1baf7a"}
SCANNER_KEYS = {"TLS": ["tls", "trimble"], "GeoSLAM": ["geoslam"], "LiGrip": ["ligrip"],
                "low-cost": ["low_cost", "lowcost", "low-cost"]}
ID_CANDIDATES = ["treeID", "treeid", "tree_id", "instance", "PredInstance", "point_source_id", "user_data"]


def parse_pairs(items: list[str]) -> dict[str, Path]:
    """Turn ['A=a.laz', 'B=b.laz'] into {'A': Path('a.laz'), 'B': Path('b.laz')}."""
    pairs = {}
    for item in items:
        name, _, value = item.partition("=")
        if not value:
            raise SystemExit(f"Expected NAME=PATH, got: {item}")
        pairs[name] = Path(value)
    return pairs


def find_clouds(folder: Path) -> dict[str, Path]:
    """One LAZ/LAS file per scanner, recognised by the scanner name in the file name."""
    files = sorted(p for p in folder.iterdir() if p.suffix.lower() in (".laz", ".las"))
    clouds = {}
    for name, keys in SCANNER_KEYS.items():
        hits = [p for p in files if any(key in p.name.lower() for key in keys)]
        if len(hits) > 1:
            raise SystemExit(f"Several files for {name}: {[h.name for h in hits]} - use --clouds")
        if hits:
            clouds[name] = hits[0]
    if not clouds:
        raise SystemExit(f"No LAZ/LAS file with a scanner name in {folder}")
    for name, path in clouds.items():
        print(f"{name:9s} <- {path.name}")
    return clouds


def read_config(config_path: Path) -> dict:
    with open(config_path, encoding="utf-8") as file:
        return yaml.safe_load(file) or {}


def read_all_tree_ids(csv_path: Path, exclude_status: list[str]) -> list[int]:
    """All treeIDs of the reference tree list, without the excluded statuses."""
    table = pd.read_csv(csv_path, sep=None, engine="python")
    if exclude_status and "status" in table.columns:
        table = table[~table["status"].isin(exclude_status)]
    return [int(tree_id) for tree_id in table["treeID"]]


def read_reference_positions(csv_path: Path, ref_ids: list[int]) -> dict[int, np.ndarray]:
    """Stem position of each reference tree from the Arbor tree list (X_bh, Y_bh; root if missing)."""
    table = pd.read_csv(csv_path, sep=None, engine="python")
    x_col, y_col = ("X_bh", "Y_bh") if {"X_bh", "Y_bh"} <= set(table.columns) else ("X_root", "Y_root")
    table = table.set_index("treeID")
    positions = {}
    for ref_id in ref_ids:
        if ref_id in table.index:
            positions[ref_id] = table.loc[ref_id, [x_col, y_col]].to_numpy(dtype=float)
        else:
            print(f"Reference tree {ref_id} not found in {csv_path.name}")
    print(f"Reference positions from {csv_path.name} ({x_col}, {y_col}): {len(positions)} trees")
    return positions


def valid_ids(values: np.ndarray) -> np.ndarray:
    """Mask of points that belong to a tree (negative values and 0 mean 'no tree')."""
    return values > 0


def pick_id_field(las: laspy.LasData, preferred: str, name: str) -> str:
    """Use the preferred field if it holds several tree IDs, otherwise the best integer candidate."""
    dims = list(las.point_format.dimension_names)
    candidates = [preferred] + [d for d in ID_CANDIDATES if d != preferred]
    counts = {}
    for dim in candidates:
        if dim not in dims:
            continue
        values = np.asarray(las[dim])
        if not np.issubdtype(values.dtype, np.integer) and not np.all(np.mod(values, 1) == 0):
            continue
        counts[dim] = len(np.unique(values[valid_ids(values)]))
    print(f"[{name}] tree IDs per field: {counts or 'none found'}")
    if counts.get(preferred, 0) > 1:
        return preferred
    best = max(counts, key=lambda dim: counts[dim], default=None)
    if best is None or counts[best] < 2:
        raise SystemExit(f"[{name}] no instance field found. Fields: {dims}")
    print(f"[{name}] '{preferred}' holds no tree IDs, using '{best}' instead")
    return best


def height_above_ground(las: laspy.LasData, ids: np.ndarray) -> np.ndarray:
    """'hag' if the cloud has it, otherwise z minus the lowest point of the same tree."""
    if "hag" in las.point_format.dimension_names:
        return np.asarray(las["hag"], dtype=float)
    trees = valid_ids(ids)
    h = np.full(len(ids), np.nan)
    z = np.asarray(las.z, dtype=float)[trees]
    h[trees] = z - pd.Series(z).groupby(ids[trees]).transform("min").to_numpy()
    return h


def stem_positions(x: np.ndarray, y: np.ndarray, h: np.ndarray, ids: np.ndarray) -> pd.DataFrame:
    """Mean XY of each tree's points in the stem band; index = tree ID."""
    band = (h >= STEM_BAND[0]) & (h <= STEM_BAND[1]) & valid_ids(ids)
    frame = pd.DataFrame({"id": ids[band], "x": x[band], "y": y[band]})
    return frame.groupby("id")[["x", "y"]].mean()


def main() -> None:
    parser = argparse.ArgumentParser(description="Extract the same trees from several LAZ clouds.")
    clouds_arg = parser.add_mutually_exclusive_group(required=True)
    clouds_arg.add_argument("--clouds", nargs="+", help="NAME=path.laz, one per scanner")
    clouds_arg.add_argument("--clouds-dir", type=Path, help="folder with one LAZ/LAS per scanner")
    parser.add_argument("--ref-ids", nargs="+", type=int, help="reference tree IDs (default: selected_trees)")
    parser.add_argument("--config", type=Path, help="config with selected_trees and reference.csv")
    parser.add_argument("--ref-csv", type=Path, help="Arbor tree list of the reference (positions)")
    parser.add_argument("--reference", help="cloud whose treeIDs are the reference IDs (without --ref-csv)")
    parser.add_argument("--id-field", default="treeID")
    parser.add_argument("--max-dist", type=float, default=0.5)
    parser.add_argument("--out-dir", type=Path, required=True)
    parser.add_argument("--all-trees", action="store_true", help="every tree of the reference tree list")
    parser.add_argument("--exclude-status", nargs="*", default=["W3 allometry"],
                        help="statuses skipped with --all-trees")
    parser.add_argument("--plots-only", action="store_true",
                        help="no LAZ; one board per tree with all view directions, all in --out-dir")
    args = parser.parse_args()

    clouds = find_clouds(args.clouds_dir) if args.clouds_dir else parse_pairs(args.clouds)
    config = read_config(args.config) if args.config else {}
    ref_csv = args.ref_csv or (Path(config["reference"]["csv"]) if config.get("reference") else None)
    if args.all_trees:
        if ref_csv is None:
            raise SystemExit("--all-trees needs the reference tree list (--ref-csv or --config)")
        ref_ids = read_all_tree_ids(ref_csv, args.exclude_status)
    else:
        ref_ids = args.ref_ids or [int(i) for i in config.get("selected_trees") or []]
    if not ref_ids:
        raise SystemExit("No trees: give --ref-ids, --all-trees or a --config with selected_trees")
    print(f"Reference trees ({len(ref_ids)}): {ref_ids}")

    names = list(clouds)
    ref_stems: dict[int, np.ndarray] = {}
    if ref_csv is not None:  # position mode: every cloud is matched to the tree list positions
        ref_stems = read_reference_positions(ref_csv, ref_ids)
        id_reference = None
        order = names
    else:  # ID mode: the IDs are treeIDs in the reference cloud
        if args.reference not in clouds:
            raise SystemExit("Give --ref-csv (or --config with reference.csv), or --reference with a cloud name")
        id_reference = args.reference
        order = [id_reference] + [name for name in names if name != id_reference]
    trees: dict[int, dict] = {ref_id: {} for ref_id in ref_ids}
    rows = [{"ref_id": ref_id, "status": "not in reference tree list"}
            for ref_id in ref_ids if id_reference is None and ref_id not in ref_stems]

    # one cloud at a time, reference first: its stems define where to look in the other clouds
    for name in order:
        path = clouds[name]
        print(f"[{name}] reading {path}")
        las = laspy.read(path)
        field = pick_id_field(las, args.id_field, name)
        ids = np.asarray(las[field]).astype(np.int64)
        x, y = np.asarray(las.x, dtype=float), np.asarray(las.y, dtype=float)
        h = height_above_ground(las, ids)
        stems = stem_positions(x, y, h, ids)
        used: dict[int, int] = {}

        for ref_id in ref_ids:
            row = {"ref_id": ref_id, "cloud": name, "id_field": field}
            if name == id_reference:
                if ref_id not in stems.index:
                    print(f"[{name}] reference tree {ref_id} not found in field '{field}'")
                    rows.append({**row, "status": "reference tree not found"})
                    continue
                tree_id = ref_id
                ref_stems[ref_id] = stems.loc[ref_id].to_numpy()
            else:
                if ref_id not in ref_stems:
                    continue
                ref_xy = ref_stems[ref_id]
                dist = np.hypot(stems["x"] - ref_xy[0], stems["y"] - ref_xy[1])
                if dist.empty or dist.min() > args.max_dist:
                    print(f"[{name}] tree {ref_id}: no stem within {args.max_dist} m")
                    rows.append({**row, "status": f"no stem within {args.max_dist} m"})
                    continue
                tree_id = int(dist.idxmin())
            if tree_id in used:
                print(f"[{name}] warning: tree {tree_id} matched to reference {used[tree_id]} and {ref_id}")
            used[tree_id] = ref_id

            stem = stems.loc[tree_id].to_numpy()
            mask = ids == tree_id
            if not args.plots_only:
                tree_dir = args.out_dir / f"tree_{ref_id}"
                tree_dir.mkdir(parents=True, exist_ok=True)
                out = laspy.LasData(las.header)
                out.points = las.points[mask].copy()
                out.write(tree_dir / f"{name}_tree{tree_id}.laz")

            trees[ref_id][name] = {"id": tree_id, "x": x[mask], "y": y[mask], "h": h[mask]}
            rows.append({**row, "status": "ok", "tree_id": tree_id,
                         "stem_x": stem[0], "stem_y": stem[1],
                         "dist_to_ref_m": float(np.hypot(*(stem - ref_stems[ref_id]))),
                         "n_points": int(mask.sum()), "height_m": float(np.nanmax(h[mask]))})
            print(f"[{name}] tree {ref_id} -> {tree_id}: {mask.sum():,} points")
        del las, ids, x, y, h  # free memory before the next cloud

    args.out_dir.mkdir(parents=True, exist_ok=True)
    summary = pd.DataFrame(rows)
    for column in ("tree_id", "n_points"):  # integers, empty where a tree was not found
        if column in summary:
            summary[column] = summary[column].astype("Int64")
    summary.to_csv(args.out_dir / "extracted_trees.csv", index=False)
    print(summary.to_string(index=False))

    found = [ref_id for ref_id in ref_ids if ref_id in ref_stems]
    for ref_id in found:
        if args.plots_only:
            board, angle_dir = args.out_dir / f"tree_{ref_id}_views.png", None
        else:
            angle_dir = args.out_dir / f"tree_{ref_id}"
            board = angle_dir / "profiles_all.png"
        plot_profiles(trees[ref_id], ref_stems[ref_id], names, f"Tree {ref_id}", board, angle_dir)
    chunks = [found[i:i + OVERVIEW_TREES] for i in range(0, len(found), OVERVIEW_TREES)]
    for number, chunk in enumerate(chunks, start=1):  # at most OVERVIEW_TREES trees per overview
        suffix = "" if len(chunks) == 1 else f"_{number}"
        plot_overview(trees, ref_stems, chunk, names, args.out_dir / f"overview_000{suffix}.png")
    print(f"Saved trees and plots to {args.out_dir}")


def tree_extent(tree: dict, center: np.ndarray) -> tuple[float, float]:
    """Largest horizontal distance from the stem and the highest point of one extracted tree."""
    reach = float(np.hypot(tree["x"] - center[0], tree["y"] - center[1]).max())
    return reach, float(np.nanmax(tree["h"]))


def draw_tree(ax, tree: dict | None, name: str, center: np.ndarray, angle: int,
              reach: float, top: float, rng: np.random.Generator) -> None:
    """Side view of one tree, viewed from the given direction; empty panel if not found."""
    ax.set_xlim(-reach, reach)
    ax.set_ylim(0, top * 1.02)
    ax.set_aspect("equal")
    ax.tick_params(labelsize=7)
    if tree is None:
        ax.set_title(f"{name} (not found)", fontsize=9)
        return
    theta = np.radians(angle)
    u = (tree["x"] - center[0]) * np.cos(theta) + (tree["y"] - center[1]) * np.sin(theta)
    keep = rng.permutation(len(u))[:MAX_PLOT_POINTS]
    ax.scatter(u[keep], tree["h"][keep], s=0.05, color=COLORS.get(name, "black"),
               alpha=0.6, linewidths=0, rasterized=True)
    ax.set_title(f"{name} (ID {tree['id']})", fontsize=9)


def plot_profiles(clouds: dict, center: np.ndarray, names: list[str], title: str,
                  board_path: Path, angle_dir: Path | None) -> None:
    """Side views of one tree, same scale in all panels.

    board_path: all directions (rows) x clouds (columns); angle_dir: also one 1x4 file per direction.
    """
    rng = np.random.default_rng(0)
    extents = [tree_extent(tree, center) for tree in clouds.values()]
    reach, top = max(e[0] for e in extents), max(e[1] for e in extents)

    for angle in ANGLES:  # separate 1x4 file per direction, only without --plots-only
        if angle_dir is None:
            break
        fig, axes = plt.subplots(1, len(names), figsize=(3 * len(names), 7), sharey=True, squeeze=False)
        for ax, name in zip(axes[0], names):
            draw_tree(ax, clouds.get(name), name, center, angle, reach, top, rng)
            ax.set_xlabel("Horizontal distance [m]", fontsize=8)
        axes[0, 0].set_ylabel("Height above ground [m]", fontsize=8)
        fig.suptitle(f"View direction {angle}°", fontsize=10)
        fig.tight_layout()
        fig.savefig(angle_dir / f"profile_{angle:03d}.png", dpi=300)
        plt.close(fig)

    fig, axes = plt.subplots(len(ANGLES), len(names), figsize=(3 * len(names), 6.5 * len(ANGLES)),
                             sharey=True, squeeze=False)
    for row, angle in enumerate(ANGLES):
        for col, name in enumerate(names):
            draw_tree(axes[row, col], clouds.get(name), name, center, angle, reach, top, rng)
        axes[row, 0].set_ylabel(f"{angle}° – height [m]", fontsize=8)
    fig.suptitle(title, fontsize=11)
    fig.tight_layout(rect=(0, 0, 1, 0.985))  # leave room for the title
    fig.savefig(board_path, dpi=200)
    plt.close(fig)


def plot_overview(trees: dict, centers: dict, ref_ids: list[int], names: list[str], path: Path) -> None:
    """All trees side by side (columns) for every cloud (rows), viewing direction 0°."""
    rng = np.random.default_rng(0)
    fig, axes = plt.subplots(len(names), len(ref_ids), figsize=(2.2 * len(ref_ids), 4.5 * len(names)),
                             squeeze=False)
    for col, ref_id in enumerate(ref_ids):
        extents = [tree_extent(tree, centers[ref_id]) for tree in trees[ref_id].values()]
        reach, top = max(e[0] for e in extents), max(e[1] for e in extents)
        for row, name in enumerate(names):
            ax = axes[row, col]
            draw_tree(ax, trees[ref_id].get(name), name, centers[ref_id], 0, reach, top, rng)
            ax.set_title(f"{name}, tree {ref_id}", fontsize=8)
    fig.tight_layout()
    fig.savefig(path, dpi=200)
    plt.close(fig)


if __name__ == "__main__":
    main()
