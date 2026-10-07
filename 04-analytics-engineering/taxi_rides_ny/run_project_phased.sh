#!/usr/bin/env bash
set -euo pipefail

DBT="$HOME/.local/bin/dbt"
DB="$HOME/zoomcamp/data-engineering-zoomcamp/taxi_rides.duckdb"
VALIDATION_SQL="scripts/validation/validate_morning_activity.sql"

echo "========================================"
echo "PHASE 1: Core models"
echo "========================================"

"$DBT" run --threads 1 --select stg_green_tripdata stg_yellow_tripdata dim_zones dim_vendors dim_payment_type payment_type_lookup int_trips_unioned fct_monthly_zone_revenue fct_trips

echo
echo "✓ Phase 1 completed successfully."
echo

echo "========================================"
echo "PHASE 2: Zone activity"
echo "========================================"

"$DBT" run --threads 1 --select fct_zone_activity

echo
echo "✓ Phase 2 completed successfully."
echo

echo "========================================"
echo "PHASE 3: Morning activity"
echo "========================================"

"$DBT" run --threads 1 --select time_spine int_weekday_morning_spine int_normal_weekday_morning_spine fct_zone_morning_activity

echo
echo "✓ Phase 3 completed successfully."
echo

echo "========================================"
echo "PHASE 4: Corridor analysis"
echo "========================================"

"$DBT" run --threads 1 --select fct_zone_morning_corridor fct_persistent_morning_corridor fct_morning_corridor_opportunity

echo
echo "✓ Phase 4 completed successfully."
echo

echo "========================================"
echo "DBT TEST SUITE"
echo "========================================"

"$DBT" test --threads 1

echo
echo "✓ DBT test suite completed successfully."
echo

echo "========================================"
echo "ANALYTICAL VALIDATION"
echo "========================================"

duckdb "$DB" < "$VALIDATION_SQL"

echo
echo "✓ Analytical validation completed successfully."
echo

echo "========================================"
echo "✓ FULL PROJECT RUN COMPLETED"
echo "========================================"
