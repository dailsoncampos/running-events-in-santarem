"""Silver layer: clean, validate and conform bronze events/runners into typed records.

Mirrors the upsert keys the web-scraper app itself uses (see
web-scraper/lib/scraper/event_store.rb and runner_store.rb) so dedup here
stays consistent with how the source system treats identity:
  events:  unique by (name, event_date)
  runners: unique by (event_id, bib_number, name)
"""
import pandas as pd

from src.config import SILVER_DIR
from src.layers import bronze
from src.logger import get_logger

logger = get_logger(__name__)

EVENTS_OUTPUT_FILE = SILVER_DIR / "events.parquet"
RUNNERS_OUTPUT_FILE = SILVER_DIR / "runners.parquet"


def _duration_to_seconds(value: str) -> float | None:
    """Parse 'H:MM:SS' or 'M:SS' strings (finish_time / average_pace) to seconds."""
    if not isinstance(value, str) or not value.strip():
        return None
    parts = value.strip().split(":")
    try:
        parts = [int(p) for p in parts]
    except ValueError:
        return None
    if len(parts) == 3:
        h, m, s = parts
    elif len(parts) == 2:
        h, m, s = 0, parts[0], parts[1]
    else:
        return None
    return float(h * 3600 + m * 60 + s)


def _clean_events(df: pd.DataFrame) -> pd.DataFrame:
    before = len(df)
    df = df.dropna(subset=["id", "name", "event_date"])
    logger.info("events: dropped %d rows missing required fields", before - len(df))

    before = len(df)
    df = df.drop_duplicates(subset=["name", "event_date"])
    logger.info("events: dropped %d duplicate rows", before - len(df))

    df["id"] = df["id"].astype(int)
    df["event_date"] = pd.to_datetime(df["event_date"]).dt.date
    df["city"] = df["city"].str.strip()
    df["scraped_at"] = pd.to_datetime(df["scraped_at"], errors="coerce")

    return df[
        ["id", "name", "event_date", "city", "result_url", "clax_file_url", "scraped_at"]
    ].rename(columns={"id": "event_id"})


def _clean_runners(df: pd.DataFrame) -> pd.DataFrame:
    before = len(df)
    df = df.dropna(subset=["event_id", "name", "position"])
    logger.info("runners: dropped %d rows missing required fields", before - len(df))

    before = len(df)
    df = df.drop_duplicates(subset=["event_id", "bib_number", "name"])
    logger.info("runners: dropped %d duplicate rows", before - len(df))

    df["event_id"] = df["event_id"].astype(int)
    df["position"] = df["position"].astype(int)
    df["points"] = pd.to_numeric(df["points"], errors="coerce").astype("Int64")
    df["laps"] = pd.to_numeric(df["laps"], errors="coerce").astype("Int64")
    df["distance_m"] = pd.to_numeric(df["distance"], errors="coerce").astype("Int64")
    df["gender"] = df["gender"].str.upper().str.strip()
    df["category"] = df["category"].str.strip()
    df["club"] = df["club"].where(df["club"].notna() & (df["club"].str.strip() != ""))

    df["finish_time_seconds"] = df["finish_time"].apply(_duration_to_seconds)
    df["pace_seconds_per_km"] = df["average_pace"].apply(_duration_to_seconds)

    return df[
        [
            "event_id",
            "bib_number",
            "name",
            "club",
            "gender",
            "category",
            "position",
            "finish_time_seconds",
            "pace_seconds_per_km",
            "points",
            "laps",
            "distance_m",
        ]
    ]


def run() -> dict[str, pd.DataFrame]:
    logger.info("Reading bronze: %s, %s", bronze.EVENTS_OUTPUT_FILE, bronze.RUNNERS_OUTPUT_FILE)
    events = _clean_events(pd.read_parquet(bronze.EVENTS_OUTPUT_FILE))
    runners = _clean_runners(pd.read_parquet(bronze.RUNNERS_OUTPUT_FILE))

    events.to_parquet(EVENTS_OUTPUT_FILE, index=False)
    logger.info("Wrote %d rows to silver: %s", len(events), EVENTS_OUTPUT_FILE)

    runners.to_parquet(RUNNERS_OUTPUT_FILE, index=False)
    logger.info("Wrote %d rows to silver: %s", len(runners), RUNNERS_OUTPUT_FILE)

    return {"events": events, "runners": runners}


if __name__ == "__main__":
    run()
