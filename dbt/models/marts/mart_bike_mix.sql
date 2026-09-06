{{ config(materialized='table') }}

with bike_mix as (
    select
        rideable_type || '|' || member_casual as mart_key,
        rideable_type,
        member_casual,
        count(*) as trip_count,
        count(valid_duration_seconds) as valid_duration_trip_count,
        avg(valid_duration_seconds) as avg_valid_duration_seconds
    from {{ ref('fct_trips') }}
    group by 1, 2, 3
)

select
    mart_key,
    rideable_type,
    member_casual,
    trip_count,
    trip_count * 1.0 / sum(trip_count) over (partition by member_casual) as trip_share_within_segment,
    valid_duration_trip_count,
    avg_valid_duration_seconds
from bike_mix
