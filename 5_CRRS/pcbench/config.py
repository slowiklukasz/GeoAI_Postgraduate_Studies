from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path
from typing import Any

import yaml


@dataclass(frozen=True)
class Config:
    """Analysis settings read from the YAML config."""

    source_path: Path
    reference_name: str
    reference_csv: Path
    arbor_csv_dir: Path
    threedfin_xlsx_dir: Path
    output_dir: Path
    exclude_status: tuple[str, ...]
    max_root_above_bh: float
    max_dist: float
    duplicate_dist: float
    save_plot: bool
    show_ids: bool
    selected_trees: tuple[int, ...]
    accuracy_parameters: tuple[str, ...]
    tree_subset: str
    profile_reference: str
    profile_min_pairs: int


def _get(section: dict[str, Any], key: str, where: str) -> Any:
    """Return section[key] or fail with a message naming the missing config key."""
    if key not in section:
        raise KeyError(f"Missing config key: {where}{key}")
    return section[key]


def load_config(path: str | Path) -> Config:
    """Load and validate the YAML config."""
    config_path = Path(path)
    with config_path.open(encoding="utf-8") as file:
        raw: dict[str, Any] = yaml.safe_load(file)

    reference = _get(raw, "reference", "")
    inputs = _get(raw, "inputs", "")
    arbor = _get(raw, "arbor", "")
    matching = _get(raw, "matching", "")
    accuracy = _get(raw, "accuracy", "")
    stem_profiles = _get(raw, "stem_profiles", "")

    tree_subset = str(_get(accuracy, "tree_subset", "accuracy."))
    if tree_subset not in ("selected", "all"):
        raise ValueError("accuracy.tree_subset must be 'selected' or 'all'")

    return Config(
        source_path=config_path,
        reference_name=str(_get(reference, "name", "reference.")),
        reference_csv=Path(_get(reference, "csv", "reference.")),
        arbor_csv_dir=Path(_get(inputs, "arbor_csv_dir", "inputs.")),
        threedfin_xlsx_dir=Path(_get(inputs, "threedfin_xlsx_dir", "inputs.")),
        output_dir=Path(_get(raw, "output_dir", "")),
        exclude_status=tuple(_get(arbor, "exclude_status", "arbor.")),
        max_root_above_bh=float(_get(arbor, "max_root_above_bh", "arbor.")),
        max_dist=float(_get(matching, "max_dist", "matching.")),
        duplicate_dist=float(_get(matching, "duplicate_dist", "matching.")),
        save_plot=bool(_get(matching, "save_plot", "matching.")),
        show_ids=bool(_get(matching, "show_ids", "matching.")),
        selected_trees=tuple(int(tree_id) for tree_id in raw.get("selected_trees") or []),
        accuracy_parameters=tuple(_get(accuracy, "parameters", "accuracy.")),
        tree_subset=tree_subset,
        profile_reference=str(_get(stem_profiles, "reference_dataset", "stem_profiles.")),
        profile_min_pairs=int(_get(stem_profiles, "min_pairs", "stem_profiles.")),
    )
