-- Morning-rush baseline validation
-- Validates the construction of the 2019 weekday comparison baseline.

with expected_weekdays as (

    select
        activity_date
    from main.int_weekday_morning_spine

),

observed_morning_weekdays as (

    select distinct
        cast(pickup_datetime as date) as activity_date
    from main.fct_trips
    where extract(isodow from pickup_datetime) between 1 and 5
      and extract(hour from pickup_datetime) >= 7
      and extract(hour from pickup_datetime) < 10

),

missing_morning_weekdays as (

    select
        e.activity_date
    from expected_weekdays e
    left join observed_morning_weekdays o
        on e.activity_date = o.activity_date
    where o.activity_date is null

),

normal_comparison_weekdays as (

    select
        activity_date
    from main.int_normal_weekday_morning_spine

),

baseline_checks as (

    select
        (select count(*) from expected_weekdays) as expected_weekdays,
        (select count(*) from observed_morning_weekdays) as observed_morning_weekdays,
        (select count(*) from missing_morning_weekdays) as completely_missing_morning_weekdays,
        (select count(*) from normal_comparison_weekdays) as normal_comparison_weekdays

)

select
    case
        when expected_weekdays = 261
         and observed_morning_weekdays = 222
         and completely_missing_morning_weekdays = 39
         and normal_comparison_weekdays = 216
            then 'PASS'
        else 'FAIL'
    end as status,

    'morning_rush_baseline' as check_name,

    expected_weekdays,
    observed_morning_weekdays,
    completely_missing_morning_weekdays,
    normal_comparison_weekdays

from baseline_checks;
