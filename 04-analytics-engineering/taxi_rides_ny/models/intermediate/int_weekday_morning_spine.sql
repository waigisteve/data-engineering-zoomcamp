{{ config(materialized='table') }}

select
    date_day as activity_date
from {{ ref('time_spine') }}
where date_day >= date '2019-01-01'
  and date_day < date '2020-01-01'
  and extract(isodow from date_day) between 1 and 5
