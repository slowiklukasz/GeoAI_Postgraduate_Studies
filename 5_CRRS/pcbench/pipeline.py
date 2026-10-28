from __future__ import annotations

import logging
from collections.abc import Iterable, Mapping, Sequence
from pathlib import Path

import matplotlib.pyplot as plt
import pandas as pd

from .accuracy import (accuracy_summary, common_tree_pairs, flag_outlier_pairs,
                       paired_differences, stem_profile_bands, stem_profile_differences,
                       stem_profile_summary)
from .matching import build_link_table
from .plotting import plot_matched_predictions, plot_stem_profile

logger = logging.getLogger(__name__)


def run_matching(
    reference_df: pd.DataFrame,
    tests_dfs: Mapping[str, pd.DataFrame],
    output_dir: str | Path,
    reference_name: str = "Reference",
    max_dist: float = 0.5,
    duplicate_dist: float = 0.3,
    columns: tuple[str, str, str] = ("id", "x", "y"),
    save_plot: bool = True,
    show_ids: bool = True,
    region: tuple[float, float, float] | None = None,
) -> tuple[pd.DataFrame, pd.DataFrame, pd.DataFrame]:
    """Matching step: compare every dataset with the reference and save the results.

    Writes to output_dir:
        link_table.csv          – one row per reference tree, matched IDs per dataset
        detection_summary.csv   – TP / FN / FP (duplicate / extra), precision, recall, F1
        match_details.csv       – one row per tree and dataset with match diagnostics
        matched_predictions/    – one map per dataset (if save_plot=True)

    Returns (link_df, summary_df, details_df).
    """
    output_path = Path(output_dir)
    output_path.mkdir(parents=True, exist_ok=True)

    link_df, summary_df, details_df = build_link_table(
        reference_df, tests_dfs, max_dist=max_dist,
        duplicate_dist=duplicate_dist, columns=columns, fp_region=region,
    )
    link_df.to_csv(output_path / "link_table.csv", index=False)
    summary_df.to_csv(output_path / "detection_summary.csv", index=False)
    details_df.to_csv(output_path / "match_details.csv", index=False)

    if save_plot:
        figures = plot_matched_predictions(reference_df, tests_dfs, link_df,
                                           reference_name=reference_name, columns=columns,
                                           output_dir=output_path, save_plot=True,
                                           show_ids=show_ids)
        for fig in figures.values():
            plt.close(fig)  # free memory once the figures are saved

    return link_df, summary_df, details_df


def load_link_table(path: str | Path) -> pd.DataFrame:
    """Read a link_table.csv written by run_matching, keeping IDs as text."""
    header = pd.read_csv(path, nrows=0).columns
    id_columns = {column: "string" for column in header if column.endswith("_id")}
    return pd.read_csv(path, dtype=id_columns)


def run_accuracy(
    reference_df: pd.DataFrame,
    tests_dfs: Mapping[str, pd.DataFrame],
    link_df: pd.DataFrame,
    output_dir: str | Path,
    parameters: Sequence[str],
    tree_ids: Iterable[int | str] | None = None,
    outlier_dh: float = 3.0,
) -> tuple[pd.DataFrame, pd.DataFrame]:
    """Accuracy step: differences test − reference for matched trees and their summary.

    Writes to output_dir:
        paired_differences.csv               one row per matched pair and parameter;
                                             outlier_pair = pair with |ΔH| > outlier_dh
        accuracy_summary.csv                 n, bias, RMSE, SD, SE, z (absolute and %)
                                             per dataset and parameter – main result
        accuracy_summary_no_outliers.csv     same without outlier pairs (robustness check)
        accuracy_summary_common_trees.csv    DBH and V on reference trees compared in
                                             every dataset (same trees for all scanners)

    Returns (differences_df, summary_df).
    """
    output_path = Path(output_dir)
    output_path.mkdir(parents=True, exist_ok=True)

    differences_df = paired_differences(reference_df, tests_dfs, link_df,
                                        parameters=parameters, tree_ids=tree_ids)
    differences_df = flag_outlier_pairs(differences_df, outlier_dh)
    summary_df = accuracy_summary(differences_df)
    differences_df.to_csv(output_path / "paired_differences.csv", index=False)
    summary_df.to_csv(output_path / "accuracy_summary.csv", index=False)
    accuracy_summary(differences_df[~differences_df["outlier_pair"]]).to_csv(
        output_path / "accuracy_summary_no_outliers.csv", index=False)
    accuracy_summary(common_tree_pairs(differences_df)).to_csv(
        output_path / "accuracy_summary_common_trees.csv", index=False)
    return differences_df, summary_df


def run_stem_profiles(
    sections_dfs: Mapping[str, pd.DataFrame],
    link_df: pd.DataFrame,
    reference_dataset: str,
    output_dir: str | Path,
    tree_ids: Iterable[int | str] | None = None,
    min_pairs: int = 5,
    save_plot: bool = True,
    bands: Mapping[str, tuple[float, float]] | None = None,
) -> tuple[pd.DataFrame, pd.DataFrame]:
    """Stem profile step: diameter differences per section height (3DFin).

    Writes to output_dir:
        stem_profile_differences.csv – one row per matched pair and common section
        stem_profile_summary.csv     – n, bias, RMSE, SD, SE, z (cm and %) per dataset and height
        stem_profile_bands.csv       – mean bias / RMSE per height band and stem reach
        stem_profile.png             – bias / RMSE / n vs. height (if save_plot=True)

    Returns (differences_df, summary_df).
    """
    output_path = Path(output_dir)
    output_path.mkdir(parents=True, exist_ok=True)

    differences_df = stem_profile_differences(sections_dfs, link_df, reference_dataset,
                                              tree_ids=tree_ids)
    summary_df = stem_profile_summary(differences_df)
    differences_df.to_csv(output_path / "stem_profile_differences.csv", index=False)
    summary_df.to_csv(output_path / "stem_profile_summary.csv", index=False)
    stem_profile_bands(summary_df, bands or {}, min_pairs).to_csv(
        output_path / "stem_profile_bands.csv", index=False)

    if differences_df.empty:
        logger.warning("No stem sections compared – is '%s' matched to the reference? "
                       "Check its link-table column and coordinates.", reference_dataset)
        return differences_df, summary_df

    if save_plot:
        fig = plot_stem_profile(summary_df, reference_name=reference_dataset,
                                min_pairs=min_pairs)
        fig.savefig(output_path / "stem_profile.png", dpi=200, facecolor="white",
                    bbox_inches="tight")
        plt.close(fig)
    return differences_df, summary_df


def run_detection_variants(
    variants: Mapping[str, tuple[pd.DataFrame, Mapping[str, pd.DataFrame]]],
    output_dir: str | Path,
    max_dist: float = 0.5,
    duplicate_dist: float = 0.3,
    region: tuple[float, float, float] | None = None,
) -> pd.DataFrame:
    """Sensitivity step: detection metrics for several filter variants (no plots).

    variants – mapping {variant_name: (reference_df, tests_dfs)} loaded with different filters

    Writes to output_dir:
        <variant>/detection_summary.csv, <variant>/match_details.csv
        detection_variants.csv – all variants in one table (column `variant`, plus
                                 `n_reference` = reference trees in that variant)
    Returns the combined table.
    """
    output_path = Path(output_dir)
    frames: list[pd.DataFrame] = []
    for variant, (reference_df, tests_dfs) in variants.items():
        variant_path = output_path / variant
        variant_path.mkdir(parents=True, exist_ok=True)
        _, summary_df, details_df = build_link_table(
            reference_df, tests_dfs, max_dist=max_dist, duplicate_dist=duplicate_dist,
            fp_region=region)
        summary_df.to_csv(variant_path / "detection_summary.csv", index=False)
        details_df.to_csv(variant_path / "match_details.csv", index=False)
        frames.append(summary_df.assign(variant=variant, n_reference=len(reference_df)))
    combined = pd.concat(frames, ignore_index=True)
    combined = combined[["variant", "n_reference", *[c for c in combined.columns
                                                     if c not in ("variant", "n_reference")]]]
    combined.to_csv(output_path / "detection_variants.csv", index=False)
    return combined
