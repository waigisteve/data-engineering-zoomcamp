{{
    config(
        materialized='table'
    )
}}

select
    pickup_zone,
    revenue_month,
    'Green' as service_type,
    revenue_monthly_fare,
    revenue_monthly_extra,
    revenue_monthly_mta_tax,
    revenue_monthly_tip_amount,
    revenue_monthly_tolls_amount,
    revenue_monthly_ehail_fee,
    revenue_monthly_improvement_surcharge,
    revenue_monthly_total_amount,
    total_monthly_trips,
    avg_monthly_passenger_count,
    avg_monthly_trip_distance
from {{ ref('int_green_monthly_zone_revenue') }}

union all

select
    pickup_zone,
    revenue_month,
    'Yellow' as service_type,
    revenue_monthly_fare,
    revenue_monthly_extra,
    revenue_monthly_mta_tax,
    revenue_monthly_tip_amount,
    revenue_monthly_tolls_amount,
    revenue_monthly_ehail_fee,
    revenue_monthly_improvement_surcharge,
    revenue_monthly_total_amount,
    total_monthly_trips,
    avg_monthly_passenger_count,
    avg_monthly_trip_distance
from {{ ref('int_yellow_monthly_zone_revenue') }}
