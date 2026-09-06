with raw_trips as (
    select
        ride_id,
        rideable_type,
        started_at,
        ended_at,
        start_station_name,
        start_station_id,
        end_station_name,
        end_station_id,
        start_lat,
        start_lng,
        end_lat,
        end_lng,
        member_casual,
        source_month,
        source_file
    from {{ source('raw', 'trips') }}
),

raw_row_count as (
    select count(*) as raw_rows
    from raw_trips
),

deduplicated_staged_trips as (
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

deduplicated_row_count as (
    select count(*) as deduplicated_rows
    from deduplicated_staged_trips
),

retained_row_count as (
    select count(*) as retained_rows
    from deduplicated_staged_trips
    where ride_id is not null
        and started_at is not null
),

fact_row_count as (
    select count(*) as fact_rows
    from {{ ref('fct_trips') }}
)

select
    raw_rows,
    raw_rows - deduplicated_rows as duplicate_rows_removed,
    deduplicated_rows - retained_rows as excluded_rows,
    fact_rows
from raw_row_count
cross join deduplicated_row_count
cross join retained_row_count
cross join fact_row_count
where raw_rows != (
    raw_rows - deduplicated_rows
    + deduplicated_rows - retained_rows
    + fact_rows
)
