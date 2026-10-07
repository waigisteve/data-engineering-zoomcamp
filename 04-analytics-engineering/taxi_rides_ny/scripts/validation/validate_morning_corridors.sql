-- Morning-rush corridor validation
-- Validates geography cleanup, corridor grain, persistence,
-- and the business-facing opportunity model.

with corridor_checks as (

    select
        count(*) as total_rows,

        count(distinct
            cast(pickup_location_id as varchar) || '|' ||
            cast(dropoff_location_id as varchar) || '|' ||
            service_type
        ) as distinct_grain_keys,

        count(*) filter (
            where pickup_zone = 'NV'
               or dropoff_zone = 'NV'
        ) as invalid_nv_corridors,

        coalesce(
            sum(
                case
                    when pickup_zone = 'NV'
                      or dropoff_zone = 'NV'
                    then total_trips
                    else 0
                end
            ),
            0
        ) as invalid_nv_trips

    from main.fct_zone_morning_corridor

),

persistent_checks as (

    select
        count(*) as total_rows,

        count(*) filter (
            where active_days < 100
        ) as below_persistence_threshold,

        min(active_days) as minimum_active_days

    from main.fct_persistent_morning_corridor

),

opportunity_checks as (

    select
        count(*) as total_rows,

        count(distinct
            cast(pickup_location_id as varchar) || '|' ||
            cast(dropoff_location_id as varchar) || '|' ||
            service_type
        ) as distinct_grain_keys,

        count(*) filter (
            where persistence_pct is null
        ) as null_persistence,

        count(*) filter (
            where total_trips is null
        ) as null_total_trips

    from main.fct_morning_corridor_opportunity

)

-- Corridor integrity and geography cleanup.
select
    case
        when total_rows = distinct_grain_keys
         and invalid_nv_corridors = 0
         and invalid_nv_trips = 0
            then 'PASS'
        else 'FAIL'
    end as status,

    'fct_zone_morning_corridor' as model,
    'integrity' as check_type,

    total_rows,
    distinct_grain_keys,
    invalid_nv_corridors,
    invalid_nv_trips,

    cast(null as bigint) as below_persistence_threshold,
    cast(null as bigint) as minimum_active_days,
    cast(null as bigint) as null_persistence,
    cast(null as bigint) as null_total_trips

from corridor_checks

union all

-- The persistent model should contain only corridors meeting
-- the documented 100-active-day persistence threshold.
select
    case
        when total_rows = 664
         and below_persistence_threshold = 0
         and minimum_active_days >= 100
            then 'PASS'
        else 'FAIL'
    end as status,

    'fct_persistent_morning_corridor' as model,
    'population_reconciliation' as check_type,

    total_rows,
    cast(null as bigint) as distinct_grain_keys,
    cast(null as bigint) as invalid_nv_corridors,
    cast(null as bigint) as invalid_nv_trips,

    below_persistence_threshold,
    minimum_active_days,
    cast(null as bigint) as null_persistence,
    cast(null as bigint) as null_total_trips

from persistent_checks

union all

-- Opportunity model must preserve the corridor grain and
-- contain the expected persistent corridor population.
select
    case
        when total_rows = 664
         and distinct_grain_keys = 664
         and null_persistence = 0
         and null_total_trips = 0
            then 'PASS'
        else 'FAIL'
    end as status,

    'fct_morning_corridor_opportunity' as model,
    'integrity' as check_type,

    total_rows,
    distinct_grain_keys,
    cast(null as bigint) as invalid_nv_corridors,
    cast(null as bigint) as invalid_nv_trips,

    cast(null as bigint) as below_persistence_threshold,
    cast(null as bigint) as minimum_active_days,
    null_persistence,
    null_total_trips

from opportunity_checks

order by
    model,
    check_type;
