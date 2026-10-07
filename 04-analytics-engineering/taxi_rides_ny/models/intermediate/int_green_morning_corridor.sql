{{
    config(
        materialized='table'
    )
}}

with normal_weekdays as (

    select
        activity_date
    from {{ ref('int_normal_weekday_morning_spine') }}

)

select
    cast(trips.pickup_datetime as date) as activity_date,
    trips.pickup_location_id,
    trips.dropoff_location_id,

    count(*) as total_trips,

    sum(coalesce(trips.passenger_count, 0)) as total_passengers,
    sum(trips.total_amount) as total_revenue,
    sum(trips.trip_distance) as total_distance,

    sum(
        case
            when trips.dropoff_datetime >= trips.pickup_datetime
            then date_diff(
                'minute',
                trips.pickup_datetime::timestamp,
                trips.dropoff_datetime::timestamp
            )
            else 0
        end
    ) as total_duration_minutes,

    count(
        case
            when trips.dropoff_datetime >= trips.pickup_datetime
            then 1
        end
    ) as valid_duration_trips

from {{ ref('stg_green_tripdata') }} as trips

inner join normal_weekdays nw
    on cast(trips.pickup_datetime as date) = nw.activity_date

where extract(isodow from trips.pickup_datetime) between 1 and 5
  and extract(hour from trips.pickup_datetime) >= 7
  and extract(hour from trips.pickup_datetime) < 10
  and trips.pickup_location_id is not null
  and trips.dropoff_location_id is not null
  and trips.pickup_location_id <> 264
  and trips.dropoff_location_id <> 264

group by
    cast(trips.pickup_datetime as date),
    trips.pickup_location_id,
    trips.dropoff_location_id
