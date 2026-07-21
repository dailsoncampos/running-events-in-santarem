import os
from pathlib import Path

from dotenv import load_dotenv

load_dotenv()

DATA_DIR = Path(os.getenv("DATA_DIR", "./data")).resolve()
LOG_DIR = Path(os.getenv("LOG_DIR", "./logs")).resolve()
LOG_LEVEL = os.getenv("LOG_LEVEL", "INFO")

RAW_DIR = DATA_DIR / "raw"
BRONZE_DIR = DATA_DIR / "bronze"
SILVER_DIR = DATA_DIR / "silver"
GOLD_DIR = DATA_DIR / "gold"

# Source files exported by the web-scraper (Rails) app: one row per
# `events` record and one row per `runners` record (see web-scraper/db/schema.rb).
EVENTS_SOURCE_FILE = os.getenv("EVENTS_SOURCE_FILE", "events.csv")
RUNNERS_SOURCE_FILE = os.getenv("RUNNERS_SOURCE_FILE", "runners.csv")

# S3 source for the bronze layer. When S3_BUCKET is set, bronze reads
# s3://S3_BUCKET/S3_EVENTS_KEY and s3://S3_BUCKET/S3_RUNNERS_KEY instead of the
# local RAW_DIR files. Credentials are resolved through boto3's default chain
# (env vars set below, ~/.aws/credentials, or an IAM role) — never hardcode
# keys in this file.
S3_BUCKET = os.getenv("S3_BUCKET", "")
S3_EVENTS_KEY = os.getenv("S3_EVENTS_KEY", f"raw/{EVENTS_SOURCE_FILE}")
S3_RUNNERS_KEY = os.getenv("S3_RUNNERS_KEY", f"raw/{RUNNERS_SOURCE_FILE}")
AWS_REGION = os.getenv("AWS_REGION", "us-east-1")
S3_ENDPOINT_URL = os.getenv("S3_ENDPOINT_URL") or None  # for LocalStack/MinIO

for path in (RAW_DIR, BRONZE_DIR, SILVER_DIR, GOLD_DIR, LOG_DIR):
    path.mkdir(parents=True, exist_ok=True)
