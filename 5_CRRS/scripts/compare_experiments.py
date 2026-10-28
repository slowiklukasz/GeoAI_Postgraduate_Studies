"""Compare analysis packages and evaluate the tests of docs/analysis_plan.md.

python scripts/compare_experiments.py [--experiments-dir experiments] [--out experiments/comparison]

Every folder in experiments/ with a config.yaml is one package (except _template and
comparison). The script reads the outputs written by run.py for each package, collects
them into common tables and evaluates every sanity check and test of the analysis plan
per package. If a package has a tests.csv written by the analyst agent, its
verdicts are compared with the automatic ones.

Outputs (in --out):
    experiments.csv          one row per package (metadata from the config `experiment` block)
    detection.csv            detection metrics per package, tool and dataset (main filter)
    detection_variants.csv   detection metrics per package and filter variant (sensitivity step)
    accuracy.csv             bias / RMSE / z per package, scanner and parameter (Arbor)
    stem_profile_bands.csv   band biases and stem reach per package and scanner (3DFin)
    tests.csv                per test and package: automatic status, agent status, agreement
    tests_matrix.csv         test x package table of automatic statuses
"""

from __future__ import annotations

import argparse
import sys
from collections.abc import Callable
from dataclasses import dataclass
from pathlib import Path
from typing import Any

import pandas as pd
import yaml

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from pcbench.config import load_config  # noqa: E402

EXCLUDED_FOLDERS = {"_template", "comparison"}
SCANNER_ALIASES = {  # canonical scanner name -> substrings found in dataset names
    "GeoSLAM": ("geoslam", "geomslam"),
    "LiGrip": ("ligrip",),
    "low_cost": ("low_cost", "lowcost", "low-cost"),
}
HLS = tuple(SCANNER_ALIASES)

CONFIRMED, INCONCLUSIVE, NOT_CONFIRMED, NO_DATA = (
    "confirmed", "inconclusive", "not_confirmed", "no_data")
Z_LIMIT = 2.0          # |z| >= 2: clearly non-zero bias
MIN_N = 5              # fewer pairs: no_data
LOW_N = 10             # fewer pairs: status allowed, low confidence
RECALL_MIN = 0.95      # D1
DUPLICATE_RATE_MIN = 0.05  # D2
ROBUST_H_BIAS_MAX = 0.5    # A6 [m]
DBH_SHARE_MAX = 0.5        # A4
MATCH_DIST_MAX = 0.2       # I1 [m], median matched distance
TLS_3DFIN_RECALL_MIN = 0.9  # I3
BREAST_HEIGHT = 1.3        # C1 [m]


def canonical_scanner(dataset: str) -> str | None:
    """Canonical HLS name for a dataset name, or None (e.g. TLS)."""
    name = dataset.lower()
    for scanner, aliases in SCANNER_ALIASES.items():
        if any(alias in name for alias in aliases):
            return scanner
    return None


def _read(path: Path) -> pd.DataFrame:
    return pd.read_csv(path) if path.exists() else pd.DataFrame()


def _with_scanner(frame: pd.DataFrame) -> pd.DataFrame:
    if frame.empty or "dataset" not in frame:
        return frame
    return frame.assign(scanner=frame["dataset"].map(canonical_scanner))


@dataclass
class Package:
    """Outputs of one analysis package."""

    name: str
    meta: dict[str, Any]
    detection: pd.DataFrame         # main filter, both tools (column `tool`)
    variants: pd.DataFrame          # sensitivity step
    link: dict[str, pd.DataFrame]   # link tables per tool
    accuracy: pd.DataFrame
    accuracy_robust: pd.DataFrame
    profile: pd.DataFrame
    bands: pd.DataFrame
    profile_reference: str
    agent_tests: pd.DataFrame | None


def load_package(folder: Path) -> Package:
    config_path = folder / "config.yaml"
    config = load_config(config_path)
    with config_path.open(encoding="utf-8") as file:
        meta = (yaml.safe_load(file) or {}).get("experiment") or {}
    out = config.output_dir

    detection_frames, links = [], {}
    for tool in ("arbor", "3dfin"):
        frame = _read(out / "matching" / tool / "detection_summary.csv")
        if not frame.empty:
            detection_frames.append(frame.assign(tool=tool))
        links[tool] = _read(out / "matching" / tool / "link_table.csv")
    agent_path = folder / "tests.csv"
    return Package(
        name=folder.name,
        meta=meta,
        detection=_with_scanner(pd.concat(detection_frames, ignore_index=True)
                                if detection_frames else pd.DataFrame()),
        variants=_with_scanner(_read(out / "sensitivity" / "detection_variants.csv")),
        link=links,
        accuracy=_with_scanner(_read(out / "accuracy" / "arbor" / "accuracy_summary.csv")),
        accuracy_robust=_with_scanner(
            _read(out / "accuracy" / "arbor" / "accuracy_summary_no_outliers.csv")),
        profile=_with_scanner(_read(out / "stem_profiles" / "stem_profile_summary.csv")),
        bands=_with_scanner(_read(out / "stem_profiles" / "stem_profile_bands.csv")),
        profile_reference=config.profile_reference,
        agent_tests=pd.read_csv(agent_path) if agent_path.exists() else None,
    )


# ---------------------------------------------------------------- lookups

def _row(frame: pd.DataFrame, scanner: str, **filters: Any) -> pd.Series | None:
    if frame.empty or "scanner" not in frame:
        return None
    rows = frame[frame["scanner"] == scanner]
    for key, value in filters.items():
        rows = rows[rows[key] == value]
    return rows.iloc[0] if len(rows) else None


def _per_scanner(frame: pd.DataFrame, column: str, **filters: Any) -> dict[str, float] | None:
    """Value per HLS scanner, or None if any scanner is missing."""
    values = {}
    for scanner in HLS:
        row = _row(frame, scanner, **filters)
        if row is None or pd.isna(row[column]):
            return None
        values[scanner] = float(row[column])
    return values


def _fmt(values: dict[str, float], unit: str = "", digits: int = 2, signed: bool = True) -> str:
    sign = "+" if signed else ""
    return ", ".join(f"{s}={v:{sign}.{digits}f}{unit}" for s, v in values.items())


Result = tuple[str, str]


def _bias_test(row: pd.Series | None, direction: int, label: str, unit: str) -> Result:
    """direction +1: bias > 0 expected, -1: bias < 0 expected."""
    if row is None or row["n"] < MIN_N or pd.isna(row["z"]):
        return NO_DATA, ""
    bias, z = float(row["bias"]), float(row["z"])
    evidence = f"{label}={bias:+.2f} {unit}, z={z:+.1f}, n={int(row['n'])}"
    if row["n"] < LOW_N:
        evidence += " (low n)"
    if bias * direction > 0:
        return (CONFIRMED if abs(z) >= Z_LIMIT else INCONCLUSIVE), evidence
    return NOT_CONFIRMED, evidence


# ---------------------------------------------------------------- sanity checks

def check_i1(p: Package) -> Result:
    medians = {}
    for tool, link in p.link.items():
        for column in [c for c in link.columns if c.endswith("_dist")]:
            values = link[column].dropna()
            if len(values):
                medians[f"{tool}:{column.removesuffix('_dist')}"] = float(values.median())
    if not medians:
        return NO_DATA, ""
    ok = max(medians.values()) < MATCH_DIST_MAX
    return (CONFIRMED if ok else NOT_CONFIRMED), _fmt(medians, " m", signed=False)


def check_i2(p: Package) -> Result:
    if p.detection.empty:
        return NO_DATA, ""
    found = {tool: set(p.detection.loc[p.detection["tool"] == tool, "scanner"].dropna())
             for tool in ("arbor", "3dfin")}
    tls_3dfin = p.profile_reference in set(p.detection.loc[p.detection["tool"] == "3dfin", "dataset"])
    ok = all(set(HLS) <= found[t] for t in found) and tls_3dfin
    evidence = f"arbor={sorted(found['arbor'])}, 3dfin={sorted(found['3dfin'])}, 3dfin TLS={tls_3dfin}"
    return (CONFIRMED if ok else NOT_CONFIRMED), evidence


def check_i3(p: Package) -> Result:
    if p.detection.empty:
        return NO_DATA, ""
    rows = p.detection[(p.detection["tool"] == "3dfin")
                       & (p.detection["dataset"] == p.profile_reference)]
    if rows.empty:
        return NO_DATA, ""
    recall = float(rows["recall"].iloc[0])
    return (CONFIRMED if recall >= TLS_3DFIN_RECALL_MIN else NOT_CONFIRMED), f"recall={recall:.2f}"


# ---------------------------------------------------------------- tests

def _arbor(p: Package) -> pd.DataFrame:
    return p.detection[p.detection["tool"] == "arbor"] if not p.detection.empty else p.detection


def check_d1(p: Package) -> Result:
    v = _per_scanner(_arbor(p), "recall")
    if v is None:
        return NO_DATA, ""
    return (CONFIRMED if min(v.values()) >= RECALL_MIN else NOT_CONFIRMED), _fmt(v, signed=False)


def check_d2(p: Package) -> Result:
    dup, tp, fn = (_per_scanner(_arbor(p), c) for c in ("FP_duplicate", "TP", "FN"))
    if dup is None or tp is None or fn is None:
        return NO_DATA, ""
    n_reference = tp["GeoSLAM"] + fn["GeoSLAM"]
    if not n_reference:
        return NO_DATA, ""
    rate = {s: dup[s] / n_reference for s in HLS}
    ok = rate["LiGrip"] > max(rate[s] for s in HLS if s != "LiGrip") and rate["LiGrip"] >= DUPLICATE_RATE_MIN
    return (CONFIRMED if ok else NOT_CONFIRMED), _fmt(rate, " per tree", 3, signed=False)


def check_a1(p: Package) -> Result:
    return _bias_test(_row(p.accuracy, "low_cost", parameter="dbh"), +1, "low_cost DBH", "cm")


def check_a2(p: Package) -> Result:
    return _bias_test(_row(p.accuracy, "LiGrip", parameter="dbh"), -1, "LiGrip DBH", "cm")


def check_a3(p: Package) -> Result:
    row = _row(p.accuracy, "GeoSLAM", parameter="dbh")
    if row is None or row["n"] < MIN_N or pd.isna(row["z"]):
        return NO_DATA, ""
    z = float(row["z"])
    evidence = f"GeoSLAM DBH={float(row['bias']):+.2f} cm, z={z:+.1f}, n={int(row['n'])}"
    return (CONFIRMED if abs(z) < Z_LIMIT else NOT_CONFIRMED), evidence


def check_a4(p: Package) -> Result:
    n_dbh = _per_scanner(p.accuracy, "n", parameter="dbh")
    n_h = _per_scanner(p.accuracy, "n", parameter="h")
    if n_dbh is None or n_h is None:
        return NO_DATA, ""
    share = {s: n_dbh[s] / n_h[s] for s in HLS if n_h[s]}
    ok = min(share, key=lambda s: share[s]) == "LiGrip" and share["LiGrip"] < DBH_SHARE_MAX
    return (CONFIRMED if ok else NOT_CONFIRMED), _fmt(share, digits=2, signed=False)


def check_a5(p: Package) -> Result:
    rows = {s: _row(p.accuracy, s, parameter="h") for s in ("GeoSLAM", "low_cost")}
    if any(r is None or pd.isna(r["z"]) for r in rows.values()):
        return NO_DATA, ""
    z = {s: float(r["z"]) for s, r in rows.items() if r is not None}
    return (CONFIRMED if all(abs(v) < Z_LIMIT for v in z.values()) else NOT_CONFIRMED), \
        "z: " + _fmt(z, digits=1)


def check_a6(p: Package) -> Result:
    row = _row(p.accuracy_robust, "LiGrip", parameter="h")
    if row is None or row["n"] < MIN_N:
        return NO_DATA, ""
    bias = float(row["bias"])
    evidence = f"LiGrip H without outlier pairs={bias:+.2f} m, n={int(row['n'])}"
    return (CONFIRMED if abs(bias) < ROBUST_H_BIAS_MAX else NOT_CONFIRMED), evidence


def check_a7(p: Package) -> Result:
    v = _per_scanner(p.accuracy, "bias", parameter="xy_offset")
    if v is None:
        return NO_DATA, ""
    return (CONFIRMED if v["LiGrip"] >= max(v.values()) else NOT_CONFIRMED), _fmt(v, " m", signed=False)


def _band(p: Package, scanner: str, band: str) -> float | None:
    row = _row(p.bands, scanner, band=band)
    if row is None:
        return None
    value = row["max_height" if band == "reach" else "mean_bias"]
    return None if pd.isna(value) else float(value)


def check_s1(p: Package) -> Result:
    low, high = _band(p, "low_cost", "lower"), _band(p, "low_cost", "upper")
    if low is None or high is None:
        return NO_DATA, ""
    return (CONFIRMED if 0 < low < high else NOT_CONFIRMED), \
        f"low_cost lower={low:+.2f}, upper={high:+.2f} cm"


def check_s2(p: Package) -> Result:
    low, high = _band(p, "LiGrip", "lower"), _band(p, "LiGrip", "upper")
    if low is None or high is None:
        return NO_DATA, ""
    return (CONFIRMED if low < 0 and high < 0 else NOT_CONFIRMED), \
        f"LiGrip lower={low:+.2f}, upper={high:+.2f} cm"


def check_s3(p: Package) -> Result:
    values = {s: _band(p, s, "all") for s in HLS}
    if any(v is None for v in values.values()):
        return NO_DATA, ""
    v = {s: float(x) for s, x in values.items() if x is not None}
    return (CONFIRMED if min(v, key=lambda s: abs(v[s])) == "GeoSLAM" else NOT_CONFIRMED), _fmt(v, " cm")


def check_s4(p: Package) -> Result:
    values = {s: _band(p, s, "reach") for s in HLS}
    if any(v is None for v in values.values()):
        return NO_DATA, ""
    r = {s: float(x) for s, x in values.items() if x is not None}
    ok = r["GeoSLAM"] >= r["low_cost"] >= r["LiGrip"]
    return (CONFIRMED if ok else NOT_CONFIRMED), _fmt(r, " m", 1, signed=False)


def check_c1(p: Package) -> Result:
    parts, ok = [], True
    for scanner in ("LiGrip", "low_cost"):
        arbor = _row(p.accuracy, scanner, parameter="dbh")
        fin = _row(p.profile, scanner, height=BREAST_HEIGHT)
        if arbor is None or fin is None:
            return NO_DATA, ""
        a, f = float(arbor["bias"]), float(fin["bias"])
        ok = ok and (a > 0) == (f > 0)
        parts.append(f"{scanner}: Arbor {a:+.2f} / 3DFin {f:+.2f} cm")
    return (CONFIRMED if ok else NOT_CONFIRMED), "; ".join(parts)


CHECKS: dict[str, Callable[[Package], Result]] = {
    "I1": check_i1, "I2": check_i2, "I3": check_i3,
    "D1": check_d1, "D2": check_d2,
    "A1": check_a1, "A2": check_a2, "A3": check_a3, "A4": check_a4, "A5": check_a5,
    "A6": check_a6, "A7": check_a7,
    "S1": check_s1, "S2": check_s2, "S3": check_s3, "S4": check_s4,
    "C1": check_c1,
}


# ---------------------------------------------------------------- main

def _stack(frames: list[pd.DataFrame]) -> pd.DataFrame:
    frames = [f for f in frames if not f.empty]
    return pd.concat(frames, ignore_index=True) if frames else pd.DataFrame()


def main() -> None:
    parser = argparse.ArgumentParser(description="Compare analysis packages.")
    parser.add_argument("--experiments-dir", default="experiments")
    parser.add_argument("--out", default="experiments/comparison")
    args = parser.parse_args()

    folders = sorted(f for f in Path(args.experiments_dir).iterdir()
                     if f.is_dir() and f.name not in EXCLUDED_FOLDERS and (f / "config.yaml").exists())
    if not folders:
        raise SystemExit(f"No packages with config.yaml in {args.experiments_dir}")
    packages = [load_package(f) for f in folders]
    out = Path(args.out)
    out.mkdir(parents=True, exist_ok=True)

    pd.DataFrame([{"package": p.name, **p.meta} for p in packages]).to_csv(
        out / "experiments.csv", index=False)
    _stack([p.detection.assign(package=p.name) for p in packages]).to_csv(
        out / "detection.csv", index=False)
    _stack([p.variants.assign(package=p.name) for p in packages]).to_csv(
        out / "detection_variants.csv", index=False)
    _stack([p.accuracy.assign(package=p.name) for p in packages]).to_csv(
        out / "accuracy.csv", index=False)
    _stack([p.bands.assign(package=p.name) for p in packages]).to_csv(
        out / "stem_profile_bands.csv", index=False)

    rows = []
    for p in packages:
        agent = p.agent_tests
        for test_id, check in CHECKS.items():
            status, evidence = check(p)
            agent_status = ""
            if agent is not None and "test" in agent:
                match = agent[agent["test"] == test_id]
                agent_status = str(match["status"].iloc[0]) if len(match) else ""
            agreement = ""
            if agent_status and status != NO_DATA and agent_status != "not_assessed":
                agreement = "yes" if agent_status == status else "NO"
            rows.append({"test": test_id, "package": p.name, "auto_status": status,
                         "agent_status": agent_status, "agreement": agreement,
                         "evidence": evidence})
    tests = pd.DataFrame(rows)
    tests.to_csv(out / "tests.csv", index=False)
    matrix = tests.pivot(index="test", columns="package", values="auto_status").loc[list(CHECKS)]
    matrix.to_csv(out / "tests_matrix.csv")

    print(matrix.to_string())
    disagreements = tests[tests["agreement"] == "NO"]
    if len(disagreements):
        print("\nAgent verdicts that disagree with the automatic checks:")
        print(disagreements[["test", "package", "auto_status", "agent_status"]].to_string(index=False))


if __name__ == "__main__":
    main()
