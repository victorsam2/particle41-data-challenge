{{ config(materialized='table') }}

select
    start_station_key || '|' || member_casual as mart_key,
    start_station_key as station_key,
    member_casual,
    count(*) as trip_count,
    count(valid_duration_seconds) as valid_duration_trip_count,
    avg(valid_duration_seconds) as avg_valid_duration_seconds
from {{ ref('fct_trips') }}
group by 1, 2, 3
