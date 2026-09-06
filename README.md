# Particle41 Data Engineering Challenge

A small, runnable pipeline for Chicago Divvy trip history and a GBFS station snapshot. It loads January through March 2025 by default, models the data in DuckDB with dbt, validates the main data-quality assumptions, and writes three analytical query outputs.

## Run it

Prerequisites:

- Python 3.11, 3.12, or 3.13
- Bash
- Internet access for the first dependency and source download

From a fresh clone:

```bash
bash run.sh
```

The command creates or reuses `.venv`, installs the pinned dependencies, runs ingestion unit tests, loads raw data, runs dbt models and tests, and writes CSV query outputs under `data/results/`. The script uses `set -euo pipefail`, so it stops at the first failed stage.

The default is `202501,202502,202503`. To select valid `YYYYMM` source months explicitly:

```bash
MONTHS=202501,202502,202503 bash run.sh
```

Month values are validated, sorted, and deduplicated. The script accepts any valid month selection; the default satisfies the challenge requirement of three consecutive months.

## Stack

- Python 3.11–3.13
- DuckDB 1.5.5
- dbt-core 1.12.3 and dbt-duckdb 1.11.0
- pytest 9.1.1 and requests 2.34.2

Python 3.14 is intentionally not accepted because the validated dbt dependency stack was not compatible with it.

## Architecture and data model

```text
Divvy ZIP files + GBFS snapshot
    -> local cache
    -> Python ingestion
    -> DuckDB raw schema
    -> dbt staging views
    -> dimensions and trip fact
    -> analytical marts
    -> CSV query outputs
```

The project uses a star schema: `fct_trips` is the central event table, and `dim_station` and `dim_date` describe its station and time references. dbt `source()` and `ref()` declarations make the lineage explicit.

| Model | Grain | Key |
| --- | --- | --- |
| `raw.trips` | One received CSV row with source metadata | Source grain; raw is not deduplicated |
| `raw.stations` | One complete GBFS station object from the cached snapshot | Source station object |
| `stg_trips` | One raw trip row after casts and light cleanup | Source row |
| `stg_stations` | One GBFS station object with selected attributes extracted | `station_id` |
| `dim_station` | One historical trip-station ID, plus one `unknown` row | `station_key` |
| `dim_date` | One calendar date in the continuous interval from the earliest to latest parseable trip event | `date_key` |
| `fct_trips` | One retained trip per `ride_id` | `ride_id` |
| `mart_station_demand` | Start station × rider segment | `station_key` + `member_casual` |
| `mart_usage_patterns` | Weekday × start hour × rider segment | `day_of_week` + `start_hour` + `member_casual` |
| `mart_bike_mix` | Bike type × rider segment | `rideable_type` + `member_casual` |

Each dimension, fact, and mart is described in `dbt/models/schema.yml`. Primary grains are backed by unique and non-null tests; mart composite grains have deterministic composite keys and singular grain tests.

## Ingestion and idempotency

The ingestion script caches the original ZIP files, extracted CSV files, and one GBFS station snapshot under `data/cache/`. A `.part` suffix prevents an interrupted download from being treated as a cache hit.

For each run, Python validates the selected months and source structures, then DuckDB rebuilds `raw.trips` and `raw.stations` in one transaction from the selected cached inputs. dbt rebuilds the downstream tables from that replacement set. There is no append or incremental path, so running the same selection again does not accumulate trips.

Raw values remain faithful to the sources: trip fields are loaded as text with `source_month` and `source_file`; each raw station row preserves the full GBFS station JSON object and snapshot metadata. DuckDB reads the cached CSVs natively, avoiding slow Python row-by-row inserts while keeping Python responsible for download, cache, and validation.

## Key design decisions

### Station identity and GBFS matching

Trip station IDs and GBFS station IDs do not overlap. `dim_station` therefore uses the historical trip station ID as identity. GBFS attributes are enrichment only: names are normalized for case, surrounding whitespace, and one trailing asterisk, then accepted only when the historical-to-GBFS association is unambiguous. Unmatched and ambiguous historical stations remain separate rows with null GBFS attributes.

When a historical ID has multiple observed names, the dimension retains the latest observed name, with lexical tie-breaking. Different historical IDs can enrich to the same current GBFS station; they remain separate historical identities rather than being merged. In the default run, the dimension contains 1,272 matched identities, 82 unmatched identities, 34 ambiguous identities, and one `unknown` row. This favors conservative coverage over a speculative match. The live GBFS snapshot must not be interpreted as historical station inventory or capacity.

### Dockless trips and missing stations

Trips with missing endpoint IDs are retained. Each missing endpoint maps independently to the reserved `unknown` station key. `unknown` preserves fact referential integrity but is not a physical station, so the station-demand query reports it separately from named-station rankings.

### Duration quality

All retained trips remain available for volume measures. Only positive durations no greater than 86,400 seconds populate `valid_duration_seconds` and contribute to average-duration measures. This prevents extreme intervals from distorting averages without silently deleting trips.

### Fact retention and duplicate handling

`fct_trips` deduplicates duplicate staged rows using the selected trip fields and source metadata, then retains only rows with a nonblank `ride_id` and a parseable start timestamp. A conflicting repeated `ride_id` is not resolved arbitrarily: the fact uniqueness test fails instead. In the default run, raw and fact each contain 588,724 rows, so no source rows were removed by these conditions.

## Data-quality checks

The project currently runs 7 pytest ingestion tests and 42 dbt tests. They cover:

- input month validation, source CSV/JSON structure, and nested GBFS preservation;
- unique and non-null keys at the relevant grains;
- fact and mart foreign-key relationships;
- accepted values for station matching status, bike type, rider segment, and duration validity;
- a singular duration-range assertion;
- one raw-to-fact reconciliation for retained, exact-copy, and excluded rows; and
- singular composite-grain checks for the three marts.

## Analytical outputs

`run.sh` executes the following SQL files and writes their results as CSV:

- `queries/01_station_demand.sql` -> `data/results/01_station_demand.csv`
- `queries/02_usage_patterns.sql` -> `data/results/02_usage_patterns.csv`
- `queries/03_bike_mix.sql` -> `data/results/03_bike_mix.csv`

See [findings.md](findings.md) for measured results and interpretation.

## What I would do with more time

- Add full multiset rerun equality and month-switch regression checks.
- Version GBFS snapshots and model historical station attributes.
- Build a curated or geographic station crosswalk after evaluating its error rate.
- Add checksums, retry/cache-repair behavior, and explicit schema-evolution handling if operating requirements justified them.
- Add incremental partitions, CI, and volume/coverage monitoring.
- Revisit station balance only with a clear operational use case and availability/repositioning data.

The findings apply to the selected January–March 2025 trips and the cached live GBFS snapshot; they are not annual or causal conclusions.
