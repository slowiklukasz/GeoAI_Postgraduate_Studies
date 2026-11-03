"""Stem cross-section of one tree at breast height in several clouds (1 x N panels, same scale).

The tree is found in every cloud by stem position, as in extract_tree.py: the reference position comes
from the Arbor tree list (X_bh, Y_bh). All panels are centred on that position, so offsets stay visible.
Optionally, the reference cloud can be drawn in light grey under the other clouds (--overlay TLS).

python scripts/cross_section.py --clouds-dir data/clouds --ref-csv tree_list_TLS.csv --ref-id 16 \
    --out cross_section_16.png

    --clouds NAME=path.laz    clouds given one by one instead of --clouds-dir
    --height 1.3              slice centre above ground [m]
    --thickness 0.1           slice thickness [m]
    --overlay TLS             draw this cloud in grey under the others (default: none)
    --point-size 2            marker size of the points
"""

from __future__ import annotations

import argparse
from pathlib import Path

import laspy
import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt
import numpy as np

from extract_tree import (COLORS, find_clouds, height_above_ground, parse_pairs, pick_id_field,
                          read_reference_positions, stem_positions)

OVERLAY_COLOR = "#c8c7c3"


def main() -> None:
    parser = argparse.ArgumentParser(description="Stem cross-section of one tree in several clouds.")
    clouds_arg = parser.add_mutually_exclusive_group(required=True)
    clouds_arg.add_argument("--clouds", nargs="+", help="NAME=path.laz, one per scanner")
    clouds_arg.add_argument("--clouds-dir", type=Path, help="folder with one LAZ/LAS per scanner")
    parser.add_argument("--ref-csv", type=Path, required=True, help="Arbor tree list of the reference")
    parser.add_argument("--ref-id", type=int, required=True, help="tree ID in the reference tree list")
    parser.add_argument("--height", type=float, default=1.3)
    parser.add_argument("--thickness", type=float, default=0.1)
    parser.add_argument("--overlay", default="")
    parser.add_argument("--point-size", type=float, default=2.0)
    parser.add_argument("--id-field", default="treeID")
    parser.add_argument("--max-dist", type=float, default=0.5)
    parser.add_argument("--out", type=Path, required=True, help="output PNG")
    args = parser.parse_args()

    clouds = find_clouds(args.clouds_dir) if args.clouds_dir else parse_pairs(args.clouds)
    center = read_reference_positions(args.ref_csv, [args.ref_id]).get(args.ref_id)
    if center is None:
        raise SystemExit(f"Tree {args.ref_id} not in {args.ref_csv}")

    slices: dict[str, tuple[int, np.ndarray, np.ndarray] | None] = {}
    for name, path in clouds.items():
        print(f"[{name}] reading {path}")
        las = laspy.read(path)
        ids = np.asarray(las[pick_id_field(las, args.id_field, name)]).astype(np.int64)
        x, y = np.asarray(las.x, dtype=float), np.asarray(las.y, dtype=float)
        h = height_above_ground(las, ids)
        stems = stem_positions(x, y, h, ids)
        dist = np.hypot(stems["x"] - center[0], stems["y"] - center[1])
        if dist.empty or dist.min() > args.max_dist:
            print(f"[{name}] no stem within {args.max_dist} m")
            slices[name] = None
            continue
        tree_id = int(dist.idxmin())
        band = (ids == tree_id) & (np.abs(h - args.height) <= args.thickness / 2)
        slices[name] = (tree_id, x[band] - center[0], y[band] - center[1])
        print(f"[{name}] tree {tree_id}: {band.sum():,} points in the slice")
        del las, ids, x, y, h  # free memory before the next cloud

    # common half-width: 99th percentile of the point distance from the centre, plus a margin
    radii = [np.percentile(np.hypot(s[1], s[2]), 99) for s in slices.values() if s is not None and len(s[1])]
    half = max(max(radii, default=0.2) + 0.05, 0.2)
    overlay = slices.get(args.overlay) if args.overlay else None

    names = list(clouds)
    fig, axes = plt.subplots(1, len(names), figsize=(3.2 * len(names), 3.4), squeeze=False)
    for ax, name in zip(axes[0], names):
        ax.set_xlim(-half, half)
        ax.set_ylim(-half, half)
        ax.set_aspect("equal")
        ax.tick_params(labelsize=7)
        ax.set_xlabel("X [m]", fontsize=8)
        data = slices[name]
        if data is None:
            ax.set_title(f"{name} (not found)", fontsize=9)
            continue
        if overlay is not None and name != args.overlay:
            ax.scatter(overlay[1], overlay[2], s=args.point_size, color=OVERLAY_COLOR, linewidths=0)
        ax.scatter(data[1], data[2], s=args.point_size, color=COLORS.get(name, "black"), linewidths=0)
        ax.set_title(f"{name} (n = {len(data[1]):,})", fontsize=9)
    axes[0, 0].set_ylabel("Y [m]", fontsize=8)
    fig.tight_layout()
    args.out.parent.mkdir(parents=True, exist_ok=True)
    fig.savefig(args.out, dpi=300)
    print(f"Saved {args.out}")


if __name__ == "__main__":
    main()
