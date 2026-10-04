{{
    config(
        materialized='view'
    )
}}

with trips as (
    select
        md5(
            coalesce(cast(service_type as varchar), '') || '-' ||
            coalesce(cast(vendor_id as varchar), '') || '-' ||
            coalesce(cast(pickup_datetime as varchar), '') || '-' ||
            coalesce(cast(pickup_location_id as varchar), '') || '-' ||
            coalesce(cast(dropoff_datetime as varchar), '') || '-' ||
            coalesce(cast(total_amount as varchar), '')
        ) as trip_id,
        *
    from {{ ref('int_trips_unioned') }}
),

dim_zones as (
    select * from {{ ref('dim_zones') }}
),

payment_type_lookup as (
    select * from {{ ref('payment_type_lookup') }}
)

select
    trips.trip_id,
    trips.vendor_id,
    trips.service_type,
    trips.rate_code_id,
    trips.pickup_location_id,
    pickup_zone.borough as pickup_borough,
    pickup_zone.zone as pickup_zone,
    trips.dropoff_location_id,
    dropoff_zone.borough as dropoff_borough,
    dropoff_zone.zone as dropoff_zone,
    trips.pickup_datetime,
    trips.dropoff_datetime,
    {{ get_trip_duration_minutes('trips.pickup_datetime', 'trips.dropoff_datetime') }} as trip_duration_minutes,
    trips.store_and_fwd_flag,
    trips.passenger_count,
    trips.trip_distance,
    trips.trip_type,
    trips.fare_amount,
    trips.extra,
    trips.mta_tax,
    trips.tip_amount,
    trips.tolls_amount,
    trips.ehail_fee,
    trips.improvement_surcharge,
    trips.total_amount,
    trips.payment_type,
    payment_type_lookup.description as payment_type_description
from trips
left join dim_zones as pickup_zone
    on trips.pickup_location_id = pickup_zone.location_id
left join dim_zones as dropoff_zone
    on trips.dropoff_location_id = dropoff_zone.location_id
left join payment_type_lookup
    on trips.payment_type = payment_type_lookup.payment_type
