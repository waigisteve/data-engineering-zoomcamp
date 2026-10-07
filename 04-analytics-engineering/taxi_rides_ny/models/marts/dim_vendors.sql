-- Dimension table for taxi technology vendors
-- Small static dimension defining vendor codes and their company names

select
    1 as vendor_id,
    'Creative Mobile Technologies' as vendor_name

union all

select
    2 as vendor_id,
    'VeriFone Inc.' as vendor_name

union all

select
    4 as vendor_id,
    'Unknown/Other' as vendor_name

union all

select
    5 as vendor_id,
    cast(null as varchar) as vendor_name
