{{
    config(
        materialized='table'
    )
}}

with activity as (

    select
        activity_date,
        activity_hour,
        pickup_location_id,
        'Green' as service_type,
        total_trips,
        total_passengers,
        total_revenue,
        total_distance,
        avg_trip_distance,
        total_duration_minutes,
        valid_duration_trips
    from {{ ref('int_green_zone_activity') }}

    union all

    select
        activity_date,
        activity_hour,
        pickup_location_id,
        'Yellow' as service_type,
        total_trips,
        total_passengers,
        total_revenue,
        total_distance,
        avg_trip_distance,
        total_duration_minutes,
        valid_duration_trips
    from {{ ref('int_yellow_zone_activity') }}

)

select
    activity_date,
    activity_hour,

    case
        when extract(isodow from activity_date) between 1 and 5
            then 'Weekday'
        else 'Weekend'
    end as day_type,

    case
        when activity_hour >= 7 and activity_hour < 10
            then 'Morning Rush'
        when activity_hour >= 10 and activity_hour < 16
            then 'Midday'
        when activity_hour >= 16 and activity_hour < 19
            then 'Evening Rush'
        when activity_hour >= 19
            then 'Evening'
        else 'Overnight'
    end as time_period,

    service_type,
    pickup_location_id,
    coalesce(z.zone, 'Unknown Zone') as pickup_zone,

    total_trips,
    total_passengers,
    total_revenue,
    total_distance,
    avg_trip_distance,

    total_duration_minutes
        / nullif(valid_duration_trips, 0)
        as avg_trip_duration_minutes

from activity

left join {{ ref('dim_zones') }} as z
    on activity.pickup_location_id = z.location_id
