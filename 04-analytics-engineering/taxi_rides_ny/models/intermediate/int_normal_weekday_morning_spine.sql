{{ config(materialized='table') }}

with expected_weekdays as (

    select
        activity_date
    from {{ ref('int_weekday_morning_spine') }}

),

observed_dates as (

    select distinct
        activity_date
    from {{ ref('fct_zone_activity') }}
    where day_type = 'Weekday'
      and time_period = 'Morning Rush'

),

excluded_dates as (

    select date '2019-02-01' as activity_date
    union all
    select date '2019-02-04'
    union all
    select date '2019-05-27'
    union all
    select date '2019-07-04'
    union all
    select date '2019-11-28'
    union all
    select date '2019-12-25'

)

select
    e.activity_date

from expected_weekdays e

inner join observed_dates o
    on e.activity_date = o.activity_date

left join excluded_dates x
    on e.activity_date = x.activity_date

where x.activity_date is null
