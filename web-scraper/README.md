# Running Race in Santarém Web Scraper

Service that scrapes race results from [cronosantarem.com.br](https://www.cronosantarem.com.br/resultados-eventos) and stores them as CSV files.

## Functionality

- Scraping of running events from Santarém, Brazil
- Automatic filtering to exclude other sports (cycling, swimming, trail, triathlon)
- Parsing of `.clax` files (XML) with detailed runner results
- Data storage as CSV, deduplicated on repeated runs
- Optional upload of the resulting CSVs to S3 for downstream processing
- Testing with RSpec, VCR, and WebMock

## Requirements

- Ruby 3.2.2 (or Docker)

## Installation and Setup

```bash
bundle install
```

## Usage

### Run the full scrape

```bash
bundle exec rake scrape:all
# or
bin/scrape
```

This scrapes the events page, saves matching events to `data/events.csv`, then
parses the `.clax` result file for every not-yet-scraped event into
`data/runners.csv`.

### Run individual steps

```bash
bundle exec rake scrape:events
bundle exec rake scrape:runners
```

### Via Docker

Build the image:

```bash
docker compose build
```

Install/update gems (also happens automatically on `build`, but useful after editing the Gemfile):

```bash
docker compose run --rm scraper bundle install
```

Run the full scrape (`scrape:all`, the default command):

```bash
docker compose up
# or, without leaving a stopped container behind
docker compose run --rm scraper
```

Run an individual step:

```bash
docker compose run --rm scraper bundle exec rake scrape:events
docker compose run --rm scraper bundle exec rake scrape:runners
```

Run the test suite:

```bash
docker compose run --rm scraper bundle exec rspec
```

Open a shell in the container (useful for debugging):

```bash
docker compose run --rm scraper bash
```

If you get `bundler: failed to load command: rake` or similar, the
`bundle_cache` volume is stale (holding gems from a previous Gemfile). Reset
it and reinstall:

```bash
docker compose down -v
docker compose build
docker compose run --rm scraper bundle install
```

### Running Tests

```bash
bundle exec rspec
bundle exec rspec --format documentation
```

## S3 export

`rake scrape:all` (and `bin/scrape`) upload `data/events.csv` and
`data/runners.csv` to S3 as their last step, so the `../etl-pipeline` app can
read them from a bucket instead of needing local file access. This is a
no-op unless `S3_BUCKET` is set — the test suite and a bare `bin/scrape`
run with no AWS access needed by default.

To point it at a real bucket, copy `.env.example` to `.env` and fill in:

```bash
# .env
S3_BUCKET=my-running-events-in-santarem-bucket
S3_EVENTS_KEY=raw/events.csv
S3_RUNNERS_KEY=raw/runners.csv
AWS_REGION=us-east-1
```

These match the defaults `etl-pipeline`'s bronze layer already expects, so no
extra configuration is needed on that side. Credentials are resolved through
the AWS SDK's normal chain — nothing is hardcoded in the code:

- **Local dev**: set `AWS_ACCESS_KEY_ID`/`AWS_SECRET_ACCESS_KEY` in `.env`, or
  mount your `~/.aws` profile by uncommenting the volume line in
  `docker-compose.yml`.
- **Production (ECS/EC2/EKS)**: attach an IAM role/task role with
  `s3:PutObject` on the bucket — no keys needed at all.

`S3_ENDPOINT_URL` is available for pointing at LocalStack/MinIO during local
testing.

To upload without re-scraping:

```bash
bundle exec rake scrape:upload
```

## Project Structure

```
lib/
├── scraper.rb                # Entrypoint: requires everything, holds data_path/logger/upload_to_s3!
└── scraper/
    ├── csv_store.rb          # Generic CSV read/upsert/write layer
    ├── event.rb               # Event value object
    ├── event_store.rb         # Event persistence (data/events.csv)
    ├── runner.rb               # Runner value object
    ├── runner_store.rb        # Runner persistence (data/runners.csv)
    ├── event_scraper.rb       # Scrapes and filters events
    ├── clax_parser.rb         # Parses .clax XML into runners
    └── s3_uploader.rb         # Uploads the two CSVs to S3 (for ../etl-pipeline)

data/
├── events.csv                 # generated, gitignored
└── runners.csv                # generated, gitignored

spec/
└── scraper/
    ├── csv_store_spec.rb
    ├── event_scraper_spec.rb
    └── clax_parser_spec.rb
```

## Data Model

### events.csv

| Column | Description |
|---|---|
| `id` | Sequential integer id |
| `name` | Event name |
| `event_date` | Event date (`YYYY-MM-DD`) |
| `city` | City (filtered to "Santarém") |
| `result_url` | Results page URL |
| `clax_file_url` | `.clax` (XML) file URL |
| `scraped_at` | Timestamp once runners have been parsed |

### runners.csv

| Column | Description |
|---|---|
| `id` | Sequential integer id |
| `event_id` | Foreign key into `events.csv` |
| `position` | Overall finish position |
| `bib_number` | Bib number |
| `name` | Runner name |
| `club` | Club/team |
| `gender` | Gender (M/F) |
| `category` | Category (OVERALL, 40-49, 50-59, etc.) |
| `finish_time` | Finish time |
| `average_pace` | Average pace |
| `points`, `laps`, `best_lap` | Not populated by the current CLAX format |
| `distance` | Distance covered |

## Deduplication

`EventStore#upsert` and `RunnerStore#upsert` look up an existing row by a
natural key (`name` + `event_date` for events; `event_id` + `bib_number` +
`name` for runners) before appending, so re-running the scraper updates
existing rows in place instead of creating duplicates. Each store loads the
whole CSV into memory once, applies all upserts for the run, then writes the
file back a single time via `persist!`.

## Architecture

- **`EventScraper`** — fetches the events page, extracts the embedded
  `list_temp` JS array, filters to running events from Santarém, and upserts
  matches into `EventStore`.
- **`ClaxParser`** — takes an `Event`, fetches its `.clax` XML file, and
  upserts each result row into `RunnerStore`, then marks the event as scraped.
- **`CsvStore`** — the only file I/O in the project; both `EventStore` and
  `RunnerStore` are thin wrappers around it with entity-specific natural keys.

Both services take their store (and a `Logger`) as constructor keyword
arguments with sensible defaults, so tests can inject a store backed by a
temp file instead of touching `data/*.csv`.

## Known caveat

`EventScraper#parse_events_from_js` uses `eval` to turn the page's embedded
`list_temp` JavaScript array literal into a Ruby array, because it isn't
valid JSON (unquoted keys, single-quoted strings). This was carried over
as-is from the original implementation; if the scraped page is ever
untrusted or compromised, this executes arbitrary Ruby. Worth hardening
with a proper JS-object-literal-to-JSON conversion if this is exposed beyond
a controlled, manually-run scrape.

## License

This project was developed for educational purposes and automation of public data collection.
