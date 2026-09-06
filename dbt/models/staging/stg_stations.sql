{{ config(materialized='view') }}

select
    station_json,
    nullif(trim(json_extract_string(station_json, '$.station_id')), '') as station_id,
    nullif(trim(json_extract_string(station_json, '$.name')), '') as station_name,
    nullif(trim(json_extract_string(station_json, '$.short_name')), '') as short_name,
    nullif(trim(json_extract_string(station_json, '$.external_id')), '') as external_id,
    try_cast(json_extract_string(station_json, '$.lat') as double) as latitude,
    try_cast(json_extract_string(station_json, '$.lon') as double) as longitude,
    try_cast(json_extract_string(station_json, '$.capacity') as integer) as capacity,
    try_cast(json_extract_string(station_json, '$.has_kiosk') as boolean) as has_kiosk,
    nullif(trim(json_extract_string(station_json, '$.station_type')), '') as station_type,
    source_snapshot,
    snapshot_last_updated,
    to_timestamp(snapshot_last_updated) as snapshot_updated_at
from {{ source('raw', 'stations') }}
