{{ config(materialized='table') }}

with endpoint_observations as (
    select
        start_station_id as historical_station_id,
        start_station_name as observed_station_name,
        started_at as observed_at
    from {{ ref('stg_trips') }}
    where start_station_id is not null

    union all

    select
        end_station_id as historical_station_id,
        end_station_name as observed_station_name,
        ended_at as observed_at
    from {{ ref('stg_trips') }}
    where end_station_id is not null
),

historical_stations as (
    select distinct historical_station_id
    from endpoint_observations
),

ranked_names as (
    select
        historical_station_id,
        observed_station_name,
        row_number() over (
            partition by historical_station_id
            order by observed_at desc nulls last, observed_station_name asc nulls last
        ) as name_rank
    from endpoint_observations
    where observed_station_name is not null
),

latest_names as (
    select
        historical_station_id,
        observed_station_name as historical_station_name
    from ranked_names
    where name_rank = 1
),

historical_aliases as (
    select distinct
        historical_station_id,
        lower(trim(rtrim(observed_station_name, '*'))) as normalized_station_name
    from endpoint_observations
    where observed_station_name is not null
),

gbfs_stations as (
    select
        station_id as gbfs_station_id,
        station_name as gbfs_station_name,
        lower(trim(rtrim(station_name, '*'))) as normalized_station_name,
        latitude,
        longitude,
        capacity,
        has_kiosk,
        station_type,
        snapshot_updated_at
    from {{ ref('stg_stations') }}
    where station_name is not null
),

matching_candidates as (
    select distinct
        historical_aliases.historical_station_id,
        gbfs_stations.gbfs_station_id
    from historical_aliases
    inner join gbfs_stations using (normalized_station_name)
),

resolved_matches as (
    select
        historical_station_id,
        count(distinct gbfs_station_id) as gbfs_candidate_count,
        min(gbfs_station_id) as matched_gbfs_station_id
    from matching_candidates
    group by 1
),

historical_dimension as (
    select
        'historical:' || historical_stations.historical_station_id as station_key,
        historical_stations.historical_station_id,
        latest_names.historical_station_name,
        case
            when coalesce(resolved_matches.gbfs_candidate_count, 0) = 0 then 'unmatched'
            when resolved_matches.gbfs_candidate_count = 1 then 'matched'
            else 'ambiguous'
        end as matching_status,
        case
            when resolved_matches.gbfs_candidate_count = 1
                then gbfs_stations.gbfs_station_id
        end as gbfs_station_id,
        case
            when resolved_matches.gbfs_candidate_count = 1
                then gbfs_stations.gbfs_station_name
        end as gbfs_station_name,
        case
            when resolved_matches.gbfs_candidate_count = 1
                then gbfs_stations.latitude
        end as latitude,
        case
            when resolved_matches.gbfs_candidate_count = 1
                then gbfs_stations.longitude
        end as longitude,
        case
            when resolved_matches.gbfs_candidate_count = 1
                then gbfs_stations.capacity
        end as capacity,
        case
            when resolved_matches.gbfs_candidate_count = 1
                then gbfs_stations.has_kiosk
        end as has_kiosk,
        case
            when resolved_matches.gbfs_candidate_count = 1
                then gbfs_stations.station_type
        end as station_type,
        case
            when resolved_matches.gbfs_candidate_count = 1
                then gbfs_stations.snapshot_updated_at
        end as gbfs_snapshot_updated_at
    from historical_stations
    left join latest_names using (historical_station_id)
    left join resolved_matches using (historical_station_id)
    left join gbfs_stations
        on resolved_matches.matched_gbfs_station_id = gbfs_stations.gbfs_station_id
)

select
    station_key,
    historical_station_id,
    historical_station_name,
    matching_status,
    gbfs_station_id,
    gbfs_station_name,
    latitude,
    longitude,
    capacity,
    has_kiosk,
    station_type,
    gbfs_snapshot_updated_at
from historical_dimension

union all

select
    'unknown' as station_key,
    null as historical_station_id,
    'Unknown station' as historical_station_name,
    'unknown' as matching_status,
    null as gbfs_station_id,
    null as gbfs_station_name,
    null as latitude,
    null as longitude,
    null as capacity,
    null as has_kiosk,
    null as station_type,
    null as gbfs_snapshot_updated_at
