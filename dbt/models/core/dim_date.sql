{{ config(materialized='table') }}

with event_dates as (
    select cast(started_at as date) as date_day
    from {{ ref('stg_trips') }}
    where started_at is not null

    union

    select cast(ended_at as date) as date_day
    from {{ ref('stg_trips') }}
    where ended_at is not null
),

date_bounds as (
    select
        min(date_day) as first_date,
        max(date_day) as last_date
    from event_dates
)

select
    cast(strftime(date_day, '%Y%m%d') as integer) as date_key,
    date_day,
    extract(year from date_day) as calendar_year,
    extract(month from date_day) as calendar_month,
    extract(day from date_day) as day_of_month,
    dayofweek(date_day) as day_of_week,
    dayname(date_day) as day_name
from date_bounds,
    generate_series(first_date, last_date, interval 1 day) as dates(date_day)
