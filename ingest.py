from __future__ import annotations

import csv
import json
import os
import re
import shutil
import sys
import zipfile
from collections.abc import Mapping, Sequence
from pathlib import Path
from typing import Any

import duckdb
import requests

DEFAULT_MONTHS = ("202501", "202502", "202503")
TRIP_COLUMNS = (
    "ride_id",
    "rideable_type",
    "started_at",
    "ended_at",
    "start_station_name",
    "start_station_id",
    "end_station_name",
    "end_station_id",
    "start_lat",
    "start_lng",
    "end_lat",
    "end_lng",
    "member_casual",
)
TRIP_URL_TEMPLATE = "https://divvy-tripdata.s3.amazonaws.com/{month}-divvy-tripdata.zip"
GBFS_URL = "https://gbfs.divvybikes.com/gbfs/en/station_information.json"
MONTH_PATTERN = re.compile(r"^\d{6}$")


def parse_months(value: str | None) -> tuple[str, ...]:
    """Return a sorted, unique selection of valid YYYYMM values."""
    selected = DEFAULT_MONTHS if value is None else tuple(part.strip() for part in value.split(","))
    if not selected or any(not month for month in selected):
        raise ValueError("MONTHS must be a comma-separated list of YYYYMM values")

    invalid = [
        month
        for month in selected
        if not MONTH_PATTERN.fullmatch(month) or not 1 <= int(month[4:]) <= 12
    ]
    if invalid:
        raise ValueError(f"Invalid month value(s): {', '.join(invalid)}")

    return tuple(sorted(set(selected)))


def extract_stations(payload: Mapping[str, Any]) -> list[dict[str, Any]]:
    """Validate the GBFS envelope while preserving every station object."""
    data = payload.get("data")
    if not isinstance(data, Mapping) or not isinstance(data.get("stations"), list):
        raise ValueError("GBFS payload must contain data.stations as a list")

    stations = data["stations"]
    if not all(isinstance(station, dict) for station in stations):
        raise ValueError("GBFS data.stations must contain objects")
    return stations


def load_gbfs_json(snapshot_path: Path) -> dict[str, Any]:
    """Load and validate a cached GBFS JSON document."""
    try:
        with snapshot_path.open(encoding="utf-8") as snapshot_file:
            payload = json.load(snapshot_file)
    except (OSError, json.JSONDecodeError) as error:
        raise ValueError(f"Invalid GBFS JSON at {snapshot_path}: {error}") from error

    if not isinstance(payload, dict):
        raise ValueError(f"Invalid GBFS JSON at {snapshot_path}: root must be an object")
    extract_stations(payload)
    return payload


def cache_trip_csv(archive_path: Path, extracted_path: Path) -> Path:
    """Extract and validate a CSV cache so DuckDB can ingest it natively."""
    if extracted_path.exists():
        print(f"Using extracted cache: {extracted_path}")
        _validate_csv_header(extracted_path)
        return extracted_path

    extracted_path.parent.mkdir(parents=True, exist_ok=True)
    partial_path = extracted_path.with_suffix(extracted_path.suffix + ".part")
    partial_path.unlink(missing_ok=True)
    try:
        with zipfile.ZipFile(archive_path) as archive:
            csv_name = _find_trip_csv_name(archive, archive_path)
            with archive.open(csv_name) as source_file, partial_path.open("wb") as cache_file:
                shutil.copyfileobj(source_file, cache_file)
        _validate_csv_header(partial_path)
        partial_path.replace(extracted_path)
    except (OSError, zipfile.BadZipFile, ValueError) as error:
        partial_path.unlink(missing_ok=True)
        raise ValueError(f"Could not create CSV cache from {archive_path}: {error}") from error

    print(f"Extracted CSV cache: {extracted_path}")
    return extracted_path


def _find_trip_csv_name(archive: zipfile.ZipFile, archive_path: Path) -> str:
    csv_names = [
        name
        for name in archive.namelist()
        if name.lower().endswith(".csv")
        and not name.startswith("__MACOSX/")
        and not Path(name).name.startswith("._")
    ]
    if len(csv_names) != 1:
        raise ValueError(f"Trip archive {archive_path} must contain exactly one CSV file")
    return csv_names[0]


def _validate_csv_header(csv_path: Path) -> None:
    with csv_path.open(encoding="utf-8-sig", newline="") as text_file:
        actual_columns = csv.DictReader(text_file).fieldnames or []
    missing_columns = [column for column in TRIP_COLUMNS if column not in actual_columns]
    if missing_columns:
        raise ValueError(
            f"Trip CSV {csv_path} is missing required columns: {', '.join(missing_columns)}"
        )


def download_to_cache(url: str, cache_path: Path) -> bool:
    """Download once into a .part file, returning True only for a fresh download."""
    if cache_path.exists():
        print(f"Using cache: {cache_path}")
        return False

    cache_path.parent.mkdir(parents=True, exist_ok=True)
    partial_path = cache_path.with_suffix(cache_path.suffix + ".part")
    partial_path.unlink(missing_ok=True)
    try:
        with requests.get(url, stream=True, timeout=(10, 60)) as response:
            response.raise_for_status()
            with partial_path.open("wb") as cache_file:
                for chunk in response.iter_content(chunk_size=1024 * 1024):
                    if chunk:
                        cache_file.write(chunk)
        partial_path.replace(cache_path)
    except requests.RequestException as error:
        partial_path.unlink(missing_ok=True)
        raise RuntimeError(f"Download failed for {url}: {error}") from error
    except OSError as error:
        partial_path.unlink(missing_ok=True)
        raise RuntimeError(f"Could not write cache file {cache_path}: {error}") from error

    print(f"Downloaded: {cache_path}")
    return True


def rebuild_raw_schema(
    database_path: Path,
    months: Sequence[str],
    trip_archives: Mapping[str, Path],
    trip_csvs: Mapping[str, Path],
    snapshot_path: Path,
) -> None:
    """Replace raw source tables atomically from the selected cached inputs."""
    snapshot = load_gbfs_json(snapshot_path)
    stations = extract_stations(snapshot)
    snapshot_last_updated = snapshot.get("last_updated")
    if snapshot_last_updated is not None and not isinstance(snapshot_last_updated, int):
        raise ValueError("GBFS last_updated must be an integer when present")

    database_path.parent.mkdir(parents=True, exist_ok=True)
    connection = duckdb.connect(str(database_path))
    trip_column_definitions = ",\n                    ".join(
        f'"{column}" VARCHAR' for column in TRIP_COLUMNS
    )

    try:
        connection.execute("CREATE SCHEMA IF NOT EXISTS raw")
        connection.execute("BEGIN TRANSACTION")
        connection.execute("DROP TABLE IF EXISTS raw.trips")
        connection.execute("DROP TABLE IF EXISTS raw.stations")
        connection.execute(
            f"""
            CREATE TABLE raw.trips (
                {trip_column_definitions},
                source_month VARCHAR NOT NULL,
                source_file VARCHAR NOT NULL
            )
            """
        )
        connection.execute(
            """
            CREATE TABLE raw.stations (
                station_json JSON NOT NULL,
                source_snapshot VARCHAR NOT NULL,
                snapshot_last_updated BIGINT
            )
            """
        )

        for month in months:
            archive_path = trip_archives[month]
            quoted_columns = ", ".join(f'"{column}"' for column in TRIP_COLUMNS)
            connection.execute(
                f"""
                INSERT INTO raw.trips
                SELECT {quoted_columns}, ?, ?
                FROM read_csv(?, header = true, all_varchar = true)
                """,
                [month, archive_path.name, str(trip_csvs[month])],
            )

        connection.executemany(
            "INSERT INTO raw.stations VALUES (?, ?, ?)",
            [
                (json.dumps(station, separators=(",", ":")), snapshot_path.name, snapshot_last_updated)
                for station in stations
            ],
        )
        connection.execute("COMMIT")
    except Exception:
        connection.execute("ROLLBACK")
        raise
    finally:
        connection.close()


def print_raw_counts(database_path: Path) -> None:
    """Print basic raw table counts for the selected source inputs."""
    connection = duckdb.connect(str(database_path), read_only=True)
    try:
        print("Raw trip counts by source month:")
        for month, trip_count in connection.execute(
            "SELECT source_month, count(*) FROM raw.trips GROUP BY 1 ORDER BY 1"
        ).fetchall():
            print(f"  {month}: {trip_count}")
        station_count = connection.execute("SELECT count(*) FROM raw.stations").fetchone()[0]
        print(f"Raw station objects: {station_count}")
    finally:
        connection.close()


def main() -> int:
    try:
        months = parse_months(os.environ.get("MONTHS"))
        project_root = Path(__file__).resolve().parent
        cache_root = project_root / "data" / "cache"
        trip_archives = {
            month: cache_root / "trips" / f"{month}-divvy-tripdata.zip" for month in months
        }
        for month, archive_path in trip_archives.items():
            download_to_cache(TRIP_URL_TEMPLATE.format(month=month), archive_path)
        trip_csvs = {
            month: cache_trip_csv(
                archive_path,
                cache_root / "trips" / "extracted" / f"{month}-divvy-tripdata.csv",
            )
            for month, archive_path in trip_archives.items()
        }

        snapshot_path = cache_root / "gbfs" / "station_information.json"
        download_to_cache(GBFS_URL, snapshot_path)

        database_path = Path(
            os.environ.get("DUCKDB_PATH", str(project_root / "data" / "warehouse.duckdb"))
        )
        rebuild_raw_schema(database_path, months, trip_archives, trip_csvs, snapshot_path)
        print_raw_counts(database_path)
        return 0
    except (RuntimeError, ValueError, duckdb.Error) as error:
        print(f"Ingestion failed: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
