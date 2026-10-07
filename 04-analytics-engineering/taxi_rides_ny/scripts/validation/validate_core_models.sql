-- Core model validation
-- Validates structural integrity of the core models and reconciles
-- the fixed 2019 project population to the documented source totals.

with trip_checks as (

    select
        count(*) as total_rows,
        count(*) filter (where service_type = 'Green') as green_trips,
        count(*) filter (where service_type = 'Yellow') as yellow_trips,
        count(*) filter (where trip_id is null) as null_trip_ids
    from main.fct_trips

),

monthly_checks as (

    select
        count(*) as total_rows,

        count(distinct
            cast(pickup_zone as varchar) || '|' ||
            cast(revenue_month as varchar) || '|' ||
            service_type
        ) as distinct_grain_keys,

        count(*) filter (where pickup_zone is null) as null_pickup_zones,
        count(*) filter (where revenue_month is null) as null_revenue_months,
        count(*) filter (where service_type is null) as null_service_types

    from main.fct_monthly_zone_revenue

)

-- Structural integrity: the fact population must reconcile internally.
select
    case
        when total_rows = green_trips + yellow_trips
         and null_trip_ids = 0
            then 'PASS'
        else 'FAIL'
    end as status,

    'fct_trips' as model,
    'integrity' as check_type,

    total_rows,
    green_trips,
    yellow_trips,
    null_trip_ids,

    cast(null as bigint) as distinct_grain_keys,
    cast(null as bigint) as null_pickup_zones,
    cast(null as bigint) as null_revenue_months,
    cast(null as bigint) as null_service_types

from trip_checks

union all

-- Dataset reconciliation: these are the documented 2019 project populations.
select
    case
        when total_rows = 12932048
         and green_trips = 5235874
         and yellow_trips = 7696174
            then 'PASS'
        else 'FAIL'
    end as status,

    'fct_trips' as model,
    'population_reconciliation' as check_type,

    total_rows,
    green_trips,
    yellow_trips,
    cast(null as bigint) as null_trip_ids,

    cast(null as bigint) as distinct_grain_keys,
    cast(null as bigint) as null_pickup_zones,
    cast(null as bigint) as null_revenue_months,
    cast(null as bigint) as null_service_types

from trip_checks

union all

-- Structural integrity: monthly reporting grain must be unique and complete.
select
    case
        when total_rows = distinct_grain_keys
         and null_pickup_zones = 0
         and null_revenue_months = 0
         and null_service_types = 0
            then 'PASS'
        else 'FAIL'
    end as status,

    'fct_monthly_zone_revenue' as model,
    'integrity' as check_type,

    total_rows,
    cast(null as bigint) as green_trips,
    cast(null as bigint) as yellow_trips,
    cast(null as bigint) as null_trip_ids,

    distinct_grain_keys,
    null_pickup_zones,
    null_revenue_months,
    null_service_types

from monthly_checks

order by
    model,
    check_type;
