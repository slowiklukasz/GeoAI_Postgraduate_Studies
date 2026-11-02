from __future__ import annotations

from collections.abc import Iterable, Mapping, Sequence
from pathlib import Path

import matplotlib.pyplot as plt
import pandas as pd

from .accuracy import (accuracy_summary, paired_differences, stem_profile_differences,
                       stem_profile_summary)
from .matching import build_link_table
from .plotting import plot_matched_predictions, plot_stem_profile


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
        duplicate_dist=duplicate_dist, columns=columns,
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
) -> tuple[pd.DataFrame, pd.DataFrame]:
    """Accuracy step: differences test − reference for matched trees and their summary.

    Writes to output_dir:
        paired_differences.csv – one row per matched pair and parameter
        accuracy_summary.csv   – n, bias, RMSE (absolute and %) per dataset and parameter

    Returns (differences_df, summary_df).
    """
    output_path = Path(output_dir)
    output_path.mkdir(parents=True, exist_ok=True)

    differences_df = paired_differences(reference_df, tests_dfs, link_df,
                                        parameters=parameters, tree_ids=tree_ids)
    summary_df = accuracy_summary(differences_df)
    differences_df.to_csv(output_path / "paired_differences.csv", index=False)
    summary_df.to_csv(output_path / "accuracy_summary.csv", index=False)
    return differences_df, summary_df


def run_stem_profiles(
    sections_dfs: Mapping[str, pd.DataFrame],
    link_df: pd.DataFrame,
    reference_dataset: str,
    output_dir: str | Path,
    tree_ids: Iterable[int | str] | None = None,
    min_pairs: int = 5,
    save_plot: bool = True,
) -> tuple[pd.DataFrame, pd.DataFrame]:
    """Stem profile step: diameter differences per section height (3DFin).

    Writes to output_dir:
        stem_profile_differences.csv – one row per matched pair and common section
        stem_profile_summary.csv     – n, bias, RMSE (cm and %) per dataset and height
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

    if save_plot:
        fig = plot_stem_profile(summary_df, reference_name=reference_dataset,
                                min_pairs=min_pairs)
        fig.savefig(output_path / "stem_profile.png", dpi=200, facecolor="white",
                    bbox_inches="tight")
        plt.close(fig)
    return differences_df, summary_df
