# orchestration

Runs the two apps in this repo as one end-to-end pipeline, using
[Prefect](https://docs.prefect.io/) as a lightweight orchestrator:

```
web-scraper (scrape + parse .clax + upload events.csv/runners.csv to S3)
        │
        ▼
etl-pipeline (bronze -> silver -> gold)
```

Each Prefect task shells out to that app's existing `docker compose run`
command — the same one documented in
[`../web-scraper/README.md`](../web-scraper/README.md) and
[`../etl-pipeline/README.md`](../etl-pipeline/README.md). This module doesn't
duplicate either app's configuration (each still reads its own `.env`); it
only sequences their existing entrypoints and adds retries/logging/scheduling
around them.

## Requirements

- Docker + Docker Compose (used to run `scraper` and `etl` — see each app's
  own README for building the images once via `docker compose build`)
- Python 3.10+
- Both `web-scraper/.env` and `etl-pipeline/.env` already configured (S3
  bucket/credentials), same as running each app manually

## Install

```bash
cd orchestration
python -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt
```

## Run once

```bash
python flows/santarem_pipeline.py
```

Runs `scrape_and_upload` then `run_etl` against Prefect's local ephemeral
API (no server to stand up) — logs stream to stdout. Either task retries
once after 60s on failure; a second failure surfaces the error and stops the
flow (the etl step never runs off of a partially-failed scrape).

## Schedule (dynamic, event-driven)

Events in Santarém don't follow a fixed calendar. `check_and_run.py` handles
this by fetching the next event date from the CronoSantarém events page each
day and triggering the pipeline exactly 1 day after the event — once results
are published.

Set up a system cron to call it daily:

```
# /etc/cron.d/santarem-pipeline  (adjust user and path as needed)
0 3 * * *  user  cd /path/to/repo/orchestration && .venv/bin/python check_and_run.py >> /var/log/santarem-pipeline.log 2>&1
```

On days that are not pipeline days the script exits immediately with no
side effects. No long-running process to keep alive.

To verify manually what date it would target today:

```bash
python -c "from next_event import next_event_date; from datetime import timedelta; d = next_event_date(); print(f'Next event: {d} | Pipeline runs: {d + timedelta(days=1)}')"
```

## Run tests

```bash
pip install -r requirements-dev.txt
pytest tests/
```

## Why not run the orchestrator itself in Docker?

Both tasks call `docker compose` on the *host*. Containerizing this process
too would mean mounting the host's Docker socket into it (Docker-in-Docker)
just to shell back out to sibling containers — extra complexity this
2-step pipeline doesn't need yet. Worth revisiting only if the orchestrator
needs to run somewhere without a host Docker daemon available (e.g. a
managed container platform).
