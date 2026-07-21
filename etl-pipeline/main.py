import argparse

from src.pipeline import STAGES, run_pipeline


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Run the medallion ETL pipeline.")
    parser.add_argument(
        "--stages",
        nargs="+",
        choices=list(STAGES.keys()),
        default=None,
        help="Subset of stages to run, in order (default: all).",
    )
    return parser.parse_args()


if __name__ == "__main__":
    args = parse_args()
    run_pipeline(stages=args.stages)
