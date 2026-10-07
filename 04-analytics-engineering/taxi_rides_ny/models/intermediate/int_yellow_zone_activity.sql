{{
    config(
        materialized='table'
    )
}}

select
    cast(pickup_datetime as date) as activity_date,
    extract(hour from pickup_datetime)::integer as activity_hour,
    pickup_location_id,

    count(*) as total_trips,
    sum(coalesce(passenger_count, 0)) as total_passengers,
    sum(total_amount) as total_revenue,
    sum(trip_distance) as total_distance,
    avg(trip_distance) as avg_trip_distance,

    sum(
        case
            when dropoff_datetime >= pickup_datetime
            then date_diff(
                'minute',
                pickup_datetime::timestamp,
                dropoff_datetime::timestamp
            )
            else 0
        end
    ) as total_duration_minutes,

    count(
        case
            when dropoff_datetime >= pickup_datetime
            then 1
        end
    ) as valid_duration_trips

from {{ ref('stg_yellow_tripdata') }}

group by
    activity_date,
    activity_hour,
    pickup_location_id
