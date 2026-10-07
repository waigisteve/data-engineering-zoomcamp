{{
    config(
        materialized='table'
    )
}}

select
    pickup_location_id,
    pickup_zone,

    dropoff_location_id,
    dropoff_zone,

    service_type,

    expected_weekdays,
    active_days,

    corridor_activity_rate,

    total_trips,
    total_passengers,
    total_revenue,

    total_trips::decimal
        / nullif(active_days, 0) as avg_trips_per_active_day,

    total_passengers::decimal
        / nullif(active_days, 0) as avg_passengers_per_active_day,

    total_revenue::decimal
        / nullif(active_days, 0) as avg_revenue_per_active_day,

    revenue_per_trip,
    avg_trip_distance,
    avg_trip_duration_minutes

from {{ ref('fct_zone_morning_corridor') }}

where active_days >= 100
