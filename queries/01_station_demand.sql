with segment_totals as (
    select
        member_casual,
        sum(trip_count) as segment_trip_count
    from main.mart_station_demand
    group by 1
),

ranked_named_stations as (
    select
        'named_station' as station_group,
        mart_station_demand.member_casual,
        mart_station_demand.station_key,
        dim_station.historical_station_name as station_name,
        mart_station_demand.trip_count,
        segment_totals.segment_trip_count,
        mart_station_demand.valid_duration_trip_count,
        mart_station_demand.avg_valid_duration_seconds,
        null as unknown_trip_share,
        row_number() over (
            partition by mart_station_demand.member_casual
            order by mart_station_demand.trip_count desc, mart_station_demand.station_key
        ) as demand_rank
    from main.mart_station_demand
    inner join main.dim_station
        on mart_station_demand.station_key = dim_station.station_key
    inner join segment_totals
        on mart_station_demand.member_casual = segment_totals.member_casual
    where mart_station_demand.station_key != 'unknown'
),

unknown_station as (
    select
        'unknown_station' as station_group,
        mart_station_demand.member_casual,
        mart_station_demand.station_key,
        dim_station.historical_station_name as station_name,
        mart_station_demand.trip_count,
        segment_totals.segment_trip_count,
        mart_station_demand.valid_duration_trip_count,
        mart_station_demand.avg_valid_duration_seconds,
        mart_station_demand.trip_count * 1.0 / segment_totals.segment_trip_count as unknown_trip_share,
        null as demand_rank
    from main.mart_station_demand
    inner join main.dim_station
        on mart_station_demand.station_key = dim_station.station_key
    inner join segment_totals
        on mart_station_demand.member_casual = segment_totals.member_casual
    where mart_station_demand.station_key = 'unknown'
)

select *
from ranked_named_stations
where demand_rank <= 10

union all

select *
from unknown_station
order by member_casual, station_group, demand_rank nulls last
