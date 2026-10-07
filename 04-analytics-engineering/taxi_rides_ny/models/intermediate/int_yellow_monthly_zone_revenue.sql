{{
    config(
        materialized='table'
    )
}}

select
    coalesce(zones.zone, 'Unknown Zone') as pickup_zone,

    {% if target.type == 'bigquery' %}
        cast(date_trunc(trips.pickup_datetime, month) as date)
    {% elif target.type == 'duckdb' %}
        date_trunc('month', trips.pickup_datetime)
    {% endif %} as revenue_month,

    sum(trips.fare_amount) as revenue_monthly_fare,
    sum(trips.extra) as revenue_monthly_extra,
    sum(trips.mta_tax) as revenue_monthly_mta_tax,
    sum(trips.tip_amount) as revenue_monthly_tip_amount,
    sum(trips.tolls_amount) as revenue_monthly_tolls_amount,
    sum(trips.ehail_fee) as revenue_monthly_ehail_fee,
    sum(trips.improvement_surcharge) as revenue_monthly_improvement_surcharge,
    sum(trips.total_amount) as revenue_monthly_total_amount,
    count(*) as total_monthly_trips,
    avg(trips.passenger_count) as avg_monthly_passenger_count,
    avg(trips.trip_distance) as avg_monthly_trip_distance

from {{ ref('stg_yellow_tripdata') }} as trips

left join {{ ref('dim_zones') }} as zones
    on trips.pickup_location_id = zones.location_id

group by
    coalesce(zones.zone, 'Unknown Zone'),
    revenue_month
