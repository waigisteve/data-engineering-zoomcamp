-- Monthly revenue aggregation by pickup zone and service type.
-- Aggregate directly from the unioned trip view.
-- This avoids materializing a large trip-level intermediate table.

select
    coalesce(pickup_zone.zone, 'Unknown Zone') as pickup_zone,

    {% if target.type == 'bigquery' %}
        cast(date_trunc(pickup_datetime, month) as date)
    {% elif target.type == 'duckdb' %}
        date_trunc('month', pickup_datetime)
    {% endif %} as revenue_month,

    trips.service_type,

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

from {{ ref('int_trips_unioned') }} as trips

left join {{ ref('dim_zones') }} as pickup_zone
    on trips.pickup_location_id = pickup_zone.location_id

group by
    coalesce(pickup_zone.zone, 'Unknown Zone'),
    revenue_month,
    trips.service_type
