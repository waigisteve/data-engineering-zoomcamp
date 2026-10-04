{{
    config(
        materialized='table'
    )
}}

select
    cast(payment_type as integer) as payment_type_id,
    payment_type as payment_type_code,
    description as payment_type_description
from {{ ref('payment_type_lookup') }}
