with source as (

    select
        cast(dispatching_base_num as string) as dispatching_base_num,
        cast(pulocationid as integer) as pickup_location_id,
        cast(dolocationid as integer) as dropoff_location_id,
        safe_cast(cast(pickup_datetime as string) as timestamp) as pickup_datetime,
        safe_cast(cast(dropoff_datetime as string) as timestamp) as dropoff_datetime
    from {{ source('raw', 'fhv_tripdata_2019_01') }}

    union all

    select
        cast(dispatching_base_num as string) as dispatching_base_num,
        cast(pulocationid as integer) as pickup_location_id,
        cast(dolocationid as integer) as dropoff_location_id,
        safe_cast(cast(pickup_datetime as string) as timestamp) as pickup_datetime,
        safe_cast(cast(dropoff_datetime as string) as timestamp) as dropoff_datetime
    from {{ source('raw', 'fhv_tripdata_2019_02') }}

    union all

    select
        cast(dispatching_base_num as string) as dispatching_base_num,
        cast(pulocationid as integer) as pickup_location_id,
        cast(dolocationid as integer) as dropoff_location_id,
        safe_cast(cast(pickup_datetime as string) as timestamp) as pickup_datetime,
        safe_cast(cast(dropoff_datetime as string) as timestamp) as dropoff_datetime
    from {{ source('raw', 'fhv_tripdata_2019_03') }}

    union all

    select
        cast(dispatching_base_num as string) as dispatching_base_num,
        cast(pulocationid as integer) as pickup_location_id,
        cast(dolocationid as integer) as dropoff_location_id,
        safe_cast(cast(pickup_datetime as string) as timestamp) as pickup_datetime,
        safe_cast(cast(dropoff_datetime as string) as timestamp) as dropoff_datetime
    from {{ source('raw', 'fhv_tripdata_2019_04') }}

    union all

    select
        cast(dispatching_base_num as string) as dispatching_base_num,
        cast(pulocationid as integer) as pickup_location_id,
        cast(dolocationid as integer) as dropoff_location_id,
        safe_cast(cast(pickup_datetime as string) as timestamp) as pickup_datetime,
        safe_cast(cast(dropoff_datetime as string) as timestamp) as dropoff_datetime
    from {{ source('raw', 'fhv_tripdata_2019_05') }}

    union all

    select
        cast(dispatching_base_num as string) as dispatching_base_num,
        cast(pulocationid as integer) as pickup_location_id,
        cast(dolocationid as integer) as dropoff_location_id,
        safe_cast(cast(pickup_datetime as string) as timestamp) as pickup_datetime,
        safe_cast(cast(dropoff_datetime as string) as timestamp) as pickup_datetime
    from {{ source('raw', 'fhv_tripdata_2019_06') }}

    union all

    select
        cast(dispatching_base_num as string) as dispatching_base_num,
        cast(pulocationid as integer) as pickup_location_id,
        cast(dolocationid as integer) as dropoff_location_id,
        safe_cast(cast(pickup_datetime as string) as timestamp) as pickup_datetime,
        safe_cast(cast(dropoff_datetime as string) as timestamp) as dropoff_datetime
    from {{ source('raw', 'fhv_tripdata_2019_07') }}

    union all

    select
        cast(dispatching_base_num as string) as dispatching_base_num,
        cast(pulocationid as integer) as pickup_location_id,
        cast(dolocationid as integer) as dropoff_location_id,
        safe_cast(cast(pickup_datetime as string) as timestamp) as pickup_datetime,
        safe_cast(cast(dropoff_datetime as string) as timestamp) as dropoff_datetime
    from {{ source('raw', 'fhv_tripdata_2019_08') }}

    union all

    select
        cast(dispatching_base_num as string) as dispatching_base_num,
        cast(pulocationid as integer) as pickup_location_id,
        cast(dolocationid as integer) as dropoff_location_id,
        safe_cast(cast(pickup_datetime as string) as timestamp) as pickup_datetime,
        safe_cast(cast(dropoff_datetime as string) as timestamp) as dropoff_datetime
    from {{ source('raw', 'fhv_tripdata_2019_09') }}

    union all

    select
        cast(dispatching_base_num as string) as dispatching_base_num,
        cast(pulocationid as integer) as pickup_location_id,
        cast(dolocationid as integer) as dropoff_location_id,
        safe_cast(cast(pickup_datetime as string) as timestamp) as pickup_datetime,
        safe_cast(cast(dropoff_datetime as string) as timestamp) as dropoff_datetime
    from {{ source('raw', 'fhv_tripdata_2019_10') }}

    union all

    select
        cast(dispatching_base_num as string) as dispatching_base_num,
        cast(pulocationid as integer) as pickup_location_id,
        cast(dolocationid as integer) as dropoff_location_id,
        safe_cast(cast(pickup_datetime as string) as timestamp) as pickup_datetime,
        safe_cast(cast(dropoff_datetime as string) as timestamp) as dropoff_datetime
    from {{ source('raw', 'fhv_tripdata_2019_11') }}

    union all

    select
        cast(dispatching_base_num as string) as dispatching_base_num,
        cast(pulocationid as integer) as pickup_location_id,
        cast(dolocationid as integer) as dropoff_location_id,
        safe_cast(cast(pickup_datetime as string) as timestamp) as pickup_datetime,
        safe_cast(cast(dropoff_datetime as string) as timestamp) as dropoff_datetime
    from {{ source('raw', 'fhv_tripdata_2019_12') }}

)

select *
from source
where dispatching_base_num is not null
