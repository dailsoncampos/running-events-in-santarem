"""Bronze layer: ingest raw events/runners data as-is, tagged with ingestion metadata.

Source is s3://S3_BUCKET/{S3_EVENTS_KEY,S3_RUNNERS_KEY} when S3_BUCKET is
configured, otherwise falls back to the local RAW_DIR files (used by tests
and quick local runs so no AWS access is required). These mirror the
`events.csv` and `runners.csv` files produced by the web-scraper app.
"""
import io
from datetime import datetime, timezone

import boto3
import pandas as pd
from botocore.exceptions import BotoCoreError, ClientError

from src.config import (
    AWS_REGION,
    BRONZE_DIR,
    EVENTS_SOURCE_FILE,
    RAW_DIR,
    RUNNERS_SOURCE_FILE,
    S3_BUCKET,
    S3_ENDPOINT_URL,
    S3_EVENTS_KEY,
    S3_RUNNERS_KEY,
)
from src.logger import get_logger

logger = get_logger(__name__)

EVENTS_OUTPUT_FILE = BRONZE_DIR / "events.parquet"
RUNNERS_OUTPUT_FILE = BRONZE_DIR / "runners.parquet"


def _read_from_s3(key: str) -> pd.DataFrame:
    logger.info("Reading raw source from s3://%s/%s", S3_BUCKET, key)
    client = boto3.client("s3", region_name=AWS_REGION, endpoint_url=S3_ENDPOINT_URL)
    try:
        obj = client.get_object(Bucket=S3_BUCKET, Key=key)
        return pd.read_csv(io.BytesIO(obj["Body"].read()), dtype=str)
    except (ClientError, BotoCoreError):
        logger.exception("Failed to read s3://%s/%s", S3_BUCKET, key)
        raise


def _read_from_local(filename: str) -> pd.DataFrame:
    source_path = RAW_DIR / filename
    logger.info("Reading raw source from local file: %s", source_path)
    return pd.read_csv(source_path, dtype=str)


def _ingest(local_filename: str, s3_key: str, output_file) -> pd.DataFrame:
    if S3_BUCKET:
        df = _read_from_s3(s3_key)
        source_label = f"s3://{S3_BUCKET}/{s3_key}"
    else:
        df = _read_from_local(local_filename)
        source_label = str(RAW_DIR / local_filename)

    df["_source_file"] = source_label
    df["_ingested_at"] = datetime.now(timezone.utc).isoformat()

    df.to_parquet(output_file, index=False)
    logger.info("Wrote %d rows to bronze: %s", len(df), output_file)
    return df


def run() -> dict[str, pd.DataFrame]:
    events = _ingest(EVENTS_SOURCE_FILE, S3_EVENTS_KEY, EVENTS_OUTPUT_FILE)
    runners = _ingest(RUNNERS_SOURCE_FILE, S3_RUNNERS_KEY, RUNNERS_OUTPUT_FILE)
    return {"events": events, "runners": runners}


if __name__ == "__main__":
    run()
