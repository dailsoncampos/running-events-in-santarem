# Publishing the gold layer for external consumption (Athena, QuickSight, Looker Studio, ...)

## Current state

The gold layer ([`src/layers/gold.py`](../src/layers/gold.py)) already produces
report-ready marts:

- `data/gold/event_summary.parquet`
- `data/gold/category_podium.parquet`

Today these files stay **local only** (`data/gold/`, gitignored) — they aren't uploaded
anywhere. This document describes how to publish them to S3 and register them as tables
queryable via SQL (Athena) and from BI tools (QuickSight, Looker Studio/Data Studio, or any
client with an Athena JDBC/ODBC driver).

None of the steps below are automated in the pipeline yet — this is a manual/bootstrap
deployment guide. See [Automation next steps](#automation-next-steps) for what's missing to
automate it.

## Proposed architecture

```
etl-pipeline (gold, local parquet)
        │  upload (aws s3 cp / sync)
        ▼
s3://<bucket>/gold/event_summary/event_summary.parquet
s3://<bucket>/gold/category_podium/category_podium.parquet
        │  schema registration
        ▼
AWS Glue Data Catalog (external tables)
        │
        ▼
Amazon Athena (SQL engine over S3)
        │
        ├──▶ Amazon QuickSight        (native Athena connector)
        ├──▶ Google Looker Studio     (community connector / bridge, see below)
        └──▶ Any Athena JDBC/ODBC client (Metabase, DBeaver, Power BI, Tableau, ...)
```

## S3 layout

Each gold table should live under its own **prefix** (folder), not as a loose file — Athena
reads every object under a prefix as one table, so this already leaves room for multiple
files/partitions later without having to recreate the table:

```
s3://<bucket>/gold/event_summary/event_summary.parquet
s3://<bucket>/gold/category_podium/category_podium.parquet
```

> **Known limitation:** `gold.py` currently overwrites the same file on every pipeline run —
> meaning S3 would always hold the "latest snapshot", with no history across runs. If
> querying trends across runs becomes necessary, this would require partitioning by run
> date (e.g. `gold/event_summary/run_date=2026-08-14/...`). That's out of scope for this
> document.

## Step 1 — Upload the gold parquet files to S3

There's no automated upload step yet (`orchestration/flows/santarem_pipeline.py` stops at
`gold`). Until that's implemented, uploading can be done manually:

```bash
cd etl-pipeline
aws s3 cp data/gold/event_summary.parquet \
  s3://<bucket>/gold/event_summary/event_summary.parquet
aws s3 cp data/gold/category_podium.parquet \
  s3://<bucket>/gold/category_podium/category_podium.parquet
```

## Step 2 — Register the tables in the Glue Data Catalog

### What it is and why it sits in the middle

The **AWS Glue Data Catalog** is a persistent metastore (Hive Metastore-compatible): it
doesn't hold data, only **metadata** — database/table names, columns, types, S3 location,
and file format. Athena can't run `SELECT ... FROM table` directly over loose files in S3;
it needs an entry in the Catalog saying "table `event_summary` looks like this, has these
columns, and its parquet files live under this prefix". That registration is what Step 1
(the upload) alone doesn't create.

The advantage of using the Glue Data Catalog instead of, say, pointing each tool directly
at the files: the catalog is **shared**. Once registered, the same
`santarem_running_events.event_summary` and `.category_podium` tables are visible not just
to Athena but also to Redshift Spectrum, EMR/Spark, and Glue ETL jobs themselves — so if
this project ever wants to run a Spark transformation or load the data into Redshift, the
catalog is already in place, with no need to redefine the schema elsewhere.

### Two ways to populate the catalog

- **Manual DDL** (`CREATE EXTERNAL TABLE`, via the Athena console or
  `aws athena start-query-execution`): you declare the schema by hand. Predictable and easy
  to audit/version (the `.sql` can be checked into the repo), but it **doesn't** track
  schema changes automatically — if `gold.py` gains a new column, the Glue table stays stale
  until someone runs an `ALTER TABLE` or recreates it. Recommended while the gold schema
  stays small and rarely changes, as is the case today.
- **AWS Glue Crawler**: a managed job that scans `s3://<bucket>/gold/`, infers the schema of
  each subfolder by reading the parquet files, and creates/updates the corresponding tables
  in the Catalog automatically. Less manual upkeep, but requires setting up an IAM role and
  (for automatic refresh) a schedule. Recommended if the gold schema is expected to change
  often, or if the number of gold tables grows and maintaining per-table manual DDL becomes
  repetitive.

Combining both is also common: manual DDL to bootstrap the tables initially, then switching
to a scheduled Crawler once manual upkeep stops scaling.

#### Option A — Manual DDL

Types derived directly from the `gold.py` code (`pandas.to_parquet` uses `snappy`
compression by default):

```sql
CREATE DATABASE IF NOT EXISTS santarem_running_events;

CREATE EXTERNAL TABLE IF NOT EXISTS santarem_running_events.event_summary (
  event_id                 int,
  name                     string,
  event_date               date,
  city                     string,
  total_runners            int,
  finishers                int,
  avg_finish_time_seconds  double
)
STORED AS PARQUET
LOCATION 's3://<bucket>/gold/event_summary/'
TBLPROPERTIES ('parquet.compression'='SNAPPY');

CREATE EXTERNAL TABLE IF NOT EXISTS santarem_running_events.category_podium (
  event_id             int,
  event_name           string,
  category             string,
  rank                 double,
  bib_number           string,
  name                 string,
  finish_time_seconds  double
)
STORED AS PARQUET
LOCATION 's3://<bucket>/gold/category_podium/'
TBLPROPERTIES ('parquet.compression'='SNAPPY');
```

If the gold schema changes (a new column in `gold.py`), the table needs to be updated by
hand, e.g.:

```sql
ALTER TABLE santarem_running_events.event_summary
ADD COLUMNS (new_column string);
```

#### Option B — Glue Crawler

1. **Crawler IAM role**: needs read access to the gold bucket (`s3:GetObject`,
   `s3:ListBucket` on `s3://<bucket>/gold/*`) and the `AWSGlueServiceRole` managed policy
   (or equivalent) to write to the Data Catalog.
2. **Create the crawler** (console: Glue > Crawlers > Create crawler; or via CLI):

   ```bash
   aws glue create-crawler \
     --name santarem-gold-crawler \
     --role <iam-role-arn> \
     --database-name santarem_running_events \
     --targets '{"S3Targets": [{"Path": "s3://<bucket>/gold/"}]}'
   ```

3. **Run on demand** or **schedule it** (e.g. cron, triggered after each pipeline run):

   ```bash
   aws glue start-crawler --name santarem-gold-crawler
   ```

4. The crawler creates one table per subfolder found under `gold/` (here, `event_summary`
   and `category_podium`), inferring types from the parquet files.

**Schema evolution with the Crawler**: by default, when the crawler finds a new column on a
later run, it **adds the column to the existing table** automatically. This behavior is
configurable via `SchemaChangePolicy` (`UPDATE_IN_DATABASE` — the default — vs. `LOG`, which
only records the difference without altering the table), and can be restricted so removed
columns aren't dropped. Every schema change is recorded as a new table version in the
Catalog (Glue keeps a schema version history, queryable via `aws glue get-table-versions`).

**Infrastructure as code**: if the project adopts Terraform/CDK in the future, both the
database/tables (`aws_glue_catalog_database`, `aws_glue_catalog_table`) and the crawler
(`aws_glue_crawler`) have native resources — this allows versioning the gold table
definitions alongside the rest of the infrastructure, instead of running manual DDL or
relying solely on the crawler.

### Required Athena setup

Before the first query, configure **Athena > Settings > Query result location** with an S3
bucket/prefix for Athena to write query results to (required, and unrelated to the gold
bucket).

## Step 3 — Query via Athena

```sql
SELECT event_id, name, event_date, total_runners, finishers, avg_finish_time_seconds
FROM santarem_running_events.event_summary
ORDER BY event_date DESC;

SELECT event_name, category, rank, name, finish_time_seconds
FROM santarem_running_events.category_podium
WHERE rank <= 3
ORDER BY event_name, category, rank;
```

## Step 4 — Connect Amazon QuickSight

QuickSight has a native Athena connector:

1. **Manage QuickSight > Security & permissions > S3** — enable access to the `<bucket>`
   bucket (and the Athena results bucket), so QuickSight's service role can read the data.
2. **Datasets > New dataset > Athena** — choose the workgroup and the
   `santarem_running_events` database.
3. Select `event_summary` and/or `category_podium` (or write a custom query).
4. Choose **Direct query** (always reads current S3 data) or **SPICE** (imports a snapshot
   for faster queries — fits well with the fact that gold today is only a "latest
   snapshot").
5. Build the visualizations/dashboard from the dataset.

## Step 5 — Connect Google Looker Studio (Data Studio)

Looker Studio has **no native AWS/Athena connector built by Google**. Available options,
from simplest to most robust:

1. **Community/partner connector for Athena** — search "Athena" in the Looker Studio
   connector gallery; third-party connectors exist (free or paid). Check current
   availability and pricing before adopting one, since that catalog changes frequently.
2. **Bridge via Google Sheets** (simplest for this project's data volume): run the Athena
   query (via the `boto3`/Athena API or AWS CLI) and write the result to a Google Sheet,
   either manually or via a scheduled script; Looker Studio connects natively to Sheets.
   Recommended while the marts stay small and are refreshed infrequently (the current
   `orchestration` schedule is monthly).
3. **Bridge via BigQuery** — load the gold files into BigQuery (e.g. via BigQuery Omni, or a
   scheduled load job) and use Looker Studio's native BigQuery connector. More robust, more
   infrastructure work.

## Step 6 — Other BI tools

Any tool with an Athena JDBC/ODBC driver (Metabase, DBeaver, Tableau, Power BI via its
Athena connector, etc.) works as soon as the Glue tables exist — no extra work beyond
pointing the tool at the Athena workgroup/database.

## Costs

- **Athena**: billed per data scanned (roughly $5/TB); at this project's current volume
  (small marts), the cost is negligible.
- **Glue Data Catalog**: the first 1 million stored objects are free.
- **S3**: standard storage cost for the published parquet files.

## Automation next steps

Out of scope for this document, but needed to make this part of the pipeline instead of a
manual process:

- Add an environment variable to `etl-pipeline` (e.g. `S3_GOLD_BUCKET`/`S3_GOLD_PREFIX`,
  following the pattern already used by `S3_BUCKET`/`S3_EVENTS_KEY` in
  [`src/config.py`](../src/config.py)) and an upload step at the end of `gold.run()`.
- Add that upload as an explicit step in the Prefect flow
  ([`orchestration/flows/santarem_pipeline.py`](../../orchestration/flows/santarem_pipeline.py)),
  which today is limited to `scrape_and_upload` → `run_etl`.
- Automate creation/refresh of the Glue tables (a scheduled crawler, or Terraform/CDK
  versioning the table definitions).
