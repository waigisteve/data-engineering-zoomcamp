{{
    config(
        materialized='table'
    )
}}

with ranked as (

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

        avg_trips_per_active_day,
        avg_passengers_per_active_day,
        avg_revenue_per_active_day,

        revenue_per_trip,
        avg_trip_distance,
        avg_trip_duration_minutes,

        rank() over (
            order by total_trips desc
        ) as scale_rank,

        rank() over (
            order by avg_trips_per_active_day desc
        ) as intensity_rank,

        rank() over (
            order by  revenue_per_trip desc
        ) as yield_rank

    from {{ ref('fct_persistent_morning_corridor') }}

)

select
    *,
    round(corridor_activity_rate * 100, 1) as persistence_pct

from ranked
