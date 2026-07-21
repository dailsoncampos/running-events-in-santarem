"""Gold layer: business-level marts for event results, ready for consumption/reporting."""
import pandas as pd

from src.config import GOLD_DIR
from src.layers import silver
from src.logger import get_logger

logger = get_logger(__name__)

EVENT_SUMMARY_FILE = GOLD_DIR / "event_summary.parquet"
CATEGORY_PODIUM_FILE = GOLD_DIR / "category_podium.parquet"


def _event_summary(events: pd.DataFrame, runners: pd.DataFrame) -> pd.DataFrame:
    finishers = runners[runners["finish_time_seconds"].notna()]

    stats = (
        runners.groupby("event_id")
        .agg(total_runners=("bib_number", "count"))
        .reset_index()
    )
    finisher_stats = (
        finishers.groupby("event_id")
        .agg(
            finishers=("bib_number", "count"),
            avg_finish_time_seconds=("finish_time_seconds", "mean"),
        )
        .reset_index()
    )

    summary = events.merge(stats, on="event_id", how="left").merge(
        finisher_stats, on="event_id", how="left"
    )
    summary["total_runners"] = summary["total_runners"].fillna(0).astype(int)
    summary["finishers"] = summary["finishers"].fillna(0).astype(int)

    return summary[
        [
            "event_id",
            "name",
            "event_date",
            "city",
            "total_runners",
            "finishers",
            "avg_finish_time_seconds",
        ]
    ].sort_values("event_date")


def _category_podium(events: pd.DataFrame, runners: pd.DataFrame, top_n: int = 3) -> pd.DataFrame:
    finishers = runners[runners["finish_time_seconds"].notna()].copy()
    finishers["rank"] = finishers.groupby(["event_id", "category"])["position"].rank(
        method="first"
    )
    podium = finishers[finishers["rank"] <= top_n].sort_values(
        ["event_id", "category", "rank"]
    )
    event_names = events[["event_id", "name"]].rename(columns={"name": "event_name"})
    podium = podium.merge(event_names, on="event_id", how="left")

    return podium[
        [
            "event_id",
            "event_name",
            "category",
            "rank",
            "bib_number",
            "name",
            "finish_time_seconds",
        ]
    ]


def run() -> dict[str, pd.DataFrame]:
    logger.info(
        "Reading silver: %s, %s", silver.EVENTS_OUTPUT_FILE, silver.RUNNERS_OUTPUT_FILE
    )
    events = pd.read_parquet(silver.EVENTS_OUTPUT_FILE)
    runners = pd.read_parquet(silver.RUNNERS_OUTPUT_FILE)

    event_summary = _event_summary(events, runners)
    event_summary.to_parquet(EVENT_SUMMARY_FILE, index=False)
    logger.info("Wrote %d rows to gold: %s", len(event_summary), EVENT_SUMMARY_FILE)

    category_podium = _category_podium(events, runners)
    category_podium.to_parquet(CATEGORY_PODIUM_FILE, index=False)
    logger.info("Wrote %d rows to gold: %s", len(category_podium), CATEGORY_PODIUM_FILE)

    return {"event_summary": event_summary, "category_podium": category_podium}


if __name__ == "__main__":
    run()
