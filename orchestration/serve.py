"""Manual fallback: serves the pipeline on a fixed monthly cron via Prefect.

For automated scheduling keyed to actual event dates, use check_and_run.py
with a system cron instead — it fetches the next event date dynamically and
only triggers the pipeline 1 day after the event.

Use this file only when you want Prefect to manage the schedule internally
(requires this process to stay alive — systemd unit, tmux, etc.).
"""
from flows.santarem_pipeline import santarem_pipeline

if __name__ == "__main__":
    santarem_pipeline.serve(
        name="santarem-running-events-monthly",
        cron="0 3 1 * *",  # 03:00 on the 1st of each month
    )
