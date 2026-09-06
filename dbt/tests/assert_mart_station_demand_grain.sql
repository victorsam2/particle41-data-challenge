select
    station_key,
    member_casual
from {{ ref('mart_station_demand') }}
group by 1, 2
having count(*) > 1
