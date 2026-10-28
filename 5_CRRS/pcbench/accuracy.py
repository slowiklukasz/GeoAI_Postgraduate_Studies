"""Differences between matched trees (test − reference) and their summary.

Only matched pairs (TP) are compared; unmatched trees are covered by the
detection metrics.
"""

from __future__ import annotations

from collections.abc import Iterable, Mapping, Sequence
from dataclasses import dataclass

import numpy as np
import pandas as pd

MEASURED_STATUS = "measured"


@dataclass(frozen=True)
class Parameter:
    """How one compared parameter is read from a trees table."""

    column: str          # column in the common trees table
    unit: str            # unit of the reported values
    scale: float         # factor converting the column to `unit`
    measured_only: bool  # use only pairs where both trees have status "measured"


PARAMETERS: dict[str, Parameter] = {
    "dbh": Parameter(column="dbh", unit="cm", scale=100.0, measured_only=True),
    "h": Parameter(column="h", unit="m", scale=1.0, measured_only=False),
    "v": Parameter(column="v", unit="m3", scale=1.0, measured_only=True),
}
XY_OFFSET = "xy_offset"  # distance between matched stem positions (from the link table)


def _index_by_id(trees_df: pd.DataFrame) -> pd.DataFrame:
    """Index a trees table by its ID as text, so IDs from CSV and memory compare equal."""
    return trees_df.assign(id=trees_df["id"].astype(str)).set_index("id")


def _map_status(ids: pd.Series, trees: pd.DataFrame) -> pd.Series:
    """Status of the given trees, or empty values if the table has no status column."""
    if "status" not in trees.columns:
        return pd.Series(np.nan, index=ids.index, dtype=object)
    return ids.map(trees["status"])


def paired_differences(
    reference_df: pd.DataFrame,
    tests_dfs: Mapping[str, pd.DataFrame],
    link_df: pd.DataFrame,
    parameters: Sequence[str] = ("dbh", "h", "v", XY_OFFSET),
    tree_ids: Iterable[int | str] | None = None,
) -> pd.DataFrame:
    """Long table of differences test − reference for matched trees.

    reference_df : reference trees (common format: id, x, y, attributes, status)
    tests_dfs    : mapping {dataset_name: trees DataFrame}
    link_df      : link table from the matching step (ref_id, <name>_id, <name>_dist)
    parameters   : names from PARAMETERS and/or "xy_offset"
    tree_ids     : reference IDs to keep (None = all matched trees)

    Returns one row per pair and parameter:
        dataset, ref_id, test_id, parameter, unit, ref_value, test_value, diff,
        ref_status, test_status, match_dist
    For "xy_offset" diff is the XY distance of the pair (always >= 0).
    """
    unknown = set(parameters) - set(PARAMETERS) - {XY_OFFSET}
    if unknown:
        raise ValueError(f"Unknown parameters: {sorted(unknown)}")

    reference_trees = _index_by_id(reference_df)
    link = link_df.assign(ref_id=link_df["ref_id"].astype(str))
    if tree_ids is not None:
        link = link[link["ref_id"].isin({str(tree_id) for tree_id in tree_ids})]

    rows: list[pd.DataFrame] = []
    for dataset_name, test_df in tests_dfs.items():
        test_trees = _index_by_id(test_df)
        pairs = (link[["ref_id", f"{dataset_name}_id", f"{dataset_name}_dist"]]
                 .dropna(subset=[f"{dataset_name}_id"])
                 .rename(columns={f"{dataset_name}_id": "test_id",
                                  f"{dataset_name}_dist": "match_dist"}))
        pairs["test_id"] = pairs["test_id"].astype(str)
        pairs["ref_status"] = _map_status(pairs["ref_id"], reference_trees)
        pairs["test_status"] = _map_status(pairs["test_id"], test_trees)

        for parameter in parameters:
            frame = pairs.assign(dataset=dataset_name, parameter=parameter)
            if parameter == XY_OFFSET:
                frame = frame.assign(unit="m", ref_value=np.nan, test_value=np.nan,
                                     diff=frame["match_dist"])
            else:
                spec = PARAMETERS[parameter]
                frame = frame.assign(
                    unit=spec.unit,
                    ref_value=frame["ref_id"].map(reference_trees[spec.column]) * spec.scale,
                    test_value=frame["test_id"].map(test_trees[spec.column]) * spec.scale,
                )
                frame["diff"] = frame["test_value"] - frame["ref_value"]
                if spec.measured_only and "status" in reference_trees and "status" in test_trees:
                    both_measured = ((frame["ref_status"] == MEASURED_STATUS)
                                     & (frame["test_status"] == MEASURED_STATUS))
                    frame = frame[both_measured]
                frame = frame.dropna(subset=["diff"])
            rows.append(frame)

    columns = ["dataset", "ref_id", "test_id", "parameter", "unit", "ref_value",
               "test_value", "diff", "ref_status", "test_status", "match_dist"]
    if not rows:
        return pd.DataFrame(columns=columns)
    return pd.concat(rows, ignore_index=True)[columns]


def _summarise(differences_df: pd.DataFrame, keys: list[str],
               ref_column: str = "ref_value") -> pd.DataFrame:
    """n, bias, RMSE and their values relative to the mean reference value per group."""
    grouped = differences_df.groupby(keys, sort=False)
    summary_df = grouped.agg(
        n=("diff", "size"),
        bias=("diff", "mean"),
        rmse=("diff", lambda d: float(np.sqrt(np.mean(np.square(d))))),
        sd=("diff", "std"),
        ref_mean=(ref_column, "mean"),
    ).reset_index()
    summary_df["se"] = summary_df["sd"] / np.sqrt(summary_df["n"])
    summary_df["z"] = np.where((summary_df["se"] == 0) & (summary_df["bias"] == 0), 0.0,
                               summary_df["bias"] / summary_df["se"])
    summary_df["bias_pct"] = summary_df["bias"] / summary_df["ref_mean"] * 100
    summary_df["rmse_pct"] = summary_df["rmse"] / summary_df["ref_mean"] * 100
    return summary_df


def accuracy_summary(differences_df: pd.DataFrame) -> pd.DataFrame:
    """Bias and RMSE per dataset and parameter.

    Returns: dataset, parameter, unit, n, bias, rmse, sd, ref_mean, se, z,
    bias_pct, rmse_pct (percentages relative to the mean reference value;
    empty for xy_offset). z = bias / se, se = sd / sqrt(n).
    """
    return _summarise(differences_df, ["dataset", "parameter", "unit"])


def flag_outlier_pairs(differences_df: pd.DataFrame, max_abs_dh: float) -> pd.DataFrame:
    """Add `outlier_pair`: True for every row of a pair whose height difference exceeds
    max_abs_dh [m] (typically a reference tree matched to a fragment)."""
    is_outlier_h = (differences_df["parameter"] == "h") & (differences_df["diff"].abs() > max_abs_dh)
    outliers = set(zip(differences_df.loc[is_outlier_h, "dataset"],
                       differences_df.loc[is_outlier_h, "ref_id"]))
    keys = zip(differences_df["dataset"], differences_df["ref_id"])
    return differences_df.assign(outlier_pair=[key in outliers for key in keys])


def common_tree_pairs(differences_df: pd.DataFrame,
                      parameters: Sequence[str] = ("dbh", "v")) -> pd.DataFrame:
    """Rows of the given parameters for reference trees compared in every dataset,
    so that datasets are compared on the same trees."""
    rows = differences_df[differences_df["parameter"].isin(parameters)]
    datasets = rows["dataset"].nunique()
    counts = rows.groupby(["parameter", "ref_id"])["dataset"].nunique()
    common = counts[counts == datasets].index
    keys = pd.MultiIndex.from_frame(rows[["parameter", "ref_id"]])
    return rows[keys.isin(common)]


def stem_profile_differences(
    sections_dfs: Mapping[str, pd.DataFrame],
    link_df: pd.DataFrame,
    reference_dataset: str,
    tree_ids: Iterable[int | str] | None = None,
) -> pd.DataFrame:
    """Stem diameter differences test − reference per height section (3DFin).

    sections_dfs      : mapping {dataset_name: sections table (id, section, height, diameter)}
    link_df           : link table of the 3DFin matching run (ref_id, <name>_id per dataset)
    reference_dataset : name of the 3DFin dataset used as the profile reference (e.g. TLS)
    tree_ids          : master reference IDs to keep (None = all matched trees)

    Only sections fitted in both trees of a pair are compared. Diameters in cm.
    Returns: dataset, ref_id, ref_tree, test_tree, height, ref_diameter,
             test_diameter, diff
    """
    if reference_dataset not in sections_dfs:
        raise ValueError(f"Reference dataset '{reference_dataset}' not among "
                         f"{sorted(sections_dfs)}")

    link = link_df.assign(ref_id=link_df["ref_id"].astype(str))
    if tree_ids is not None:
        link = link[link["ref_id"].isin({str(tree_id) for tree_id in tree_ids})]

    def sections_of(dataset_name: str, tree_column: str) -> pd.DataFrame:
        sections = sections_dfs[dataset_name]
        return pd.DataFrame({
            tree_column: sections["id"].astype(str),
            "height": sections["height"],
            "diameter": sections["diameter"] * 100.0,  # m -> cm
        })

    reference_sections = sections_of(reference_dataset, "ref_tree")
    rows: list[pd.DataFrame] = []
    for dataset_name in sections_dfs:
        if dataset_name == reference_dataset:
            continue
        pairs = (link[["ref_id", f"{reference_dataset}_id", f"{dataset_name}_id"]]
                 .dropna()
                 .rename(columns={f"{reference_dataset}_id": "ref_tree",
                                  f"{dataset_name}_id": "test_tree"})
                 .astype({"ref_tree": str, "test_tree": str}))
        frame = (pairs
                 .merge(reference_sections, on="ref_tree")
                 .merge(sections_of(dataset_name, "test_tree"), on=["test_tree", "height"],
                        suffixes=("_ref", "_test"))
                 .rename(columns={"diameter_ref": "ref_diameter",
                                  "diameter_test": "test_diameter"}))
        frame["diff"] = frame["test_diameter"] - frame["ref_diameter"]
        rows.append(frame.assign(dataset=dataset_name))

    columns = ["dataset", "ref_id", "ref_tree", "test_tree", "height",
               "ref_diameter", "test_diameter", "diff"]
    if not rows:
        return pd.DataFrame(columns=columns)
    return pd.concat(rows, ignore_index=True)[columns].sort_values(
        ["dataset", "height", "ref_id"], ignore_index=True)


def stem_profile_summary(differences_df: pd.DataFrame) -> pd.DataFrame:
    """Bias and RMSE of stem diameter per dataset and section height.

    Returns: dataset, height, n, bias, rmse, ref_mean, bias_pct, rmse_pct (cm / %).
    """
    return _summarise(differences_df, ["dataset", "height"], ref_column="ref_diameter")


def stem_profile_bands(
    summary_df: pd.DataFrame,
    bands: Mapping[str, tuple[float, float]],
    min_pairs: int,
) -> pd.DataFrame:
    """Mean bias / RMSE per dataset and height band, plus stem reach.

    Only heights with n >= min_pairs are used. Band value = mean of the per-height values.
    Rows with band "reach" give the highest section with n >= min_pairs (max_height).
    Returns: dataset, band, low, high, n_heights, mean_bias, mean_rmse, max_height
    """
    reliable = summary_df[summary_df["n"] >= min_pairs]
    rows: list[dict[str, object]] = []
    for dataset_name, group in reliable.groupby("dataset", sort=False):
        for band, (low, high) in bands.items():
            in_band = group[(group["height"] >= low) & (group["height"] <= high)]
            rows.append({"dataset": dataset_name, "band": band, "low": low, "high": high,
                         "n_heights": len(in_band),
                         "mean_bias": in_band["bias"].mean() if len(in_band) else np.nan,
                         "mean_rmse": in_band["rmse"].mean() if len(in_band) else np.nan})
        rows.append({"dataset": dataset_name, "band": "reach", "n_heights": len(group),
                     "max_height": group["height"].max()})
    columns = ["dataset", "band", "low", "high", "n_heights", "mean_bias", "mean_rmse",
               "max_height"]
    return pd.DataFrame(rows, columns=columns)
