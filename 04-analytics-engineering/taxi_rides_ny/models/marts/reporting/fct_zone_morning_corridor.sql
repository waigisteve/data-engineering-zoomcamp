{{
    config(
        materialized='table'
    )
}}

with corridor_activity as (

    select
        pickup_location_id,
        dropoff_location_id,

        'Green' as service_type,

        sum(total_trips) as total_trips,
        sum(total_passengers) as total_passengers,
        sum(total_revenue) as total_revenue,
        sum(total_distance) as total_distance,
        sum(total_duration_minutes) as total_duration_minutes,
        sum(valid_duration_trips) as valid_duration_trips,

        count(*) as active_days

    from {{ ref('int_green_morning_corridor') }}

    group by
        pickup_location_id,
        dropoff_location_id

    union all

    select
        pickup_location_id,
        dropoff_location_id,

        'Yellow' as service_type,

        sum(total_trips) as total_trips,
        sum(total_passengers) as total_passengers,
        sum(total_revenue) as total_revenue,
        sum(total_distance) as total_distance,
        sum(total_duration_minutes) as total_duration_minutes,
        sum(valid_duration_trips) as valid_duration_trips,

        count(*) as active_days

    from {{ ref('int_yellow_morning_corridor') }}

    group by
        pickup_location_id,
        dropoff_location_id

)

select
    corridor.pickup_location_id,
    pickup_zone.zone as pickup_zone,

    corridor.dropoff_location_id,
    dropoff_zone.zone as dropoff_zone,

    corridor.service_type,

    216 as expected_weekdays,

    corridor.active_days,

    cast(corridor.active_days as decimal(10,4))
        / 216 as corridor_activity_rate,

    corridor.total_trips,
    corridor.total_passengers,
    corridor.total_revenue,
    corridor.total_distance,

    corridor.total_distance
        / nullif(corridor.total_trips, 0) as avg_trip_distance,

    corridor.total_revenue
        / nullif(corridor.total_trips, 0) as revenue_per_trip,

    corridor.total_duration_minutes
        / nullif(corridor.valid_duration_trips, 0)
        as avg_trip_duration_minutes

from corridor_activity corridor

left join {{ ref('dim_zones') }} pickup_zone
    on corridor.pickup_location_id = pickup_zone.location_id

left join {{ ref('dim_zones') }} dropoff_zone
    on corridor.dropoff_location_id = dropoff_zone.location_id
