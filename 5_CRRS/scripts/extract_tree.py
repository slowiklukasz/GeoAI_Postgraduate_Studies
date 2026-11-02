"""Extract the same tree from several instance-segmented LAZ clouds and plot its side views.

The tree is found in the reference cloud by its ID (or by an XY position). In every other
cloud the tree whose stem lies closest to the reference stem is taken, unless an ID is given.
Stem position = mean XY of the tree's points 1.0-1.6 m above ground.

python scripts/extract_tree.py \
    --clouds TLS=tls.laz GeoSLAM=geoslam.laz LiGrip=ligrip.laz low-cost=low_cost.laz \
    --reference TLS --ref-id 10 --out-dir tree_10

Optional:
    --ids LiGrip=59           use this ID instead of matching (any cloud)
    --ref-xy X Y              reference stem position instead of --ref-id
    --id-field treeID         instance field (default: treeID, auto-detected if empty)
    --max-dist 0.5            max stem distance for matching [m]

Outputs in --out-dir: one LAZ per cloud with the extracted tree, extracted_trees.csv,
profile_000.png ... profile_270.png (1x4 side views rotated by 90 degrees) and profiles_all.png.
Needs: pip install "laspy[lazrs]" numpy pandas matplotlib
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

STEM_BAND = (1.0, 1.6)        # height above ground used for the stem position [m]
SEARCH_RADIUS = 3.0           # only trees with points this close to the reference are considered [m]
MAX_PLOT_POINTS = 150_000     # random subsample per panel to keep plotting fast
COLORS = {"TLS": "#3d3d3a", "GeoSLAM": "#2a78d6", "LiGrip": "#eb6834", "low-cost": "#1baf7a"}
ID_CANDIDATES = ["treeID", "treeid", "tree_id", "instance", "PredInstance", "point_source_id", "user_data"]


def parse_pairs(items: list[str] | None, cast=str) -> dict:
    """Turn ['A=1', 'B=2'] into {'A': cast('1'), 'B': cast('2')}."""
    pairs = {}
    for item in items or []:
        name, _, value = item.partition("=")
        if not value:
            raise SystemExit(f"Expected NAME=VALUE, got: {item}")
        pairs[name] = cast(value)
    return pairs


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


def height_above_ground(las: laspy.LasData, ids: np.ndarray, region: np.ndarray) -> np.ndarray:
    """'hag' if the cloud has it, otherwise z minus the lowest point of the same tree.

    Without 'hag' the height is computed only for points in the region (NaN elsewhere).
    """
    if "hag" in las.point_format.dimension_names:
        return np.asarray(las["hag"], dtype=float)
    h = np.full(len(ids), np.nan)
    z = np.asarray(las.z, dtype=float)[region]
    h[region] = z - pd.Series(z).groupby(ids[region]).transform("min").to_numpy()
    return h


def stem_positions(x: np.ndarray, y: np.ndarray, h: np.ndarray, ids: np.ndarray) -> pd.DataFrame:
    """Mean XY of each tree's points in the stem band; index = tree ID."""
    band = (h >= STEM_BAND[0]) & (h <= STEM_BAND[1]) & valid_ids(ids)
    frame = pd.DataFrame({"id": ids[band], "x": x[band], "y": y[band]})
    return frame.groupby("id")[["x", "y"]].mean()


def main() -> None:
    parser = argparse.ArgumentParser(description="Extract the same tree from several LAZ clouds.")
    parser.add_argument("--clouds", nargs="+", required=True, help="NAME=path.laz, one per scanner")
    parser.add_argument("--reference", required=True, help="name of the reference cloud")
    ref = parser.add_mutually_exclusive_group(required=True)
    ref.add_argument("--ref-id", type=int, help="tree ID in the reference cloud")
    ref.add_argument("--ref-xy", nargs=2, type=float, metavar=("X", "Y"), help="reference stem XY")
    parser.add_argument("--ids", nargs="*", help="NAME=ID to skip matching for a cloud")
    parser.add_argument("--id-field", default="treeID")
    parser.add_argument("--max-dist", type=float, default=0.5)
    parser.add_argument("--out-dir", type=Path, required=True)
    args = parser.parse_args()

    clouds = parse_pairs(args.clouds, Path)
    fixed_ids = parse_pairs(args.ids, int)
    if args.reference not in clouds:
        raise SystemExit(f"--reference {args.reference} is not in --clouds")
    if args.ref_id is not None:
        fixed_ids.setdefault(args.reference, args.ref_id)
    args.out_dir.mkdir(parents=True, exist_ok=True)

    # reference first, so its stem position is known before matching the others
    order = [args.reference] + [name for name in clouds if name != args.reference]
    ref_xy = None if args.ref_xy is None else np.array(args.ref_xy)
    trees, rows = {}, []

    for name in order:
        path = clouds[name]
        print(f"[{name}] reading {path}")
        las = laspy.read(path)
        field = pick_id_field(las, args.id_field, name)
        ids = np.asarray(las[field]).astype(np.int64)
        x, y = np.asarray(las.x, dtype=float), np.asarray(las.y, dtype=float)

        if ref_xy is not None:  # restrict to the neighbourhood of the reference stem (fast)
            near = (np.abs(x - ref_xy[0]) < SEARCH_RADIUS) & (np.abs(y - ref_xy[1]) < SEARCH_RADIUS)
            near_ids = np.unique(ids[near & valid_ids(ids)])
            region = np.isin(ids, near_ids)
        else:
            region = valid_ids(ids)
        h = height_above_ground(las, ids, region)
        stems = stem_positions(x[region], y[region], h[region], ids[region])

        if name in fixed_ids:
            tree_id = fixed_ids[name]
            if tree_id not in stems.index:
                raise SystemExit(f"[{name}] tree ID {tree_id} not found in field '{field}'")
        else:
            if ref_xy is None:
                raise SystemExit("Reference stem position unknown: give --ref-id or --ref-xy")
            dist = np.hypot(stems["x"] - ref_xy[0], stems["y"] - ref_xy[1])
            if dist.empty or dist.min() > args.max_dist:
                raise SystemExit(f"[{name}] no stem within {args.max_dist} m of the reference")
            tree_id = int(dist.idxmin())

        stem = stems.loc[tree_id].to_numpy()
        if ref_xy is None:
            ref_xy = stem  # the reference tree defines the position for all other clouds
        mask = ids == tree_id
        out = laspy.LasData(las.header)
        out.points = las.points[mask].copy()
        out_path = args.out_dir / f"{name}_tree{tree_id}.laz"
        out.write(out_path)

        trees[name] = {"id": tree_id, "x": x[mask], "y": y[mask], "h": h[mask], "stem": stem}
        rows.append({"cloud": name, "file": str(path), "id_field": field, "tree_id": tree_id,
                     "stem_x": stem[0], "stem_y": stem[1],
                     "dist_to_ref_m": float(np.hypot(*(stem - ref_xy))),
                     "n_points": int(mask.sum()), "height_m": float(np.nanmax(h[mask]))})
        print(f"[{name}] tree {tree_id}: {mask.sum():,} points -> {out_path}")

    summary = pd.DataFrame(rows)
    summary.to_csv(args.out_dir / "extracted_trees.csv", index=False)
    print(summary.to_string(index=False))
    assert ref_xy is not None  # set by the reference cloud
    plot_profiles(trees, ref_xy, args.out_dir)


def plot_profiles(trees: dict, center: np.ndarray, out_dir: Path) -> None:
    """Side views of each tree, 1x4 per viewing direction, same scale in all panels."""
    rng = np.random.default_rng(0)
    names = list(trees)
    angles = [0, 90, 180, 270]
    reach = max(np.hypot(t["x"] - center[0], t["y"] - center[1]).max() for t in trees.values())
    top = max(np.nanmax(t["h"]) for t in trees.values())

    def draw(ax, tree, name, angle):
        theta = np.radians(angle)
        u = (tree["x"] - center[0]) * np.cos(theta) + (tree["y"] - center[1]) * np.sin(theta)
        keep = rng.permutation(len(u))[:MAX_PLOT_POINTS]
        ax.scatter(u[keep], tree["h"][keep], s=0.05, color=COLORS.get(name, "black"),
                   alpha=0.6, linewidths=0, rasterized=True)
        ax.set_xlim(-reach, reach)
        ax.set_ylim(0, top * 1.02)
        ax.set_aspect("equal")
        ax.set_title(f"{name} (ID {tree['id']})", fontsize=9)
        ax.tick_params(labelsize=7)

    for angle in angles:
        fig, axes = plt.subplots(1, len(names), figsize=(3 * len(names), 7), sharey=True)
        for ax, name in zip(np.atleast_1d(axes), names):
            draw(ax, trees[name], name, angle)
            ax.set_xlabel("Horizontal distance [m]", fontsize=8)
        np.atleast_1d(axes)[0].set_ylabel("Height above ground [m]", fontsize=8)
        fig.suptitle(f"View direction {angle}°", fontsize=10)
        fig.tight_layout()
        fig.savefig(out_dir / f"profile_{angle:03d}.png", dpi=300)
        plt.close(fig)

    fig, axes = plt.subplots(len(angles), len(names), figsize=(3 * len(names), 6.5 * len(angles)),
                             sharey=True, squeeze=False)
    for row, angle in enumerate(angles):
        for col, name in enumerate(names):
            draw(axes[row, col], trees[name], name, angle)
        axes[row, 0].set_ylabel(f"{angle}° – height [m]", fontsize=8)
    fig.tight_layout()
    fig.savefig(out_dir / "profiles_all.png", dpi=200)
    plt.close(fig)
    print(f"Saved profile plots to {out_dir}")


if __name__ == "__main__":
    main()
