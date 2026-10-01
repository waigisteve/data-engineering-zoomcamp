-- TEMPORARY MODEL (DISABLED)
-- ------------------------------------------------------------
-- Purpose:
--   Created to simulate a failing accepted_values test for
--   payment_type in dbt Zoomcamp Homework Question 2.
--
-- Details:
--   This model points to a manually created BigQuery table
--   (fct_trips_test) that contains an invalid value:
--       payment_type = 6
--
-- Behavior:
--   The model is intentionally disabled to prevent it from
--   affecting normal dbt runs, tests, or builds.
--
-- Action:
--   Do NOT enable unless explicitly testing data quality behavior.

{{ config(enabled=false) }}

select *
from `terraform-demo-487119.zoomcamp.fct_trips_test`
