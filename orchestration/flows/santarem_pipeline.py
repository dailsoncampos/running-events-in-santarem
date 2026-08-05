"""Prefect flow chaining the two apps in this repo into one end-to-end run.

web-scraper (scrape CronoSantarém + upload events.csv/runners.csv to S3)
    -> etl-pipeline (bronze -> silver -> gold against that S3 data)

Each step shells out to that app's own `docker compose run`, the same
entrypoint a human already uses manually (see each app's README) — this
module doesn't reach into either app's internals or duplicate their config,
it only sequences their existing commands and surfaces failures/retries.
"""
import subprocess
from pathlib import Path

from prefect import flow, get_run_logger, task

REPO_ROOT = Path(__file__).resolve().parents[2]
WEB_SCRAPER_DIR = REPO_ROOT / "web-scraper"
ETL_PIPELINE_DIR = REPO_ROOT / "etl-pipeline"


def _run_compose(service: str, cwd: Path) -> None:
    logger = get_run_logger()
    logger.info("Running `docker compose run --rm %s` in %s", service, cwd)
    result = subprocess.run(
        ["docker", "compose", "run", "--rm", service],
        cwd=cwd,
        capture_output=True,
        text=True,
    )
    if result.stdout:
        logger.info(result.stdout)
    if result.returncode != 0:
        logger.error(result.stderr)
        raise RuntimeError(
            f"`docker compose run --rm {service}` failed in {cwd} "
            f"(exit code {result.returncode})"
        )


@task(name="scrape-and-upload", retries=1, retry_delay_seconds=60)
def scrape_and_upload() -> None:
    """Runs the web-scraper's `scrape:all`: scrape + parse + upload to S3."""
    _run_compose("scraper", WEB_SCRAPER_DIR)


@task(name="run-etl", retries=1, retry_delay_seconds=60)
def run_etl() -> None:
    """Runs the etl-pipeline's bronze -> silver -> gold stages."""
    _run_compose("etl", ETL_PIPELINE_DIR)


@flow(name="santarem-running-events-pipeline", log_prints=True)
def santarem_pipeline() -> None:
    scrape_and_upload()
    run_etl()


if __name__ == "__main__":
    santarem_pipeline()
