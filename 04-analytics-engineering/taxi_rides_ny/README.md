# Taxi Rides NY - Analytics Engineering Pipeline (dbt & DuckDB)

This repository contains the analytics engineering project for **Module 4 of the Data Engineering Zoomcamp**, built using **dbt (Data Build Tool)** and **DuckDB**. It processes, transforms, and models New York City taxi trip data (Yellow and Green taxis) into clean staging, intermediate, and mart layers, complete with automated data quality testing.

---

## 🛠️ Tech Stack
*   **Orchestration & Transformation:** dbt-core
*   **Data Warehouse / Database:** DuckDB
*   **Language:** SQL, Python
*   **Version Control & Testing:** Git, dbt Test Suite

---

## 🚨 Troubleshooting & Engineering Challenges Log

During development, the pipeline encountered several SQL, data-quality, and memory challenges. The final design favors simple transformations, view-based intermediate layers, and early aggregation to keep DuckDB resource usage predictable.

### 1. SQL Syntax Errors During CTE Development

* **The Issue:** Early versions of the trip-unioning logic contained repeated `WITH` keywords between Common Table Expressions.
* **Root Cause:** A SQL statement requires a single `WITH` clause, with subsequent CTEs separated by commas.
* **Resolution:** Refactored the transformation into a single CTE chain and separated the Green and Yellow datasets cleanly before applying the final `UNION ALL`.

### 2. DuckDB Out-of-Memory Pressure on Large Trip-Level Transformations

* **The Issue:** Materializing large trip-level intermediate datasets and applying memory-intensive operations caused DuckDB out-of-memory failures on the local environment.
* **Root Cause:** The combined Green and Yellow datasets contain approximately 12.9 million 2019 trip records. Materializing additional wide intermediate tables increases memory pressure unnecessarily, particularly when operations require sorting, hashing, or maintaining large in-memory working sets.
* **Resolution:** The final architecture keeps `int_trips_unioned` as a view rather than materializing another large trip-level table. `fct_trips` also remains a view, while the reporting mart performs aggregation directly from the unioned trip view. DuckDB is configured with a single execution thread, a bounded memory limit, and a dedicated temporary directory.

### 3. Trip ID and Duplicate-Handling Design

* **The Challenge:** A trip-level `trip_id` was required for the fact model, while global uniqueness validation across the full dataset introduced significant memory pressure.
* **Resolution:** The final `fct_trips` view generates a deterministic MD5-based `trip_id` from stable trip attributes. The model enforces that the generated identifier is not null, while avoiding an expensive global uniqueness test over the complete 12.9 million-row view.
* **Design Principle:** A surrogate identifier is generated for downstream use without forcing a large materialized deduplication step when the reporting workload does not require it.

### 4. Incomplete Green Taxi 2019 Source Data

* **The Issue:** The original Green Taxi source contained only part of the 2019 data, with March through August missing.
* **Resolution:** The missing official TLC monthly Parquet files were downloaded and loaded into the raw Green dataset month by month. The final 2019 Green dataset contains 5,235,874 valid records.
* **Validation:** Green and Yellow staging models explicitly scope their source records to calendar year 2019.

### 5. Yellow Taxi Date Outliers

* **The Issue:** The raw Yellow Taxi source contained a small number of records outside the 2019 reporting period.
* **Resolution:** The Yellow staging model filters pickup timestamps to the 2019 calendar year rather than modifying the raw source data.

### 6. dbt Test Memory Pressure

* **The Issue:** Broad relationship and uniqueness tests against the full trip-level view could consume substantial memory.
* **Resolution:** Tests were executed with `--threads 1`, and expensive global uniqueness validation was avoided where it did not provide sufficient value for the portfolio workload. Targeted relationship and data-quality tests remain enabled for the fact model.
* **Final Validation:** The complete dbt build completed successfully with 37 passing resources, 1 no-op saved query, and zero warnings or errors.

---

## 📊 Pipeline Architecture & Layers

1. **Staging**
   - `stg_yellow_tripdata`
   - `stg_green_tripdata`

   Cleans source column names, standardizes data types, applies 2019 date boundaries, and exposes the source data as views.

2. **Intermediate**
   - `int_trips_unioned`

   Combines Green and Yellow trip records using `UNION ALL`. This remains a view to avoid materializing a large generic trip-level intermediate table.

3. **Fact**
   - `fct_trips`

   Generates a deterministic `trip_id`, joins zone and payment-type dimensions, calculates trip duration, and exposes the business-ready trip-level model as a view.

4. **Reporting Mart**
   - `fct_monthly_zone_revenue`

   Aggregates revenue and trip measures directly from `int_trips_unioned` by pickup zone, month, and service type. This is materialized as a table because it reduces approximately 12.9 million trip records to a compact reporting dataset.

5. **Dimensions & Supporting Models**
   - `dim_zones`
   - `dim_vendors`
   - `dim_payment_type`
   - `time_spine`

   These provide reusable dimensional and temporal context for reporting and semantic definitions.

6. **Semantic / Reporting Layer**
   - `monthly_zone_revenue_semantic`
   - `total_revenue`
   - `total_trips`
   - `monthly_revenue_by_zone_and_service`

   Provides reusable business metrics, dimensions, and a saved reporting query on top of the monthly revenue mart.

---

## 🚀 Quick Start & Execution

To run the pipeline and validate the test suite locally:

1.  **Run dbt models:**
    ```bash
    dbt run --threads 1
    ```

2.  **Execute data quality tests:**
    ```bash
    dbt test
    ```

---

## 📚 Generating & Viewing dbt Documentation

This project includes rich model lineage graphs, column descriptions, and test coverage documentation powered by dbt.

### 1. Generate Documentation Metadata
To compile and generate the documentation artifacts locally:
```bash
dbt docs generate
```
*Note: If you encounter metadata ingestion errors due to stale target files, clear your target directory first:*
```bash
rm -rf target/
dbt docs generate
```

### 2. Serve the Documentation Locally
To launch the local web server and view your lineage graphs and schema definitions:
```bash
dbt docs serve --port 8090
```
*(Access the interface by opening `http://127.0.0.1:8090` in your browser, or via SSH port forwarding if running inside a remote/WSL environment).*

---

## 📊 Analytics Engineering & Semantic Layer (`taxi_rides_ny`)

This project implements dbt semantic models, metrics, and saved queries on top of the taxi rides reporting mart, enabling standardized business metrics, dimensional slicing, and reusable reporting queries.

### 🌟 Semantic Models & Metrics Architecture

The semantic configuration defines the reporting model, business metrics, dimensions, entities, and reusable saved queries:

* **Primary Model (`fct_monthly_zone_revenue`)**: Aggregates enterprise trip volumes and fare amounts by pickup zone, month, and taxi service type (`Green` or `Yellow`).
* **Semantic Entities & Dimensions**:
  * **Entities**: `pickup_zone` (Foreign key mapping)
  * **Time Dimension**: `revenue_month` (Monthly granularity)
  * **Categorical Dimension**: `service_type`
* **Core Metrics**:
  * `total_revenue`: Sum of total monthly fares (`revenue_monthly_total_amount`).
  * `total_trips`: Count of total monthly trips (`total_monthly_trips`).

### 🔍 Saved Queries

* **`monthly_revenue_by_zone_and_service`**: A predefined query grouping total revenue and trip counts by `revenue_month`, `service_type`, and `pickup_zone`.

### 🛠️ Quick Commands

To parse, build, and view the updated documentation including your semantic layer and lineage:

```bash
# Parse configurations and check for validation errors
dbt parse

# Build the models and generate documentation artifacts
dbt build --select +monthly_revenue_by_zone_and_service+ && dbt docs generate

# Serve the local documentation UI
dbt docs serve --port 8090
```
