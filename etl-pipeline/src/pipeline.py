"""Orchestrates the medallion pipeline: bronze -> silver -> gold."""
from src.layers import bronze, gold, silver
from src.logger import get_logger

logger = get_logger(__name__)

STAGES = {
    "bronze": bronze.run,
    "silver": silver.run,
    "gold": gold.run,
}


def run_pipeline(stages: list[str] | None = None) -> None:
    stages = stages or list(STAGES.keys())
    logger.info("Starting pipeline run: stages=%s", stages)

    for stage in stages:
        if stage not in STAGES:
            raise ValueError(f"Unknown stage '{stage}', must be one of {list(STAGES)}")
        logger.info("Running stage: %s", stage)
        try:
            STAGES[stage]()
        except Exception:
            logger.exception("Stage '%s' failed", stage)
            raise

    logger.info("Pipeline run complete")
