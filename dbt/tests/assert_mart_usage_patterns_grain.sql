select
    day_of_week,
    start_hour,
    member_casual
from {{ ref('mart_usage_patterns') }}
group by 1, 2, 3
having count(*) > 1
