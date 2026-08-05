"""Long-running process that serves the pipeline on a monthly cron schedule.

`Flow.serve()` registers the schedule against Prefect's local ephemeral API
and polls it from this same process — no separate Prefect server/Postgres to
run or maintain. Keep this process alive (systemd unit, tmux, a small always
-on container, etc.) for scheduled runs to actually fire; killing it just
stops future runs, it doesn't affect anything already scraped/processed.

For a one-off run instead (e.g. to test the flow, or trigger it from CI),
run `flows/santarem_pipeline.py` directly rather than this file.
"""
from flows.santarem_pipeline import santarem_pipeline

if __name__ == "__main__":
    santarem_pipeline.serve(
        name="santarem-running-events-monthly",
        cron="0 3 1 * *",  # 03:00 on the 1st of each month
    )
