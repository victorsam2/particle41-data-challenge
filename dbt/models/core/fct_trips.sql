{{ config(materialized='table') }}

with deduplicated_trips as (
    select distinct
        ride_id,
        rideable_type,
        started_at,
        ended_at,
        start_station_name,
        start_station_id,
        end_station_name,
        end_station_id,
        start_latitude,
        start_longitude,
        end_latitude,
        end_longitude,
        member_casual,
        source_month,
        source_file
    from {{ ref('stg_trips') }}
),

retained_trips as (
    select
        *,
        date_diff('second', started_at, ended_at) as duration_seconds
    from deduplicated_trips
    where ride_id is not null
        and started_at is not null
)

select
    ride_id,
    rideable_type,
    member_casual,
    started_at,
    ended_at,
    cast(strftime(started_at, '%Y%m%d') as integer) as start_date_key,
    cast(strftime(ended_at, '%Y%m%d') as integer) as end_date_key,
    case
        when start_station_id is null then 'unknown'
        else 'historical:' || start_station_id
    end as start_station_key,
    case
        when end_station_id is null then 'unknown'
        else 'historical:' || end_station_id
    end as end_station_key,
    start_station_name,
    end_station_name,
    start_latitude,
    start_longitude,
    end_latitude,
    end_longitude,
    duration_seconds,
    case
        when duration_seconds > 0 and duration_seconds <= 86400 then true
        else false
    end as duration_is_valid,
    case
        when duration_seconds > 0 and duration_seconds <= 86400 then duration_seconds
    end as valid_duration_seconds,
    source_month,
    source_file
from retained_trips
