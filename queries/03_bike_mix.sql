select
    rideable_type,
    member_casual,
    trip_count,
    trip_share_within_segment,
    valid_duration_trip_count,
    avg_valid_duration_seconds
from main.mart_bike_mix
order by member_casual, rideable_type
