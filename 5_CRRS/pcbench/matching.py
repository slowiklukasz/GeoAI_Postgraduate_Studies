from __future__ import annotations

from collections.abc import Mapping, Sequence

import numpy as np
import pandas as pd
from scipy.optimize import linear_sum_assignment
from scipy.spatial.distance import cdist

_FORBIDDEN_COST = 1e6  # cost assigned to pairs beyond the distance threshold


def match_predictions(
    reference_df: pd.DataFrame,
    test_df: pd.DataFrame,
    max_dist: float = 0.5,
    reference_cols: tuple[str, str, str] = ("id", "x", "y"),
    test_cols: tuple[str, str, str] = ("id", "x", "y"),
) -> pd.DataFrame:
    """Match trees from two datasets one-to-one by XY distance (Hungarian algorithm).

    reference_df, test_df : DataFrames with a tree ID column and X, Y coordinates
    max_dist              : maximum distance of a valid pair [m]; more distant pairs are rejected
    reference_cols, test_cols : column names (id, x, y) in each dataset

    Returns a DataFrame with one row per tree from both datasets:
        ref_id, test_id, dist, match ("TP" / "FN" / "FP")
    """
    ref_id_col, ref_x_col, ref_y_col = reference_cols
    test_id_col, test_x_col, test_y_col = test_cols
    reference_ids = reference_df[ref_id_col].to_numpy(dtype=object)
    test_ids = test_df[test_id_col].to_numpy(dtype=object)

    distance_matrix = cdist(
        reference_df[[ref_x_col, ref_y_col]].to_numpy(),
        test_df[[test_x_col, test_y_col]].to_numpy(),
    )
    cost_matrix = np.where(distance_matrix <= max_dist, distance_matrix, _FORBIDDEN_COST)
    ref_idx, test_idx = linear_sum_assignment(cost_matrix)

    is_valid_pair = distance_matrix[ref_idx, test_idx] <= max_dist
    ref_idx, test_idx = ref_idx[is_valid_pair], test_idx[is_valid_pair]

    matched_df = pd.DataFrame({
        "ref_id": reference_ids[ref_idx],
        "test_id": test_ids[test_idx],
        "dist": distance_matrix[ref_idx, test_idx],
        "match": "TP",
    })
    missed_df = pd.DataFrame({"ref_id": np.delete(reference_ids, ref_idx), "match": "FN"})
    extra_df = pd.DataFrame({"test_id": np.delete(test_ids, test_idx), "match": "FP"})
    return pd.concat([matched_df, missed_df, extra_df], ignore_index=True)


def describe_matches(
    reference_df: pd.DataFrame,
    test_df: pd.DataFrame,
    match_df: pd.DataFrame,
    dataset_name: str,
    max_dist: float = 0.5,
    duplicate_dist: float = 0.3,
    columns: tuple[str, str, str] = ("id", "x", "y"),
    attributes: Sequence[str] = ("status", "h"),
) -> pd.DataFrame:
    """Add diagnostics to the output of match_predictions (one row per tree).

    FN rows get the nearest test tree (nearest_id, nearest_dist) and an error_type:
        "too_far" – no test tree within max_dist
        "taken"   – the nearby test tree was matched to another reference tree
    FP rows get the nearest matched test tree and an error_type:
        "duplicate" – within duplicate_dist of a matched test tree (over-segmentation)
        "extra"     – stand-alone detection absent from the reference
    For every attribute in `attributes` the reference and test values are added
    as ref_<attribute> and test_<attribute> (empty if the column is missing).
    """
    id_col, x_col, y_col = columns
    reference_trees = reference_df.set_index(id_col)
    test_trees = test_df.set_index(id_col)

    details_df = match_df.copy()
    details_df.insert(0, "dataset", dataset_name)
    details_df["nearest_id"] = pd.Series(dtype=object)
    details_df["nearest_dist"] = np.nan
    details_df["error_type"] = pd.Series(dtype=object)

    is_fn = details_df["match"] == "FN"
    if is_fn.any():
        if len(test_trees):
            fn_xy = reference_trees.loc[details_df.loc[is_fn, "ref_id"], [x_col, y_col]]
            distance_matrix = cdist(fn_xy.to_numpy(), test_trees[[x_col, y_col]].to_numpy())
            nearest_dist = distance_matrix.min(axis=1)
            details_df.loc[is_fn, "nearest_id"] = (
                test_trees.index.to_numpy(dtype=object)[distance_matrix.argmin(axis=1)])
            details_df.loc[is_fn, "nearest_dist"] = nearest_dist
            details_df.loc[is_fn, "error_type"] = np.where(
                nearest_dist > max_dist, "too_far", "taken")
        else:
            details_df.loc[is_fn, "error_type"] = "too_far"

    is_fp = details_df["match"] == "FP"
    matched_test_ids = details_df.loc[details_df["match"] == "TP", "test_id"].to_numpy()
    if is_fp.any():
        if len(matched_test_ids):
            fp_xy = test_trees.loc[details_df.loc[is_fp, "test_id"], [x_col, y_col]]
            matched_xy = test_trees.loc[matched_test_ids, [x_col, y_col]]
            distance_matrix = cdist(fp_xy.to_numpy(), matched_xy.to_numpy())
            nearest_dist = distance_matrix.min(axis=1)
            details_df.loc[is_fp, "nearest_id"] = (
                matched_test_ids.astype(object)[distance_matrix.argmin(axis=1)])
            details_df.loc[is_fp, "nearest_dist"] = nearest_dist
            details_df.loc[is_fp, "error_type"] = np.where(
                nearest_dist <= duplicate_dist, "duplicate", "extra")
        else:
            details_df.loc[is_fp, "error_type"] = "extra"

    for attribute in attributes:
        for prefix, trees, id_column in (("ref", reference_trees, "ref_id"),
                                         ("test", test_trees, "test_id")):
            details_df[f"{prefix}_{attribute}"] = (
                details_df[id_column].map(trees[attribute])
                if attribute in trees.columns else np.nan)

    leading = ["dataset", "match", "error_type", "ref_id", "test_id", "dist",
               "nearest_id", "nearest_dist"]
    return details_df[leading + [c for c in details_df.columns if c not in leading]]


def build_link_table(
    reference_df: pd.DataFrame,
    tests_dfs: Mapping[str, pd.DataFrame],
    max_dist: float = 0.5,
    duplicate_dist: float = 0.3,
    columns: tuple[str, str, str] = ("id", "x", "y"),
    attributes: Sequence[str] = ("status", "h"),
) -> tuple[pd.DataFrame, pd.DataFrame, pd.DataFrame]:
    """Match several datasets against one reference (star layout).

    reference_df   : reference DataFrame (e.g. TLS); its IDs become the master key
    tests_dfs      : mapping {dataset_name: DataFrame} with the datasets to compare
    max_dist       : maximum distance of a valid pair [m]
    duplicate_dist : FP closer than this to a matched test tree counts as a duplicate [m]
    columns        : common column names (id, x, y) used in all DataFrames
    attributes     : columns copied into the details table for both sides

    Returns:
        link_df    – one row per reference tree; for each dataset the matched
                     ID and distance (<name>_id, <name>_dist), empty = missed
        summary_df – TP / FN / FP (FP split into duplicate / extra),
                     precision, recall and F1 per dataset
        details_df – one row per tree and dataset with match type and diagnostics
                     (see describe_matches)
    """
    id_col = columns[0]
    link_df = reference_df[[id_col]].rename(columns={id_col: "ref_id"})
    summary_rows: list[dict[str, float | int | str]] = []
    details_dfs: list[pd.DataFrame] = []

    for dataset_name, test_df in tests_dfs.items():
        match_df = match_predictions(
            reference_df, test_df, max_dist,
            reference_cols=columns, test_cols=columns,
        )
        matched_df = match_df.loc[match_df["match"] == "TP", ["ref_id", "test_id", "dist"]]
        link_df = link_df.merge(
            matched_df.rename(columns={"test_id": f"{dataset_name}_id",
                                       "dist": f"{dataset_name}_dist"}),
            on="ref_id", how="left",
        )

        details_df = describe_matches(reference_df, test_df, match_df, dataset_name,
                                      max_dist=max_dist, duplicate_dist=duplicate_dist,
                                      columns=columns, attributes=attributes)
        details_dfs.append(details_df)

        counts = match_df["match"].value_counts().reindex(["TP", "FN", "FP"], fill_value=0)
        n_tp, n_fn, n_fp = int(counts["TP"]), int(counts["FN"]), int(counts["FP"])
        n_duplicate = int((details_df["error_type"] == "duplicate").sum())
        precision = n_tp / (n_tp + n_fp) if n_tp + n_fp else np.nan
        recall = n_tp / (n_tp + n_fn) if n_tp + n_fn else np.nan
        f1 = (2 * precision * recall / (precision + recall)
              if precision + recall else np.nan)
        summary_rows.append({
            "dataset": dataset_name, "TP": n_tp, "FN": n_fn, "FP": n_fp,
            "FP_duplicate": n_duplicate, "FP_extra": n_fp - n_duplicate,
            "precision": precision, "recall": recall, "F1": f1,
        })

    return link_df, pd.DataFrame(summary_rows), pd.concat(details_dfs, ignore_index=True)
