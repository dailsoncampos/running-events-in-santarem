"""Daily check: run the pipeline if today is 1 day after the next scheduled event.

Designed to be called by a system cron (e.g. `0 3 * * *`). On days that are
not pipeline days the script exits cleanly without doing anything.
"""
import logging
from datetime import date, timedelta

from flows.santarem_pipeline import santarem_pipeline
from next_event import next_event_date

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s %(levelname)s %(message)s",
)
logger = logging.getLogger(__name__)


def main(today: date | None = None) -> None:
    today = today or date.today()
    event_date = next_event_date(today=today)

    if event_date is None:
        logger.warning("Could not determine next event date — skipping run")
        return

    run_date = event_date + timedelta(days=1)
    logger.info(
        "Next event: %s | Pipeline runs: %s | Today: %s",
        event_date, run_date, today,
    )

    if today != run_date:
        logger.info("Not a pipeline day — nothing to do")
        return

    logger.info("Pipeline day — starting run")
    santarem_pipeline()


if __name__ == "__main__":
    main()
