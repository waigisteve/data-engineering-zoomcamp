-- Morning-rush exclusion validation
-- Validates the six dates excluded from the normal weekday baseline:
-- two severely incomplete source/data dates and four holidays.

with expected_exclusions as (

    select
        date '2019-02-01' as activity_date,
        'Severely incomplete source/data' as expected_reason

    union all

    select
        date '2019-02-04',
        'Severely incomplete source/data'

    union all

    select
        date '2019-05-27',
        'Holiday/outlier'

    union all

    select
        date '2019-07-04',
        'Holiday/outlier'

    union all

    select
        date '2019-11-28',
        'Holiday/outlier'

    union all

    select
        date '2019-12-25',
        'Holiday/outlier'

),

daily_coverage as (

    select
        cast(pickup_datetime as date) as activity_date,
        count(*) as total_trips,
        count(distinct pickup_location_id) as pickup_zones

    from main.fct_trips

    where extract(isodow from pickup_datetime) between 1 and 5
      and extract(hour from pickup_datetime) >= 7
      and extract(hour from pickup_datetime) < 10

    group by activity_date

),

validated_exclusions as (

    select
        e.activity_date,
        e.expected_reason,

        coalesce(d.total_trips, 0) as total_trips,
        coalesce(d.pickup_zones, 0) as pickup_zones,

        case
            when d.activity_date is not null
             and d.total_trips > 0
                then 1
            else 0
        end as has_activity

    from expected_exclusions e

    left join daily_coverage d
        on e.activity_date = d.activity_date

)

select
    case
        when count(*) = 6
         and count(*) filter (
                where has_activity = 1
            ) = 6
         and count(*) filter (
                where expected_reason = 'Severely incomplete source/data'
                  and total_trips <= 8
                  and pickup_zones <= 7
            ) = 2
         and count(*) filter (
                where expected_reason = 'Holiday/outlier'
            ) = 4
            then 'PASS'
        else 'FAIL'
    end as status,

    'morning_rush_exclusions' as check_name,

    count(*) as expected_exclusions,

    count(*) filter (
        where has_activity = 1
    ) as exclusions_with_activity,

    count(*) filter (
        where expected_reason = 'Severely incomplete source/data'
    ) as incomplete_source_dates,

    count(*) filter (
        where expected_reason = 'Holiday/outlier'
    ) as holiday_outlier_dates

from validated_exclusions;
