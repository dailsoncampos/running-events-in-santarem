# etl-pipeline

A Python ETL pipeline using the **medallion architecture** (bronze → silver → gold), containerized with Docker.

Processes race-results data collected by the `web-scraper` (Rails) app in this repo — [CronoSantarém](https://www.cronosantarem.com.br) running events and their finisher results — after that app exports its `events` and `runners` tables to S3.

## Architecture

```
s3://S3_BUCKET/{S3_EVENTS_KEY,S3_RUNNERS_KEY}
  (falls back to data/raw/{events,runners}.csv if S3_BUCKET is unset)
        │
        ▼
   ┌─────────┐   raw ingestion + metadata (_source_file, _ingested_at)
   │ BRONZE  │   src/layers/bronze.py -> data/bronze/{events,runners}.parquet
   └────┬────┘
        │
        ▼
   ┌─────────┐   dedupe, drop invalid rows, type casting, HH:MM:SS -> seconds
   │ SILVER  │   src/layers/silver.py -> data/silver/{events,runners}.parquet
   └────┬────┘
        │
        ▼
   ┌─────────┐   business marts
   │  GOLD   │   src/layers/gold.py -> data/gold/event_summary.parquet
   └─────────┘                        data/gold/category_podium.parquet
```

Each layer reads only from the layer before it and is independently re-runnable.

### Source schema

Bronze expects one CSV row per record from the Rails app's tables (see `web-scraper/db/schema.rb`):

- **events**: `id, name, event_date, city, result_url, clax_file_url, scraped_at, created_at, updated_at`
- **runners**: `id, event_id, position, bib_number, name, club, gender, category, finish_time, average_pace, points, laps, best_lap, distance, created_at, updated_at`

`finish_time` and `average_pace` are free-text `H:MM:SS`/`M:SS` strings in the source (that's how the scraper's CLAX parser writes them); silver converts both to numeric seconds (`finish_time_seconds`, `pace_seconds_per_km`). Silver dedup keys mirror the upsert keys the Rails app itself uses: events by `(name, event_date)`, runners by `(event_id, bib_number, name)`.

## Project structure

```
etl-pipeline/
├── main.py                # CLI entrypoint
├── src/
│   ├── config.py          # paths & env-driven settings
│   ├── logger.py          # shared logging setup
│   ├── pipeline.py         # orchestrates bronze -> silver -> gold
│   └── layers/
│       ├── bronze.py
│       ├── silver.py
│       └── gold.py
├── data/
│   ├── raw/                # local fallback source (checked in; unused when S3_BUCKET is set)
│   ├── bronze/             # generated, gitignored
│   ├── silver/             # generated, gitignored
│   └── gold/                # generated, gitignored
├── tests/                  # pytest, one file per layer
├── Dockerfile
├── docker-compose.yml
└── requirements.txt
```

## Run locally

```bash
cd etl-pipeline
python -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt
cp .env.example .env

python main.py                          # run all stages
python main.py --stages bronze silver   # run a subset
```

## Run with Docker

```bash
cd etl-pipeline
cp .env.example .env
docker compose build
docker compose run --rm etl
```

Outputs land in `./data/{bronze,silver,gold}` on the host via the mounted volume; logs land in `./logs/etl.log`.

## S3 source

The bronze layer (`src/layers/bronze.py`) reads `s3://S3_BUCKET/S3_EVENTS_KEY` and `s3://S3_BUCKET/S3_RUNNERS_KEY` whenever `S3_BUCKET` is set in `.env`; otherwise it falls back to the local `data/raw/{events,runners}.csv` samples (this is what tests and a bare `docker compose run` use, so no AWS access is required to try the pipeline).

To point it at a real bucket:

```bash
# .env
S3_BUCKET=my-running-events-in-santarem-bucket
S3_EVENTS_KEY=raw/events.csv
S3_RUNNERS_KEY=raw/runners.csv
AWS_REGION=us-east-1
```

Credentials are resolved through boto3's normal chain — nothing is hardcoded in the code:
- **Local dev**: either set `AWS_ACCESS_KEY_ID`/`AWS_SECRET_ACCESS_KEY` in `.env`, or mount your `~/.aws` profile by uncommenting the volume line in `docker-compose.yml`.
- **Production (ECS/EC2/EKS)**: attach an IAM role/task role with `s3:GetObject` (and `s3:ListBucket` if you later add prefix listing) on the bucket — no keys needed at all.

`S3_ENDPOINT_URL` is available for pointing at LocalStack/MinIO during local testing.

The `web-scraper` app uploads `data/events.csv` and `data/runners.csv` to the same `S3_EVENTS_KEY`/`S3_RUNNERS_KEY` whenever it has `S3_BUCKET` set (see `web-scraper/README.md`'s "S3 export" section) — that's the other half of this integration.

## Tests

```bash
pip install pytest
pytest
```

## Extending

- **New source field**: add it to the relevant CSV shape, then thread it through `bronze.py` (pass-through) and `silver.py` (typing/cleaning).
- **New transform**: add logic to `src/layers/silver.py`; keep bronze immutable/raw.
- **New aggregate**: add a function to `src/layers/gold.py` following the existing pattern (e.g. per-runner personal bests across events, club leaderboards).
- **Scheduling**: run `docker compose run --rm etl` from cron, or wrap `main.py` in Airflow/Prefect if orchestration needs grow beyond a single container.
