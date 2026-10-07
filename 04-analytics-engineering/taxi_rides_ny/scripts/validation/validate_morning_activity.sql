-- Morning-rush activity validation
-- Validates structural integrity of the activity models,
-- reconciles the fixed 2019 analytical populations,
-- and validates fct_trips integrity checks.

with zone_activity_checks as (

    select
        count(*) as total_rows,

        count(distinct
            cast(activity_date as varchar) || '|' ||
            cast(activity_hour as varchar) || '|' ||
            cast(pickup_location_id as varchar) || '|' ||
            service_type
        ) as distinct_grain_keys

    from main.fct_zone_activity

),

morning_activity_checks as (

    select
        count(*) as total_rows,
        count(distinct pickup_zone) as distinct_zones

    from main.fct_zone_morning_activity

),

pickup_location_checks as (

    select
        count(*) as total_rows,
        count(z.location_id) as matched_location_ids

    from main.fct_trips f

    left join main.dim_zones z
        on f.pickup_location_id = z.location_id

    where f.pickup_location_id is not null

),

trip_id_checks as (

    select
        count(*) as total_rows,
        count(trip_id) as non_null_trip_ids

    from main.fct_trips

),

payment_type_checks as (

    select
        count(*) as total_rows,

        count(
            case
                when payment_type is null
                  or payment_type between 0 and 5
                then 1
            end
        ) as valid_payment_type_rows

    from main.fct_trips

)

-- Structural integrity: activity grain must be unique.
select
    case
        when total_rows = distinct_grain_keys
            then 'PASS'
        else 'FAIL'
    end as status,

    'fct_zone_activity' as model,
    'integrity' as check_type,

    total_rows,
    distinct_grain_keys,
    cast(null as bigint) as distinct_zones

from zone_activity_checks

union all

-- Dataset reconciliation: this project has 875,670 activity rows.
select
    case
        when total_rows = 875670
            then 'PASS'
        else 'FAIL'
    end as status,

    'fct_zone_activity' as model,
    'population_reconciliation' as check_type,

    total_rows,
    cast(null as bigint) as distinct_grain_keys,
    cast(null as bigint) as distinct_zones

from zone_activity_checks

union all

-- Analytical reconciliation: the morning activity model contains
-- one row per observed pickup zone in the 2019 comparison period.
select
    case
        when total_rows = 257
         and distinct_zones = 257
            then 'PASS'
        else 'FAIL'
    end as status,

    'fct_zone_morning_activity' as model,
    'population_reconciliation' as check_type,

    total_rows,
    cast(null as bigint) as distinct_grain_keys,
    distinct_zones

from morning_activity_checks

union all

-- Baseline reconciliation: the analytical calendar contains
-- all 261 weekdays in 2019.
select
    case
        when count(*) = 261
            then 'PASS'
        else 'FAIL'
    end as status,

    'int_weekday_morning_spine' as model,
    'population_reconciliation' as check_type,

    count(*) as total_rows,
    cast(null as bigint) as distinct_grain_keys,
    cast(null as bigint) as distinct_zones

from main.int_weekday_morning_spine

union all

-- Baseline reconciliation: 216 normal comparison weekdays remain
-- after excluding missing/incomplete and holiday/outlier dates.
select
    case
        when count(*) = 216
            then 'PASS'
        else 'FAIL'
    end as status,

    'int_normal_weekday_morning_spine' as model,
    'population_reconciliation' as check_type,

    count(*) as total_rows,
    cast(null as bigint) as distinct_grain_keys,
    cast(null as bigint) as distinct_zones

from main.int_normal_weekday_morning_spine

union all

-- Referential integrity: every non-null pickup location in fct_trips
-- must resolve to a valid TLC taxi zone.
select
    case
        when total_rows = matched_location_ids
            then 'PASS'
        else 'FAIL'
    end as status,

    'fct_trips' as model,
    'pickup_location_relationship' as check_type,

    total_rows,
    cast(null as bigint) as distinct_grain_keys,
    cast(null as bigint) as distinct_zones

from pickup_location_checks

union all

-- Integrity: every fct_trips row must have a non-null trip identifier.
select
    case
        when total_rows = non_null_trip_ids
            then 'PASS'
        else 'FAIL'
    end as status,

    'fct_trips' as model,
    'trip_id_not_null' as check_type,

    total_rows,
    cast(null as bigint) as distinct_grain_keys,
    cast(null as bigint) as distinct_zones

from trip_id_checks

union all

-- Integrity: payment_type must be NULL or a valid TLC payment code 0-5.
select
    case
        when total_rows = valid_payment_type_rows
            then 'PASS'
        else 'FAIL'
    end as status,

    'fct_trips' as model,
    'payment_type_accepted_values' as check_type,

    total_rows,
    cast(null as bigint) as distinct_grain_keys,
    cast(null as bigint) as distinct_zones

from payment_type_checks

order by
    model,
    check_type;
