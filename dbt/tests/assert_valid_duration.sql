select
    ride_id,
    duration_seconds,
    valid_duration_seconds,
    duration_is_valid
from {{ ref('fct_trips') }}
where duration_is_valid is null
    or (
        duration_is_valid = true
        and (
            valid_duration_seconds is null
            or duration_seconds is null
            or duration_seconds <= 0
            or duration_seconds > 86400
            or valid_duration_seconds != duration_seconds
        )
    )
    or (
        duration_is_valid = false
        and (
            valid_duration_seconds is not null
            or (duration_seconds > 0 and duration_seconds <= 86400)
        )
    )
