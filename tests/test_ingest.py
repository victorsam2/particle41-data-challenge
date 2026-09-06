from __future__ import annotations

import zipfile
from pathlib import Path

import pytest

from ingest import cache_trip_csv, extract_stations, load_gbfs_json, parse_months


def test_parse_months_rejects_an_invalid_calendar_month() -> None:
    with pytest.raises(ValueError, match="Invalid month"):
        parse_months("202501,202513")


def test_parse_months_sorts_and_deduplicates_repeated_months() -> None:
    assert parse_months("202502,202501,202502") == ("202501", "202502")


def test_load_gbfs_json_rejects_invalid_json(tmp_path: Path) -> None:
    snapshot_path = tmp_path / "stations.json"
    snapshot_path.write_text("{not json", encoding="utf-8")

    with pytest.raises(ValueError, match="Invalid GBFS JSON"):
        load_gbfs_json(snapshot_path)


def test_cache_trip_csv_rejects_missing_required_columns(tmp_path: Path) -> None:
    archive_path = tmp_path / "202501-divvy-tripdata.zip"
    headers = [
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
        "member_casual",
    ]

    with zipfile.ZipFile(archive_path, "w") as archive:
        with archive.open("202501-divvy-tripdata.csv", "w") as raw_file:
            raw_file.write((",".join(headers) + "\n").encode("utf-8"))

    with pytest.raises(ValueError, match="end_lng"):
        cache_trip_csv(archive_path, tmp_path / "extracted.csv")


def test_cache_trip_csv_ignores_macos_archive_metadata(tmp_path: Path) -> None:
    archive_path = tmp_path / "202501-divvy-tripdata.zip"
    row = {column: "source value" for column in [
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
    ]}

    with zipfile.ZipFile(archive_path, "w") as archive:
        archive.writestr("202501-divvy-tripdata.csv", ",".join(row) + "\n" + ",".join(row.values()) + "\n")
        archive.writestr("__MACOSX/._202501-divvy-tripdata.csv", "metadata")

    extracted_path = cache_trip_csv(archive_path, tmp_path / "extracted.csv")

    assert extracted_path.read_text(encoding="utf-8") == (
        ",".join(row) + "\n" + ",".join(row.values()) + "\n"
    )


def test_extract_stations_preserves_nested_fields() -> None:
    station = {
        "station_id": "1",
        "name": "Example station",
        "rental_uris": {"android": "https://example.test/android"},
        "rental_methods": ["KEY", "CREDITCARD"],
    }

    assert extract_stations({"data": {"stations": [station]}}) == [station]


def test_extract_stations_rejects_a_missing_station_list() -> None:
    with pytest.raises(ValueError, match="data.stations"):
        extract_stations({"data": {}})
