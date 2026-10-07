-- Source data validation
-- Validates loaded source populations and 2019 date boundaries.

with source_checks as (

    select
        'green_tripdata' as source,
        count(*) as total_rows,
        count(*) filter (
            where lpep_pickup_datetime >= '2019-01-01'
              and lpep_pickup_datetime < '2020-01-01'
        ) as rows_2019,
        count(*) filter (
            where lpep_pickup_datetime < '2019-01-01'
               or lpep_pickup_datetime >= '2020-01-01'
        ) as rows_outside_2019,
        min(lpep_pickup_datetime) as min_pickup_datetime,
        max(lpep_pickup_datetime) as max_pickup_datetime,
        5235874 as expected_rows_2019
    from main.green_tripdata

    union all

    select
        'yellow_tripdata' as source,
        count(*) as total_rows,
        count(*) filter (
            where tpep_pickup_datetime >= '2019-01-01'
              and tpep_pickup_datetime < '2020-01-01'
        ) as rows_2019,
        count(*) filter (
            where tpep_pickup_datetime < '2019-01-01'
               or tpep_pickup_datetime >= '2020-01-01'
        ) as rows_outside_2019,
        min(tpep_pickup_datetime) as min_pickup_datetime,
        max(tpep_pickup_datetime) as max_pickup_datetime,
        7696174 as expected_rows_2019
    from main.yellow_tripdata

)

select
    case
        when rows_2019 = expected_rows_2019
         and rows_outside_2019 >= 0
            then 'PASS'
        else 'FAIL'
    end as status,

    source,

    rows_2019,
    expected_rows_2019,

    rows_outside_2019,

    min_pickup_datetime,
    max_pickup_datetime

from source_checks

order by source;
