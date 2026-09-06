{{ config(materialized='table') }}

select
    cast(dim_date.day_of_week as varchar)
        || '|' || cast(extract(hour from fct_trips.started_at) as varchar)
        || '|' || fct_trips.member_casual as mart_key,
    dim_date.day_of_week,
    dim_date.day_name,
    extract(hour from fct_trips.started_at) as start_hour,
    fct_trips.member_casual,
    count(*) as trip_count,
    count(fct_trips.valid_duration_seconds) as valid_duration_trip_count,
    avg(fct_trips.valid_duration_seconds) as avg_valid_duration_seconds
from {{ ref('fct_trips') }}
inner join {{ ref('dim_date') }} as dim_date
    on fct_trips.start_date_key = dim_date.date_key
group by 1, 2, 3, 4, 5
