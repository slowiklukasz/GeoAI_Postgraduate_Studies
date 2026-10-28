# scanner-benchmark – instructions for Claude

## Project
Compares tree detection and tree measurements of three handheld laser scanners (GeoSLAM Horizon,
LiGrip, low-cost) with TLS (Trimble X7) on one forest plot with dense understorey.
Inputs: Arbor tree lists (CSV) and 3DFin outputs (XLSX). Tree positions of all clouds share one
coordinate system. The reference is TLS – a relative reference, not ground truth: report
"differences from TLS", never "errors".

## How the repo is used
- `pcbench/` – library (loaders, matching, accuracy, plotting, pipeline). Stable code.
- `run.py --config <config.yaml>` – runs matching, accuracy, stem profiles and filter sensitivity.
- `select_trees.py` – proposes trees for `selected_trees`.
- `experiments/<ID>_<name>/` – one analysis package: `config.yaml`, input data, `outputs/`,
  `report.md`, `tests.csv`. `experiments/_template/` is the starting point.
- `scripts/compare_experiments.py` – collects all packages, evaluates the tests automatically,
  writes `experiments/comparison/`.

## Documentation (`docs/`)
| File | Content | Changes when |
|---|---|---|
| `methods.md` | what each step computes, config keys, outputs | the code changes |
| `interpretation.md` | how to read each output, patterns and pitfalls | new patterns recur |
| `analysis_plan.md` | tests, decision rules, predictions – frozen | never after freezing (new tests only) |
| `analysis_protocol.md` | procedure for one package | the procedure changes |
| `output_schema.md` | format of report.md, tests.csv, comparison report | the format changes |
| `experiment_plan.md` | packages and what stays constant | a package is added |
| `examples/report_example.md` | example report (depth and tone) | – |
| `analysis_guide.md`, `.xlsx` | guide for people: workflow, steps, metrics, patterns, tests | together with the files above |
| `pl/` | auxiliary Polish version of the guide | together with the guide |

## Rules
- Do not modify `pcbench/`, `run.py`, `scripts/`, `docs/` or another package's files during an
  analysis. If the code seems wrong, stop and describe the problem.
- Every number in a report comes from an output file of the package (name it) or from a command
  quoted in the report appendix. Never estimate numbers in text.
- Separate results from interpretation; causes are hypotheses unless checked on the point clouds.
- Inspect real input files before assuming formats. Known formats: `docs/methods.md`, `README.md`.
- Follow `docs/output_schema.md` exactly so packages can be compared.
- Everything in English; Polish only in the auxiliary guide `docs/pl/`.
- Run commands from the repo root.

## Workflow for packages
1. Package analysis: `experiment-analyst` subagent, one per package; several can run in parallel.
   Pass the package folder, e.g. `experiments/P01_clip_rf02`.
2. Comparison: `experiment-comparer` subagent after all packages have `report.md` and `tests.csv`.

@docs/experiment_plan.md
