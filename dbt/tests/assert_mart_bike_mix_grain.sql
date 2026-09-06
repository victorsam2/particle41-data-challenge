select
    rideable_type,
    member_casual
from {{ ref('mart_bike_mix') }}
group by 1, 2
having count(*) > 1
