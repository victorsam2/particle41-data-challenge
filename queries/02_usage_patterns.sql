select
    day_of_week,
    day_name,
    start_hour,
    member_casual,
    trip_count,
    valid_duration_trip_count,
    avg_valid_duration_seconds
from main.mart_usage_patterns
order by day_of_week, start_hour, member_casual
