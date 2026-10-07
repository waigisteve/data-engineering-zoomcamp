{{
    config(
        materialized='table'
    )
}}

with normal_weekdays as (

    select
        activity_date
    from {{ ref('int_normal_weekday_morning_spine') }}

),

daily_activity as (

    select
        activity_date,
        pickup_zone,
        sum(total_trips) as daily_trips
    from {{ ref('fct_zone_activity') }}
    where day_type = 'Weekday'
      and time_period = 'Morning Rush'
    group by
        activity_date,
        pickup_zone

),

zones as (

    select distinct
        pickup_zone
    from daily_activity

),

zone_calendar as (

    select
        z.pickup_zone,
        w.activity_date
    from zones z
    cross join normal_weekdays w

),

activity_with_coverage as (

    select
        zc.pickup_zone,
        zc.activity_date,
        coalesce(da.daily_trips, 0) as daily_trips,

        case
            when da.activity_date is not null then 1
            else 0
        end as has_recorded_activity

    from zone_calendar zc

    left join daily_activity da
        on zc.pickup_zone = da.pickup_zone
       and zc.activity_date = da.activity_date

),

zone_statistics as (

    select
        pickup_zone,

        count(*) as expected_weekdays,

        sum(has_recorded_activity) as observed_weekdays,

        sum(
            case
                when daily_trips > 0 then 1
                else 0
            end
        ) as positive_activity_days,

        sum(daily_trips) as total_trips,

        avg(daily_trips) as avg_daily_trips,

        median(daily_trips) as median_daily_trips,

        quantile_cont(daily_trips, 0.25) as p25_daily_trips,

        quantile_cont(daily_trips, 0.75) as p75_daily_trips,

        min(daily_trips) as min_daily_trips,

        max(daily_trips) as max_daily_trips

    from activity_with_coverage

    group by pickup_zone

)

select
    pickup_zone,

    expected_weekdays,

    observed_weekdays,

    positive_activity_days,

    cast(observed_weekdays as decimal(10,4))
        / nullif(expected_weekdays, 0) as recorded_activity_rate,

    total_trips,

    avg_daily_trips,

    median_daily_trips,

    p25_daily_trips,

    p75_daily_trips,

    min_daily_trips,

    max_daily_trips

from zone_statistics
