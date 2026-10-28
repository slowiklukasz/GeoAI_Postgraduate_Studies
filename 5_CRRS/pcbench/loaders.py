"""Read tool outputs into a common trees table.

Common columns: id, x, y (+ tool-specific attributes). Units are metres.
"""

from __future__ import annotations

from collections.abc import Sequence
from pathlib import Path

import numpy as np
import pandas as pd

_ARBOR_COLUMNS = {
    "treeID": "id",
    "X_root": "x",
    "Y_root": "y",
    "Z_root": "z",
    "DBH": "dbh",
    "H": "h",
    "V": "v",
    "status": "status",
}
_ARBOR_PREFIX = "tree_list_"
_THREEDFIN_SHEET = "Plot metrics"
_THREEDFIN_HEADER_ROW = 2  # two title rows precede the column header
_THREEDFIN_DIAMETERS_SHEET = "Diameters"
_THREEDFIN_SECTIONS_SHEET = "Sections"


def load_arbor_tree_list(
    path: str | Path,
    exclude_status: Sequence[str] = ("W3 allometry",),
    max_root_above_bh: float = 1.0,
) -> pd.DataFrame:
    """Load an Arbor tree_list.csv.

    Rows whose status is in exclude_status are dropped, as are artefacts whose
    root lies more than max_root_above_bh [m] above the breast-height point.
    Returns columns id, x, y, z, dbh, h, v, status (root position, metres).
    """
    raw_df = pd.read_csv(path)
    missing = (set(_ARBOR_COLUMNS) | {"Z_bh"}) - set(raw_df.columns)
    if missing:
        raise ValueError(f"{path}: missing columns {sorted(missing)}")

    is_artefact = raw_df["Z_root"] > raw_df["Z_bh"] + max_root_above_bh
    keep = ~raw_df["status"].isin(exclude_status) & ~is_artefact
    trees_df = raw_df.loc[keep, list(_ARBOR_COLUMNS)].rename(columns=_ARBOR_COLUMNS)
    return trees_df.reset_index(drop=True)


def load_3dfin_plot_metrics(path: str | Path) -> pd.DataFrame:
    """Load the per-tree sheet of a 3DFin .xlsx output.

    Returns columns id, x, y, dbh, h (stem position at breast height, metres).
    A DBH of 0 means no circle was fitted and is returned as missing.
    """
    raw_df = pd.read_excel(path, sheet_name=_THREEDFIN_SHEET, header=_THREEDFIN_HEADER_ROW)
    raw_df = raw_df.iloc[:, 1:6]  # first column is empty, second holds the tree labels
    raw_df.columns = ["id", "h", "dbh", "x", "y"]
    trees_df = raw_df.dropna(subset=["id", "x", "y"]).copy()
    trees_df["dbh"] = trees_df["dbh"].replace(0, np.nan)
    return trees_df[["id", "x", "y", "dbh", "h"]].reset_index(drop=True)


def load_3dfin_sections(path: str | Path) -> pd.DataFrame:
    """Load stem diameters of every section from a 3DFin .xlsx output.

    Returns one row per fitted section: id, section, height, diameter
    (normalised section height and diameter in metres). Sections without a
    fitted circle (diameter 0) are left out.
    """
    sections_raw = pd.read_excel(path, sheet_name=_THREEDFIN_SECTIONS_SHEET, header=None)
    section_heights = dict(zip(sections_raw.iloc[1].astype(str),
                               sections_raw.iloc[2].astype(float).round(2)))

    diameters = pd.read_excel(path, sheet_name=_THREEDFIN_DIAMETERS_SHEET, header=1)
    diameters = diameters.iloc[:, 1:].rename(columns={diameters.columns[1]: "id"})
    diameters = diameters.dropna(subset=["id"])

    sections_df = diameters.melt(id_vars="id", var_name="section", value_name="diameter")
    sections_df["height"] = sections_df["section"].astype(str).map(section_heights)
    sections_df = sections_df[sections_df["diameter"] > 0]
    return sections_df[["id", "section", "height", "diameter"]].reset_index(drop=True)


def dataset_name(path: Path, prefix: str = "") -> str:
    """Dataset name from a file name, e.g. tree_list_HLS_LiGrip.csv -> HLS_LiGrip."""
    stem = path.stem
    return stem[len(prefix):] if prefix and stem.startswith(prefix) else stem


def load_arbor_dir(
    directory: str | Path,
    exclude_status: Sequence[str] = ("W3 allometry",),
    max_root_above_bh: float = 1.0,
    skip: Sequence[Path] = (),
) -> dict[str, pd.DataFrame]:
    """Load every Arbor CSV in a directory; files listed in skip are ignored."""
    skipped = {p.resolve() for p in skip}
    return {
        dataset_name(path, _ARBOR_PREFIX): load_arbor_tree_list(
            path, exclude_status, max_root_above_bh)
        for path in sorted(Path(directory).glob("*.csv"))
        if path.resolve() not in skipped
    }


def load_3dfin_dir(directory: str | Path) -> dict[str, pd.DataFrame]:
    """Load every 3DFin .xlsx output in a directory."""
    return {
        dataset_name(path): load_3dfin_plot_metrics(path)
        for path in sorted(Path(directory).glob("*.xlsx"))
        if not path.name.startswith("~$")  # skip Excel lock files
    }


def load_3dfin_sections_dir(directory: str | Path) -> dict[str, pd.DataFrame]:
    """Load the section diameters of every 3DFin .xlsx output in a directory."""
    return {
        dataset_name(path): load_3dfin_sections(path)
        for path in sorted(Path(directory).glob("*.xlsx"))
        if not path.name.startswith("~$")
    }


def filter_region(trees_df: pd.DataFrame,
                  region: tuple[float, float, float] | None,
                  buffer: float = 0.0) -> pd.DataFrame:
    """Keep trees whose position lies within a circle (x, y, radius + buffer); None keeps all.

    Compared datasets are loaded with buffer = matching distance, so that a reference tree
    just inside the circle can still find its partner just outside it.
    """
    if region is None:
        return trees_df
    x, y, radius = region
    inside = np.hypot(trees_df["x"] - x, trees_df["y"] - y) <= radius + buffer
    return trees_df[inside].reset_index(drop=True)
