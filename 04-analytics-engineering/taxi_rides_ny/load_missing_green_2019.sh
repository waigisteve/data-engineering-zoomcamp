#!/usr/bin/env bash

set -euo pipefail

DB="$HOME/zoomcamp/data-engineering-zoomcamp/taxi_rides.duckdb"
DATA_DIR="$HOME/zoomcamp/data-engineering-zoomcamp/green_2019_missing"

months=(
    "03:2019-03-01:2019-04-01"
    "04:2019-04-01:2019-05-01"
    "05:2019-05-01:2019-06-01"
    "06:2019-06-01:2019-07-01"
    "07:2019-07-01:2019-08-01"
    "08:2019-08-01:2019-09-01"
)

for entry in "${months[@]}"; do
    IFS=":" read -r month start_date end_date <<< "$entry"

    file="$DATA_DIR/green_tripdata_2019-${month}.parquet"

    echo
    echo "============================================================"
    echo "Processing Green 2019-${month}"
    echo "File: $file"
    echo "============================================================"

    if [[ ! -f "$file" ]]; then
        echo "ERROR: File not found: $file"
        exit 1
    fi

    existing=$(duckdb "$DB" -noheader -csv -c "
        SELECT COUNT(*)
        FROM main.green_tripdata
        WHERE lpep_pickup_datetime >= TIMESTAMP '${start_date}'
          AND lpep_pickup_datetime <  TIMESTAMP '${end_date}';
    ")

    existing=$(echo "$existing" | tr -d '[:space:]')

    echo "Existing rows for ${start_date} to ${end_date}: $existing"

    if [[ "$existing" != "0" ]]; then
        echo "SKIPPING 2019-${month}: data already exists."
        continue
    fi

    echo "Loading 2019-${month}..."

    duckdb "$DB" -c "
        SET threads=1;
        SET preserve_insertion_order=false;

        INSERT INTO main.green_tripdata
        SELECT *
        FROM read_parquet('${file}')
        WHERE lpep_pickup_datetime >= TIMESTAMP '${start_date}'
          AND lpep_pickup_datetime < TIMESTAMP '${end_date}';
    "

    loaded=$(duckdb "$DB" -noheader -csv -c "
        SELECT COUNT(*)
        FROM main.green_tripdata
        WHERE lpep_pickup_datetime >= TIMESTAMP '${start_date}'
          AND lpep_pickup_datetime < TIMESTAMP '${end_date}';
    ")

    loaded=$(echo "$loaded" | tr -d '[:space:]')

    echo "Rows now present for 2019-${month}: $loaded"
    echo "2019-${month} completed."
done

echo
echo "============================================================"
echo "FINAL GREEN 2019 MONTHLY COUNTS"
echo "============================================================"

duckdb "$DB" -c "
    SELECT
        EXTRACT(MONTH FROM lpep_pickup_datetime)::INTEGER AS month,
        COUNT(*) AS rows
    FROM main.green_tripdata
    WHERE lpep_pickup_datetime >= TIMESTAMP '2019-01-01'
      AND lpep_pickup_datetime < TIMESTAMP '2020-01-01'
    GROUP BY 1
    ORDER BY 1;
"

echo
echo "Done."
