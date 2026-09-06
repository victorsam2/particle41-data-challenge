{{ config(materialized='view') }}

select
    nullif(trim(ride_id), '') as ride_id,
    nullif(trim(rideable_type), '') as rideable_type,
    try_cast(started_at as timestamp) as started_at,
    try_cast(ended_at as timestamp) as ended_at,
    nullif(trim(start_station_name), '') as start_station_name,
    nullif(trim(start_station_id), '') as start_station_id,
    nullif(trim(end_station_name), '') as end_station_name,
    nullif(trim(end_station_id), '') as end_station_id,
    try_cast(start_lat as double) as start_latitude,
    try_cast(start_lng as double) as start_longitude,
    try_cast(end_lat as double) as end_latitude,
    try_cast(end_lng as double) as end_longitude,
    nullif(trim(member_casual), '') as member_casual,
    source_month,
    source_file
from {{ source('raw', 'trips') }}
