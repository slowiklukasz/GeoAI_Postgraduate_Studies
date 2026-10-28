"""Entry point: python run.py --config configs/config.yaml [--step <step>|all]"""

from __future__ import annotations

import argparse
import logging
import shutil

import pandas as pd

from pcbench.config import Config, load_config
from pcbench.loaders import (filter_region, load_3dfin_dir, load_3dfin_sections_dir,
                             load_arbor_dir, load_arbor_tree_list)
from pcbench.pipeline import (load_link_table, run_accuracy, run_detection_variants,
                              run_matching, run_stem_profiles)

STEPS = ("matching", "accuracy", "stem_profiles", "sensitivity")

logger = logging.getLogger("pcbench")


def load_arbor_inputs(
    config: Config, exclude_status: tuple[str, ...] | None = None,
) -> tuple[pd.DataFrame, dict[str, pd.DataFrame]]:
    """Reference trees and the Arbor results of all compared scanners.

    exclude_status overrides config.exclude_status (used by the sensitivity step).
    """
    statuses = config.exclude_status if exclude_status is None else exclude_status
    reference_df = load_arbor_tree_list(config.reference_csv, statuses, config.max_root_above_bh)
    tests_dfs = load_arbor_dir(config.arbor_csv_dir, statuses,
                               config.max_root_above_bh, skip=[config.reference_csv])
    reference_df = filter_region(reference_df, config.region)
    tests_dfs = {name: filter_region(df, config.region, buffer=config.max_dist)
                 for name, df in tests_dfs.items()}
    return reference_df, tests_dfs


def step_matching(config: Config) -> None:
    """Match Arbor and 3DFin results to the reference and save link tables and maps."""
    reference_df, arbor_dfs = load_arbor_inputs(config)
    logger.info("Reference %s: %d trees", config.reference_name, len(reference_df))

    threedfin_dfs = {name: filter_region(df, config.region, buffer=config.max_dist)
                     for name, df in load_3dfin_dir(config.threedfin_xlsx_dir).items()}
    runs = {"arbor": arbor_dfs, "3dfin": threedfin_dfs}
    for run_name, tests_dfs in runs.items():
        if not tests_dfs:
            logger.warning("No %s files found – skipping this matching run", run_name)
            continue
        _, summary_df, _ = run_matching(
            reference_df, tests_dfs,
            output_dir=config.output_dir / "matching" / run_name,
            reference_name=config.reference_name,
            max_dist=config.max_dist,
            duplicate_dist=config.duplicate_dist,
            save_plot=config.save_plot,
            show_ids=config.show_ids,
            region=config.region,
        )
        logger.info("Matching %s:\n%s", run_name, summary_df.round(3).to_string(index=False))


def selected_tree_ids(config: Config) -> tuple[int, ...] | None:
    """Reference IDs for the per-tree analyses, or None for all matched trees."""
    if config.tree_subset == "all":
        return None
    if not config.selected_trees:
        logger.warning("selected_trees is empty – using all matched trees")
        return None
    return config.selected_trees


def read_link_table(config: Config, run_name: str) -> pd.DataFrame:
    """Link table saved by the matching step for one run (arbor / 3dfin)."""
    link_path = config.output_dir / "matching" / run_name / "link_table.csv"
    if not link_path.exists():
        raise FileNotFoundError(f"{link_path} not found – run the matching step first")
    return load_link_table(link_path)


def step_accuracy(config: Config) -> None:
    """Bias and RMSE of Arbor parameters for matched trees, based on the saved link table."""
    reference_df, tests_dfs = load_arbor_inputs(config)
    _, summary_df = run_accuracy(
        reference_df, tests_dfs, read_link_table(config, "arbor"),
        output_dir=config.output_dir / "accuracy" / "arbor",
        parameters=config.accuracy_parameters,
        tree_ids=selected_tree_ids(config),
        outlier_dh=config.outlier_dh,
    )
    logger.info("Accuracy arbor:\n%s", summary_df.round(3).to_string(index=False))


def step_stem_profiles(config: Config) -> None:
    """Stem diameter differences per section height from 3DFin, vs. the 3DFin reference."""
    sections_dfs = load_3dfin_sections_dir(config.threedfin_xlsx_dir)
    if not sections_dfs:
        logger.warning("No 3DFin files found – skipping stem profiles")
        return
    _, summary_df = run_stem_profiles(
        sections_dfs, read_link_table(config, "3dfin"),
        reference_dataset=config.profile_reference,
        output_dir=config.output_dir / "stem_profiles",
        tree_ids=selected_tree_ids(config),
        min_pairs=config.profile_min_pairs,
        save_plot=config.save_plot,
        bands=config.profile_bands,
    )
    logger.info("Stem profiles: %d dataset(s), %d height sections",
                summary_df["dataset"].nunique(), summary_df["height"].nunique())


def step_sensitivity(config: Config) -> None:
    """Detection metrics of the Arbor results for the main filter and every sensitivity variant."""
    if not config.sensitivity:
        logger.warning("No arbor.sensitivity variants in the config – skipping sensitivity")
        return
    variants = {"main": config.exclude_status, **config.sensitivity}
    combined = run_detection_variants(
        {name: load_arbor_inputs(config, statuses) for name, statuses in variants.items()},
        output_dir=config.output_dir / "sensitivity",
        max_dist=config.max_dist,
        duplicate_dist=config.duplicate_dist,
        region=config.region,
    )
    columns = ["variant", "n_reference", "dataset", "TP", "FN", "FP", "FP_duplicate",
               "FP_extra", "precision", "recall", "F1"]
    logger.info("Detection variants:\n%s", combined[columns].round(3).to_string(index=False))


def main() -> None:
    parser = argparse.ArgumentParser(description="Compare tree results across laser scanners.")
    parser.add_argument("--config", required=True, help="path to the YAML config")
    parser.add_argument("--step", choices=(*STEPS, "all"), default="all",
                        help="which step to run (default: all)")
    args = parser.parse_args()

    logging.basicConfig(level=logging.INFO, format="%(levelname)s  %(message)s")
    config = load_config(args.config)
    config.output_dir.mkdir(parents=True, exist_ok=True)
    shutil.copy(config.source_path, config.output_dir / "config_used.yaml")

    if args.step in ("matching", "all"):
        step_matching(config)
    if args.step in ("accuracy", "all"):
        step_accuracy(config)
    if args.step in ("stem_profiles", "all"):
        step_stem_profiles(config)
    if args.step in ("sensitivity", "all"):
        step_sensitivity(config)


if __name__ == "__main__":
    main()
