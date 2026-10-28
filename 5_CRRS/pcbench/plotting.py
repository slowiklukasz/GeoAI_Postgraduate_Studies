from __future__ import annotations

import re
from collections.abc import Mapping
from pathlib import Path

import matplotlib

matplotlib.use("Agg")  # render to file, no display needed
import matplotlib.pyplot as plt
import pandas as pd
from matplotlib.figure import Figure
from matplotlib.lines import Line2D

_REFERENCE_COLOR = "#3d3d3a"   # neutral ink for the reference
_TEST_COLOR = "#2a78d6"        # one colour for the compared dataset
_ERROR_COLOR = "#e34948"       # red marks for errors: FP crosses and FN rings
_TEXT_PRIMARY = "#0b0b0b"
_TEXT_MUTED = "#52514e"
_GRID_COLOR = "#e4e3df"

_REFERENCE_SIZE = 200.0  # marker area of reference trees
_TEST_SIZE = 60.0        # marker area of compared trees


def plot_matched_pair(
    reference_df: pd.DataFrame,
    test_df: pd.DataFrame,
    pairs_df: pd.DataFrame,
    reference_name: str = "Reference",
    test_name: str = "Test",
    columns: tuple[str, str, str] = ("id", "x", "y"),
    show_ids: bool = True,
) -> Figure:
    """Top-view map of one dataset matched against the reference.

    reference_df : reference trees
    test_df      : trees of the compared dataset
    pairs_df     : matched pairs with columns ref_id, test_id
    columns      : common column names (id, x, y) used in both DataFrames
    show_ids     : label reference trees with their IDs

    Reference trees are large dark dots, test trees small blue dots. Errors are red:
    reference trees missed by the test (FN) are rings, unmatched test trees (FP)
    are crosses. Matched trees are joined by a thin line.
    """
    id_col, x_col, y_col = columns
    reference_xy = reference_df.set_index(id_col)[[x_col, y_col]]
    test_xy = test_df.set_index(id_col)[[x_col, y_col]]

    matched_ref_xy = reference_xy.loc[pairs_df["ref_id"]]
    missed_ref_xy = reference_xy[~reference_xy.index.isin(pairs_df["ref_id"])]
    matched_test_xy = test_xy.loc[pairs_df["test_id"]]
    unmatched_test_xy = test_xy[~test_xy.index.isin(pairs_df["test_id"])]

    n_tp, n_fn, n_fp = len(pairs_df), len(missed_ref_xy), len(unmatched_test_xy)
    precision = n_tp / (n_tp + n_fp) if n_tp + n_fp else float("nan")
    recall = n_tp / (n_tp + n_fn) if n_tp + n_fn else float("nan")
    f1 = 2 * precision * recall / (precision + recall) if precision + recall else float("nan")

    fig, ax = plt.subplots(figsize=(8, 8.5), facecolor="white")
    ax.set_facecolor("white")

    for (rx, ry), (tx, ty) in zip(matched_ref_xy.to_numpy(), matched_test_xy.to_numpy()):
        ax.plot([rx, tx], [ry, ty], color=_TEST_COLOR, linewidth=1.0, zorder=3)

    ax.scatter(matched_ref_xy[x_col], matched_ref_xy[y_col], s=_REFERENCE_SIZE,
               color=_REFERENCE_COLOR, edgecolors="white", linewidths=1.5, zorder=2)
    ax.scatter(missed_ref_xy[x_col], missed_ref_xy[y_col], s=_REFERENCE_SIZE,
               facecolors="white", edgecolors=_ERROR_COLOR, linewidths=2.0, zorder=2)
    ax.scatter(matched_test_xy[x_col], matched_test_xy[y_col], s=_TEST_SIZE,
               color=_TEST_COLOR, edgecolors="white", linewidths=1.0, zorder=4)
    ax.scatter(unmatched_test_xy[x_col], unmatched_test_xy[y_col], s=_TEST_SIZE, marker="x",
               color=_ERROR_COLOR, linewidths=1.8, zorder=4)

    if show_ids:
        for tree_id, (x, y) in reference_xy.iterrows():
            ax.annotate(str(tree_id), (x, y), xytext=(6, 6), textcoords="offset points",
                        fontsize=7, color=_TEXT_MUTED, zorder=10)

    # Column 1: detections of each dataset; column 2: errors (FP, FN).
    legend_handles = [
        Line2D([], [], marker="o", linestyle="", markersize=11, markerfacecolor=_REFERENCE_COLOR,
               markeredgecolor="white", label=f"Reference detection ({len(reference_xy)})"),
        Line2D([], [], marker="o", linestyle="", markersize=6, color=_TEST_COLOR,
               markeredgecolor="white", label=f"Test detection ({len(test_xy)})"),
        Line2D([], [], marker="x", linestyle="", markersize=7, color=_ERROR_COLOR,
               markeredgewidth=1.8, label=f"False positive – not in reference ({n_fp})"),
        Line2D([], [], marker="o", linestyle="", markersize=11, markerfacecolor="white",
               markeredgecolor=_ERROR_COLOR, markeredgewidth=2,
               label=f"False negative – missed by test ({n_fn})"),
    ]
    ax.legend(handles=legend_handles, loc="upper left", bbox_to_anchor=(0, -0.08),
              ncol=2, frameon=False, fontsize=9, labelcolor=_TEXT_PRIMARY)

    ax.set_title(f"Test: {test_name}   |   Reference: {reference_name}", loc="left",
                 fontsize=12, color=_TEXT_PRIMARY, pad=20)
    ax.text(0, 1.01, f"matched {n_tp} · precision {precision:.2f} · recall {recall:.2f} · F1 {f1:.2f}",
            transform=ax.transAxes, fontsize=9, color=_TEXT_MUTED, va="bottom")

    ax.set_aspect("equal")
    ax.set_xlabel("X [m]", color=_TEXT_MUTED)
    ax.set_ylabel("Y [m]", color=_TEXT_MUTED)
    ax.grid(color=_GRID_COLOR, linewidth=0.6, zorder=0)
    ax.tick_params(colors=_TEXT_MUTED, labelsize=8)
    for spine in ax.spines.values():
        spine.set_color(_GRID_COLOR)
    fig.tight_layout()
    return fig


def _safe_name(name: str) -> str:
    """Make a dataset name safe for use in a file name."""
    return re.sub(r"[^A-Za-z0-9_-]+", "_", name).strip("_")


def plot_matched_predictions(
    reference_df: pd.DataFrame,
    tests_dfs: Mapping[str, pd.DataFrame],
    link_df: pd.DataFrame,
    reference_name: str = "Reference",
    columns: tuple[str, str, str] = ("id", "x", "y"),
    output_dir: str | Path | None = None,
    save_plot: bool = True,
    show_ids: bool = True,
) -> dict[str, Figure]:
    """One matching map per compared dataset, based on the link table.

    link_df    : output of build_link_table (ref_id + <name>_id per dataset)
    output_dir : root output directory; figures are saved to
                 output_dir/matched_predictions/ref-<reference>_test-<dataset>.png
    save_plot  : save each figure as PNG (requires output_dir)

    Returns a mapping {dataset_name: Figure}.
    """
    if save_plot and output_dir is None:
        raise ValueError("output_dir is required when save_plot=True.")
    plot_dir = Path(output_dir) / "matched_predictions" if output_dir is not None else None

    figures: dict[str, Figure] = {}
    for test_name, test_df in tests_dfs.items():
        pairs_df = (link_df[["ref_id", f"{test_name}_id"]]
                    .dropna()
                    .rename(columns={f"{test_name}_id": "test_id"}))
        fig = plot_matched_pair(reference_df, test_df, pairs_df,
                                reference_name=reference_name, test_name=test_name,
                                columns=columns, show_ids=show_ids)
        if save_plot and plot_dir is not None:
            plot_dir.mkdir(parents=True, exist_ok=True)
            file_name = f"ref-{_safe_name(reference_name)}_test-{_safe_name(test_name)}.png"
            fig.savefig(plot_dir / file_name, dpi=200, facecolor="white", bbox_inches="tight")
        figures[test_name] = fig
    return figures


_SERIES_COLORS = ["#2a78d6", "#eb6834", "#1baf7a"]  # fixed order, validated for <= 3 series


def plot_stem_profile(
    summary_df: pd.DataFrame,
    reference_name: str = "Reference",
    min_pairs: int = 5,
) -> Figure:
    """Stem diameter differences vs. section height, one line per dataset.

    summary_df : output of stem_profile_summary (dataset, height, n, bias, rmse)
    min_pairs  : heights with fewer compared trees are not drawn

    Three panels share the height axis: bias [cm], RMSE [cm] and the number of
    compared trees per height.
    """
    datasets = list(dict.fromkeys(summary_df["dataset"]))
    if not (summary_df["n"] >= min_pairs).any():
        raise ValueError(f"No section height has at least {min_pairs} compared trees.")
    if len(datasets) > len(_SERIES_COLORS):
        raise ValueError(f"At most {len(_SERIES_COLORS)} datasets can be shown in one plot.")

    fig, axes = plt.subplots(1, 3, figsize=(11, 7), sharey=True, facecolor="white",
                             gridspec_kw={"width_ratios": [3, 3, 1.4]})
    panels = [("bias", "Bias [cm]"), ("rmse", "RMSE [cm]"), ("n", "Compared trees")]

    for dataset_name, color in zip(datasets, _SERIES_COLORS):
        rows = summary_df[(summary_df["dataset"] == dataset_name)
                          & (summary_df["n"] >= min_pairs)].sort_values("height")
        for ax, (column, _) in zip(axes, panels):
            ax.plot(rows[column], rows["height"], color=color, linewidth=2,
                    marker="o", markersize=3, label=dataset_name)

    axes[0].axvline(0, color=_TEXT_MUTED, linewidth=1, zorder=1)
    for ax, (_, label) in zip(axes, panels):
        ax.set_facecolor("white")
        ax.set_xlabel(label, color=_TEXT_MUTED)
        ax.grid(color=_GRID_COLOR, linewidth=0.6, zorder=0)
        ax.tick_params(colors=_TEXT_MUTED, labelsize=8)
        for spine in ax.spines.values():
            spine.set_color(_GRID_COLOR)
    axes[0].set_ylabel("Section height above ground [m]", color=_TEXT_MUTED)

    axes[0].set_title(f"Stem diameter differences vs {reference_name} (3DFin)", loc="left",
                      fontsize=12, color=_TEXT_PRIMARY, pad=20)
    axes[0].text(0, 1.01, f"test − reference per section · heights with ≥ {min_pairs} trees",
                 transform=axes[0].transAxes, fontsize=9, color=_TEXT_MUTED, va="bottom")
    axes[0].legend(loc="upper left", bbox_to_anchor=(0, -0.08), ncol=len(datasets),
                   frameon=False, fontsize=9, labelcolor=_TEXT_PRIMARY)
    fig.tight_layout()
    return fig
