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

## Schedule (monthly cron)

```bash
python serve.py
```

Registers a `0 3 1 * *` (03:00 on the 1st of each month) schedule and keeps polling for it —
this process needs to stay running for scheduled runs to fire (systemd unit,
tmux/screen, or a small always-on host process; not something `cron` itself
launches, since Prefect owns the schedule here). Stopping the process just
pauses future runs, it doesn't affect data already produced by prior runs.

For monitoring/history beyond stdout logs, point `PREFECT_API_URL` at a free
[Prefect Cloud](https://www.prefect.io/cloud) workspace or a self-hosted
`prefect server start` — neither is required for the above to work locally.

## Why not run the orchestrator itself in Docker?

Both tasks call `docker compose` on the *host*. Containerizing this process
too would mean mounting the host's Docker socket into it (Docker-in-Docker)
just to shell back out to sibling containers — extra complexity this
2-step pipeline doesn't need yet. Worth revisiting only if the orchestrator
needs to run somewhere without a host Docker daemon available (e.g. a
managed container platform).
