# Taxi Rides NY — Analytics Engineering Pipeline

An end-to-end analytics engineering project built with **dbt Core 2.0.6 and DuckDB**, using the NYC Taxi & Limousine Commission (TLC) Yellow Taxi and Green Taxi datasets.

The project demonstrates how I approach data engineering work beyond simply building transformations: **source validation, dimensional modeling, data quality testing, performance-conscious SQL, analytical modeling, reproducible validation, documentation, and business-oriented analysis.**

The final pipeline processes **12,932,048 validated 2019 taxi trips**, produces zone, revenue, activity and corridor analytics, and completes a staged execution with:

* **4/4 analytical execution phases successful**
* **48/48 dbt tests passed**
* **8/8 analytical validation checks passed**
* **0 validation failures**
* **0 remaining NV corridor records**
* **875,670 zone-activity rows**
* **37,398 corridor/service combinations**
* **664 persistent morning-rush corridors**

---

# Project Overview

The pipeline transforms raw NYC taxi trip data into tested and documented analytical models.

The project covers:

* Yellow Taxi and Green Taxi trip data
* Source-data validation and anomaly handling
* Restoration of missing Green Taxi source months
* Staging and intermediate transformations
* Dimensional modeling
* Monthly revenue analysis
* Zone-level activity analysis
* Weekday morning-rush analysis
* Origin-destination corridor analysis
* Persistent corridor analysis
* Business-oriented corridor opportunity ranking
* dbt data quality testing
* dbt documentation
* Semantic models, metrics and saved queries
* Reproducible SQL validation
* Performance-conscious DuckDB design

The current analytical focus is:

> **Which taxi zones and origin-destination corridors consistently show recorded activity during weekday morning rush hour, and where should deeper demand and capacity analysis be focused?**

The analysis deliberately distinguishes **observed completed taxi activity** from actual passenger demand or transportation capacity.

---

# Technology Stack

| Technology         | Purpose                                                         |
| ------------------ | --------------------------------------------------------------- |
| **dbt Core 2.0.6** | SQL transformations, model dependency management, testing, 
                        documentation, and analytical modeling |
| **DuckDB**         | Local analytical database and execution engine                  |
| **SQL**            | Transformation and analytical logic                             |
| **Jinja**          | dbt macros and reusable SQL logic                               |
| **dbt-utils**      | Data-quality and grain testing                                  |
| **Git / GitHub**   | Version control                                                 |
| **dbt Docs**       | Data catalog, lineage and model documentation                   |

The project is intentionally designed to run locally with controlled DuckDB resource usage.

---

# Data Architecture

The project evolved from a straightforward staging → intermediate → marts structure into a more deliberate analytical architecture.

```text
                         Raw TLC Data
                              │
                              ▼
                    ┌──────────────────┐
                    │ Staging Layer    │
                    │                  │
                    │ stg_yellow      │
                    │ stg_green       │
                    └────────┬─────────┘
                             │
                             ▼
                    ┌──────────────────┐
                    │ Intermediate     │
                    │ Layer            │
                    │                  │
                    │ int_trips_unioned│
                    │ monthly rollups  │
                    │ activity rollups │
                    │ corridor rollups │
                    │ morning spines   │
                    └────────┬─────────┘
                             │
                             ▼
                    ┌──────────────────┐
                    │ Core Marts       │
                    │                  │
                    │ fct_trips        │
                    │ dimensions       │
                    │ monthly revenue  │
                    └────────┬─────────┘
                             │
                             ▼
                  ┌──────────────────────┐
                  │ Analytical Marts     │
                  │                      │
                  │ zone activity        │
                  │ morning activity     │
                  │ morning corridors    │
                  │ persistent corridors │
                  │ opportunity ranking  │
                  └──────────┬───────────┘
                             │
                             ▼
                    Business Analysis
```

A major design principle is that **large trip-level data is aggregated before expensive downstream joins or grouping operations whenever possible.**

---

# 1. Source Data Investigation

Before building the analytical models, the source data was profiled to understand completeness, anomalies and the actual 2019 population.

This was important because the raw files could not simply be assumed to represent a complete and clean calendar year.

## Green Taxi source investigation

The original Green Taxi source contained missing months within the 2019 analytical period.

The missing official TLC monthly parquet files for March through August were restored and loaded individually.

| Month              |         Trips |
| ------------------ | ------------: |
| March              |       642,987 |
| April              |       567,819 |
| May                |       545,410 |
| June               |       506,185 |
| July               |       470,695 |
| August             |       449,659 |
| **Total restored** | **3,182,755** |

After restoration and date validation:

**Green Taxi 2019 = 5,235,874 trips**

The raw Green source had 5,236,040 rows, with 166 outside the 2019 analytical period.

## Yellow Taxi source investigation

The Yellow Taxi source contained 443 records outside the 2019 analytical period.

The staging model therefore uses an explicit half-open date boundary:

```text
2019-01-01 <= pickup_datetime < 2020-01-01
```

Final validated population:

**Yellow Taxi 2019 = 7,696,174 trips**

## Combined analytical population

| Service   |     2019 Trips |
| --------- | -------------: |
| Green     |      5,235,874 |
| Yellow    |      7,696,174 |
| **Total** | **12,932,048** |

These populations were explicitly reconciled before downstream analysis.

---

# 2. Staging Layer

The staging layer standardizes the Yellow and Green Taxi source datasets while applying source-specific data-quality rules.

## `stg_yellow_tripdata`

Responsibilities include:

* Vendor ID validation
* Payment type validation
* Pickup-date filtering
* Numeric normalization
* Consistent column naming

The final model contains:

**7,696,174 2019 Yellow Taxi trips**

## `stg_green_tripdata`

Responsibilities include:

* Vendor ID validation
* Pickup-date filtering
* Numeric normalization
* Consistent column naming
* Preservation of legitimate source nulls

Green Taxi `payment_type` was investigated rather than blindly constrained with a `not_null` test.

The source contains legitimate null payment types:

```text
NULL: 573,520
1:    2,635,390
2:    1,992,049
3:       24,370
4:       10,393
5:          152
```

The final Green Taxi population contains:

**5,235,874 2019 trips**

---

# 3. Core Intermediate Layer

## `int_trips_unioned`

Combines the standardized Green and Yellow datasets using:

```sql
UNION ALL
```

The model remains a **view**.

This is intentional.

Materializing another copy of approximately 13 million trip records created unnecessary storage and memory pressure. The logical union is sufficient for downstream models, while expensive analytical aggregations are handled through targeted intermediate models.

---

# 4. Core Mart Layer

## `fct_trips`

`fct_trips` is the main trip-level analytical view.

It provides:

* Deterministic trip ID
* Vendor
* Service type
* Pickup and drop-off zones
* Pickup and drop-off timestamps
* Trip duration
* Passenger count
* Trip distance
* Fare and surcharge components
* Total revenue
* Payment type
* Payment type description

### Trip ID design

The trip identifier is generated using an MD5 hash based on stable trip attributes including:

* Service type
* Vendor ID
* Pickup timestamp
* Pickup location
* Drop-off timestamp
* Total amount

A global uniqueness test over all 12.9 million trip rows was intentionally removed after it caused unnecessary memory pressure in DuckDB.

The project instead validates:

* Trip ID non-nullness
* Analytical grain uniqueness where it matters
* Referential integrity
* Other business-relevant constraints

The project also deliberately avoids blanket global deduplication because repeated-looking records were not sufficient evidence that those records represented erroneous duplicates.

---

# 5. Performance Optimization Milestone: Monthly Revenue

The original `fct_monthly_zone_revenue` design aggregated directly from the large trip-level union.

That worked logically, but profiling showed an expensive execution pattern:

```text
12,932,048 trip rows
        │
        ├── large join
        │
        ├── large hash aggregation
        │
        ▼
2,804 reporting rows
```

The final result only contained 2,804 rows, so repeatedly pushing the entire trip population through the final reporting model was unnecessary.

## Optimization

Two service-specific intermediate models were introduced:

```text
int_green_monthly_zone_revenue
int_yellow_monthly_zone_revenue
```

Each model:

1. Reads its staging model
2. Joins the zone dimension
3. Groups by zone and month
4. Calculates the required revenue/trip measures
5. Materializes the small aggregate as a table

The final reporting model simply performs:

```text
Green monthly aggregate
        +
Yellow monthly aggregate
        ↓
fct_monthly_zone_revenue
```

This changed the final model from processing the entire 12.9 million-row trip population to combining already aggregated service-specific datasets.

### Final reconciliation

| Service   |      Rows |          Trips |             Revenue |
| --------- | --------: | -------------: | ------------------: |
| Green     |     2,489 |      5,235,874 |      95,552,954.960 |
| Yellow    |       315 |      7,696,174 |     121,680,378.490 |
| **Total** | **2,804** | **12,932,048** | **217,233,333.450** |

The optimized model now completes in a fraction of a second in the local development environment.

---

# 6. Performance Optimization Milestone: Zone Activity

`fct_zone_activity` initially attempted to aggregate the combined Green + Yellow trip population in a single operation.

That approach produced severe memory pressure and, under constrained DuckDB execution, eventually resulted in a Rust alternative-stack allocation failure.

## Optimization

The aggregation was split by service:

```text
stg_green_tripdata
        │
        ▼
int_green_zone_activity

stg_yellow_tripdata
        │
        ▼
int_yellow_zone_activity

        │
        └──────────────┐
                       ▼
                fct_zone_activity
```

Each service-specific model is materialized as a table and aggregates directly from staging.

This reduced the working set for each expensive aggregation.

## Invalid duration handling

The raw data also contained invalid trip durations:

* Green: **249 invalid durations**
* Yellow: **4 invalid durations**
* Total: **253 invalid durations**

Rather than discarding the entire trips, the models:

* Retain the trips for trip counts, revenue and other measures
* Exclude invalid timestamp pairs from duration calculations

The final average duration therefore uses:

```text
total_duration_minutes
/
valid_duration_trips
```

with protection against division by zero.

## Final validation

`fct_zone_activity` contains:

**875,670 rows**

with:

**875,670 distinct analytical grain keys**

The validated grain is:

```text
activity_date
× activity_hour
× pickup_location_id
× service_type
```

---

# 7. Zone Activity Model

## `fct_zone_activity`

The model aggregates recorded activity by:

* Activity date
* Activity hour
* Day type
* Time period
* Service type
* Pickup zone

Metrics include:

* Total trips
* Total passengers
* Total revenue
* Total distance
* Average trip distance
* Average trip duration

Morning rush is defined as:

**07:00–10:00 on weekdays**

The model contains:

**875,670 rows**

This model measures **observed completed taxi activity**.

It does not measure:

* Total passenger demand
* Available taxi supply
* Rejected requests
* Cancellations
* Waiting time
* Unserved passengers
* Fleet utilization

---

# 8. Morning-Rush Baseline

The project does not assume that every 2019 weekday is equally suitable for comparison.

## `int_weekday_morning_spine`

Generates the complete weekday calendar for 2019.

Expected population:

**261 weekdays**

## Source completeness investigation

The morning-rush source population was then profiled by date.

The investigation identified:

* **39 weekdays** with no recorded morning-rush activity anywhere in the source
* **2 severely incomplete observed dates**
* **4 holiday/outlier dates**

The severely incomplete dates were:

* 2019-02-01
* 2019-02-04

The holiday/outlier dates were:

* Memorial Day
* Independence Day
* Thanksgiving
* Christmas

The resulting comparison population is:

**216 normal comparison weekdays**

The baseline therefore follows:

```text
261 expected weekdays
        ↓
222 weekdays with observed morning activity
        ↓
39 completely missing weekdays
        ↓
exclude 2 severe anomalies
        ↓
exclude 4 holiday/outlier dates
        ↓
216 normal comparison weekdays
```

This creates a controlled analytical baseline rather than treating missing source activity as zero demand.

---

# 9. `fct_zone_morning_activity`

This model summarizes weekday morning-rush activity by pickup zone across the controlled comparison period.

Metrics include:

* Expected comparison weekdays
* Observed weekdays
* Positive activity days
* Recorded activity rate
* Total trips
* Average daily trips
* Median daily trips
* P25 daily trips
* P75 daily trips
* Minimum daily trips
* Maximum daily trips

Validated population:

**257 observed pickup zones**

The strongest persistent recorded activity includes zones such as:

* East Harlem North
* East Harlem South
* Central Harlem

## East Harlem North

East Harlem North provides the strongest example of persistent recorded morning-rush activity.

Across the 216 normal comparison weekdays:

* Activity observed on **216 / 216 days**
* Recorded activity rate: **100%**
* Median: **301 trips/day**
* P25: **272 trips/day**
* P75: **330 trips/day**
* Total recorded morning-rush trips: **69,142**
* Average: **320.1 trips/day**
* Minimum: **132**
* Maximum: **631**

This persistence is more informative than simply ranking zones by annual trip volume.

---

# 10. Performance Optimization Milestone: Morning Corridors

The next analytical step was to move from pickup zones to origin-destination flows.

The original combined morning-rush corridor aggregation attempted to process the large morning-rush population in one operation.

Under constrained DuckDB execution, that approach produced:

```text
failed to allocate an alternative stack
```

## Optimization

The corridor aggregation was split by service:

```text
stg_green_tripdata
        │
        ▼
int_green_morning_corridor

stg_yellow_tripdata
        │
        ▼
int_yellow_morning_corridor

        │
        └──────────────┐
                       ▼
              corridor analytical marts
```

This follows the same principle used for zone activity:

> **Reduce the working set before performing expensive downstream analytical operations.**

The Green and Yellow intermediate corridor tables aggregate independently before being combined into the final analytical models.

Location ID `264`, representing the `NV` placeholder geography, was explicitly excluded from the corridor analysis.

---

# 11. Morning-Rush Corridor Analysis

The business question becomes:

> **Which origin-destination corridors show persistent passenger movement during weekday morning rush, and where might those recurring flows inform future vehicle-positioning analysis?**

This is deliberately a progression:

```text
Zone activity
      ↓
Recurring passenger flows
      ↓
Potential positioning opportunities
      ↓
Demand vs. supply analysis
```

The current corridor models measure **completed-trip movement**, not unmet demand.

---

# 12. `fct_zone_morning_corridor`

Builds the origin-destination corridor dataset for weekday morning rush.

Logical grain:

```text
pickup_location_id
× dropoff_location_id
× service_type
```

Metrics include:

* Expected comparison weekdays
* Active days
* Corridor activity rate
* Total trips
* Total passengers
* Total revenue
* Total distance
* Average trip distance
* Revenue per trip
* Average trip duration

The validated final population contains:

**37,398 unique corridor/service combinations**

with:

**0 remaining `NV` corridors**

The service-specific intermediate models contained:

```text
Green corridor day rows: 321,544
Green trips:             595,598

Yellow corridor day rows: 97,285
Yellow trips:             880,453
```

Combined morning-rush corridor trips:

**1,476,051**

---

# 13. `fct_persistent_morning_corridor`

The persistent corridor model filters the corridor population to flows that recorded activity on at least:

**100 of the 216 normal comparison weekdays**

Persistence is therefore defined as:

```text
active_days / 216 comparison weekdays
```

The resulting model contains:

**664 persistent corridors**

This removes highly sporadic flows from the business-facing opportunity population.

---

# 14. `fct_morning_corridor_opportunity`

The opportunity model separates four different signals.

## Scale

How much completed-trip volume does the corridor generate?

```text
total_trips
```

## Intensity

How many completed trips occur on an average active day?

```text
avg_trips_per_active_day
```

## Yield

How much completed-trip revenue is generated per trip?

```text
revenue_per_trip
```

## Persistence

How consistently does the corridor appear across the comparison period?

```text
persistence_pct
```

These signals are intentionally kept separate.

A corridor can be:

* High volume but low yield
* High yield but low volume
* Highly persistent but relatively small
* Large and persistent but not necessarily underserved

The opportunity model contains:

**664 persistent corridors**

with the validated grain:

```text
pickup_location_id
× dropoff_location_id
× service_type
```

---

# 15. Corridor Results

Examples of persistent high-volume Green Taxi corridors include:

| Pickup → Drop-off                           | Active Days | Total Trips | Avg Trips / Active Day |
| ------------------------------------------- | ----------: | ----------: | ---------------------: |
| East Harlem North → East Harlem South       |         216 |      12,811 |                   59.3 |
| East Harlem South → East Harlem North       |         216 |       7,597 |                   35.2 |
| East Harlem North → Morningside Heights     |         216 |       6,919 |                   32.0 |
| East Harlem South → East Harlem South       |         216 |       5,971 |                   27.6 |
| East Harlem North → East Harlem North       |         216 |       5,776 |                   26.7 |
| Central Harlem North → Central Harlem North |         216 |       4,914 |                   22.8 |
| East Harlem North → Central Harlem          |         215 |       4,900 |                   22.8 |
| Central Harlem → East Harlem North          |         216 |       4,651 |                   21.5 |
| East Harlem North → Upper East Side North   |         216 |       4,566 |                   21.1 |

These results demonstrate why zone-level activity alone is not sufficient for operational analysis.

A zone can have high activity, but the destination pattern provides additional information about recurring passenger movement.

---

# 16. Corridor Economics

The persistent corridor model also provides completed-trip revenue measures.

| Corridor                                  | Total Revenue | Avg Revenue / Active Day | Revenue / Trip |
| ----------------------------------------- | ------------: | -----------------------: | -------------: |
| East Harlem North → East Harlem South     |   $127,026.35 |                  $588.08 |          $9.92 |
| East Harlem South → East Harlem North     |    $56,668.82 |                  $262.36 |          $7.46 |
| East Harlem North → Morningside Heights   |    $78,491.18 |                  $363.39 |         $11.34 |
| East Harlem North → Upper East Side North |    $75,054.14 |                  $347.47 |         $16.44 |

These are **completed-trip revenue measures, not profit**.

They should therefore be interpreted as commercial activity indicators rather than profitability estimates.

---

# 17. Opportunity Query Guardrail

The reusable opportunity model does not hard-code a volume threshold.

For focused business reporting, the analysis applies a **1,000-trip reporting guardrail**:

```sql
select
    pickup_zone,
    dropoff_zone,
    service_type,
    total_trips,
    persistence_pct,
    round(avg_trips_per_active_day, 2) as avg_trips_per_active_day,
    round(revenue_per_trip, 2) as revenue_per_trip
from main.fct_morning_corridor_opportunity
where total_trips >= 1000
order by
    total_trips desc,
    persistence_pct desc,
    revenue_per_trip desc
limit 20;
```

The threshold belongs in the business query rather than the reusable model because different stakeholders may want different definitions of materiality.

---

# 18. Performance Optimization Milestone: Vendor Dimension

The original `dim_vendors` model derived the vendor dimension using:

```text
DISTINCT vendor_id
```

from the full `fct_trips` view.

That meant scanning the entire 12.9 million-row trip population to produce only four vendor records.

This was unnecessary.

## Optimization

The vendor dimension was converted to a static four-row mapping:

| Vendor ID | Vendor                       |
| --------: | ---------------------------- |
|         1 | Creative Mobile Technologies |
|         2 | VeriFone Inc.                |
|         4 | Unknown/Other                |
|         5 | NULL                         |

The resulting model builds almost instantly and preserves the required vendor mapping without repeatedly scanning the trip population.

This is a good example of a broader principle used throughout the project:

> **Do not derive a small static dimension by repeatedly scanning a very large fact source when the business mapping is already known.**

---

# 19. Data Quality and Testing

Data quality is treated as part of transformation design rather than as a final validation step.

The project uses:

* `not_null`
* `unique`
* `accepted_values`
* `relationships`
* `dbt_utils.unique_combination_of_columns`

Tests cover:

* Dimension keys
* Vendor identifiers
* Payment types
* Zone relationships
* Analytical model grain
* Pickup-zone uniqueness
* Activity grain
* Corridor grain
* Service-type domains
* Time-period domains
* Day-type domains

## Final dbt test result

The complete test suite currently contains:

**48 tests**

Final result:

```text
48 total
48 success
0 failures
0 errors
```

The test suite completes successfully with dbt 2.0.6.

---

# 20. Analytical Validation

The project supplements dbt's generic tests with explicit SQL validation.

The final validation script:

```text
scripts/validation/validate_morning_activity.sql
```

checks eight project-level assumptions.

Final result:

**8/8 PASS**

| Model                              | Validation                            |
| ---------------------------------- | ------------------------------------- |
| `fct_trips`                        | Payment type accepted values          |
| `fct_trips`                        | Pickup location relationship          |
| `fct_trips`                        | Trip ID non-null                      |
| `fct_zone_activity`                | Grain integrity                       |
| `fct_zone_activity`                | Population reconciliation             |
| `fct_zone_morning_activity`        | Zone population reconciliation        |
| `int_normal_weekday_morning_spine` | 216-day population reconciliation     |
| `int_weekday_morning_spine`        | 261-weekday population reconciliation |

The important distinction is that some checks are **population reconciliation checks**, not generic rules.

For example:

```text
fct_zone_activity = 875,670 rows
```

is a known analytical population that is explicitly reconciled.

---

# 21. Payment Type Validation

The final `fct_trips` payment-type distribution is:

| Payment Type |     Trips |
| -----------: | --------: |
|            0 |    28,672 |
|            1 | 8,121,439 |
|            2 | 4,129,156 |
|            3 |    57,551 |
|            4 |    21,558 |
|            5 |       152 |
|         NULL |   573,520 |

All values are either:

```text
NULL
```

or valid TLC payment codes:

```text
0–5
```

A generic `accepted_values` test over the 12.9 million-row `fct_trips` view created unnecessary memory pressure.

The project therefore uses an explicit analytical validation for this condition rather than forcing the expensive full-table generic test.

The final validation returns:

```text
12,932,048 / 12,932,048 valid
PASS
```

---

# 22. Engineering Challenges and Solutions

## Challenge 1 — Incomplete source data

The Green Taxi source was missing official 2019 months.

### Solution

I profiled the source before defining the analytical population, restored the missing official TLC monthly files, and rebuilt the staging layer.

Result:

**5,235,874 validated Green Taxi trips**

---

## Challenge 2 — Date anomalies

The raw sources contained records outside the intended analytical period.

### Solution

The staging layer uses explicit half-open date boundaries:

```text
2019-01-01 <= pickup_datetime < 2020-01-01
```

This produces reproducible 2019 populations rather than relying on file boundaries.

---

## Challenge 3 — Large trip-level intermediate model

A generic materialized trip-level intermediate table unnecessarily duplicated approximately 13 million records.

### Solution

`int_trips_unioned` remains a view.

Large analytical operations are performed through targeted aggregates rather than repeatedly materializing the full trip population.

---

## Challenge 4 — Monthly revenue aggregation was too expensive

The original monthly revenue model pushed the full trip population through a large join and aggregation.

### Solution

I introduced:

```text
int_green_monthly_zone_revenue
int_yellow_monthly_zone_revenue
```

Each service is aggregated independently before the final reporting union.

Result:

```text
12.9M trip-level rows
        ↓
small service-specific aggregates
        ↓
2,804 final reporting rows
```

---

## Challenge 5 — Zone activity aggregation caused memory pressure

The combined Green + Yellow activity aggregation created an oversized working set.

### Solution

I split the aggregation into:

```text
int_green_zone_activity
int_yellow_zone_activity
```

Both are materialized as tables before being combined downstream.

Result:

**875,670 validated activity rows**

---

## Challenge 6 — Corridor aggregation triggered Rust stack allocation failure

The combined morning-rush corridor aggregation produced:

```text
failed to allocate an alternative stack
```

### Solution

I applied the same service-splitting strategy:

```text
int_green_morning_corridor
int_yellow_morning_corridor
```

The downstream corridor models operate on these smaller pre-aggregated datasets.

Result:

**37,398 corridor/service combinations**

and:

**664 persistent corridors**

---

## Challenge 7 — Static vendor dimension scanned 12.9M trips

The original `dim_vendors` implementation used `DISTINCT` over `fct_trips`.

### Solution

The dimension was replaced with a static mapping containing the four observed vendor IDs.

Result:

A four-row dimension that builds almost instantly.

---

## Challenge 8 — Global trip-ID uniqueness test caused memory pressure

A full uniqueness test across the trip-level fact view was unnecessarily expensive.

### Solution

The project validates trip ID non-nullness and enforces uniqueness at analytical grains where uniqueness has business meaning.

This keeps the automated test suite useful without making a global scan the most expensive part of validation.

---

## Challenge 9 — Morning-rush baseline contained missing and anomalous dates

A naive weekday comparison would have treated source gaps and holidays as normal zero-activity days.

### Solution

The source was profiled first.

The resulting baseline distinguishes:

```text
261 expected weekdays
222 observed weekdays
39 completely missing weekdays
216 normal comparison weekdays
```

This produces a more defensible persistence metric.

---

# 23. DuckDB Resource Strategy

The project is intentionally designed around constrained local analytical execution.

The current dbt profile uses:

```yaml
threads: 1

settings:
  memory_limit: '8GB'
  temp_directory: '/home/waigisteve/zoomcamp/data-engineering-zoomcamp/duckdb_tmp'
  preserve_insertion_order: false
  threads: 1
```

The design principle is not:

> "Give DuckDB more memory until the query works."

Instead, the project repeatedly applies:

```text
Reduce input
    ↓
Aggregate early
    ↓
Split large operations
    ↓
Materialize useful small intermediates
    ↓
Join / combine reduced datasets
```

The increase to an 8 GB development limit was useful during diagnosis, but it did not replace query optimization. The largest improvements came from changing the execution shape.

---

# 24. Full Execution Strategy

A monolithic:

```bash
dbt build --threads 1
```

was tested repeatedly.

The complete graph encountered a DuckDB/dbt runtime failure:

```text
failed to allocate an alternative stack:
Cannot allocate memory (os error 12)
```

This occurred during graph execution despite:

* `threads: 1`
* controlled DuckDB memory
* temporary-directory configuration
* optimized models
* cleaned dbt target metadata

Importantly, the individual execution stages remained stable.

Rather than hiding this limitation or continuing to increase memory allocation, the project uses a **phased execution strategy**.

This is the reproducible execution path:

```text
Phase 1
Core models
    ↓
Phase 2
Zone activity
    ↓
Phase 3
Morning activity
    ↓
Phase 4
Corridor analysis
    ↓
48 dbt tests
    ↓
8 analytical validation checks
```

The complete phased pipeline currently executes successfully.

---

# 25. Reproducible Project Runner

The repository contains:

```text
run_project_phased.sh
```

Run the complete project with:

```bash
./run_project_phased.sh
```

The runner executes four phases.

## Phase 1 — Core models

```text
staging
dimensions
int_trips_unioned
monthly revenue
fct_trips
```

Validated result:

```text
8 models
8 success
```

## Phase 2 — Zone activity

```text
fct_zone_activity
```

Validated result:

```text
1 model
1 success
```

## Phase 3 — Morning activity

```text
time_spine
int_weekday_morning_spine
int_normal_weekday_morning_spine
fct_zone_morning_activity
```

Validated result:

```text
4 models
4 success
```

## Phase 4 — Corridor analysis

```text
fct_zone_morning_corridor
fct_persistent_morning_corridor
fct_morning_corridor_opportunity
```

Validated result:

```text
3 models
3 success
```

The runner then executes:

```text
48 dbt tests
```

followed by:

```text
8 analytical validation checks
```

Final output:

```text
========================================
✓ FULL PROJECT RUN COMPLETED
========================================
```

This staged runner is the project's **validated local execution path**.

---

# 26. Final Execution Result

The latest complete run produced:

```text
PHASE 1
8 / 8 models successful

PHASE 2
1 / 1 model successful

PHASE 3
4 / 4 models successful

PHASE 4
3 / 3 models successful

DBT TEST SUITE
48 / 48 tests successful

ANALYTICAL VALIDATION
8 / 8 checks PASS

FULL PROJECT RUN COMPLETED
```

This is the current reproducible project checkpoint.

---

# 27. dbt Warnings

The successful execution currently reports three non-blocking warnings.

## Legacy semantic-model YAML

dbt reports:

```text
SemanticModelDeprecated (dbt1157)
```

The project currently uses legacy semantic-model/metric YAML definitions.

The implementation is retained intentionally for the current project scope and is documented rather than misrepresented as the newest dbt Semantic Layer implementation.

## Macro argument metadata

dbt also reports two `ValidateMacroArgs` warnings for:

```text
get_trip_duration_minutes
```

The macro currently documents `pickup_datetime` and `dropoff_datetime` as `timestamp`, while dbt 2.0.6 does not accept `timestamp` as a supported macro argument metadata type.

These warnings do not prevent model execution or validation.

The warnings are therefore treated as **documentation/schema metadata cleanup items**, not pipeline failures.

---

# 28. Semantic Layer

The project includes semantic definitions for monthly zone revenue.

## Semantic model

```text
monthly_zone_revenue_semantic
```

## Dimensions

* `revenue_month`
* `service_type`
* `pickup_zone`

## Metrics

* `total_revenue`
* `total_trips`

## Saved query

```text
monthly_revenue_by_zone_and_service
```

The saved query provides:

* Month
* Service type
* Pickup zone
* Total revenue
* Total trips

The current implementation uses dbt's legacy semantic-model YAML definitions. It is not presented as the modern dbt Semantic Layer implementation.

---

# 29. dbt Documentation

Generate project documentation with:

```bash
~/.local/bin/dbt docs generate --threads 1
```

Serve it with:

```bash
~/.local/bin/dbt docs serve --port 8090
```

Then open:

```text
http://localhost:8090
```

The documentation exposes:

* Models
* Columns
* Descriptions
* Tests
* Sources
* Seeds
* Macros
* Model lineage
* Semantic definitions
* Metrics
* Saved queries

The analytical documentation explicitly distinguishes recorded activity from demand and supply.

For example:

> Recorded activity measures source observations; it does not measure passenger demand or taxi supply.

---

# 30. Reproducible Validation

Dedicated validation SQL lives under:

```text
scripts/validation/
```

## Source validation

```bash
duckdb ~/zoomcamp/data-engineering-zoomcamp/taxi_rides.duckdb \
  < scripts/validation/validate_source_data.sql
```

Validates the expected 2019 source populations:

```text
Green:  5,235,874
Yellow: 7,696,174
Total:  12,932,048
```

## Core model validation

```bash
duckdb ~/zoomcamp/data-engineering-zoomcamp/taxi_rides.duckdb \
  < scripts/validation/validate_core_models.sql
```

Validates core model structure and population reconciliation.

## Morning activity validation

```bash
duckdb ~/zoomcamp/data-engineering-zoomcamp/taxi_rides.duckdb \
  < scripts/validation/validate_morning_activity.sql
```

Validates:

* `fct_zone_activity` grain
* Activity population
* Morning activity population
* 261 weekday population
* 216 normal comparison weekday population
* Pickup-zone relationships
* Trip ID non-nullness
* Payment-type validity

Final result:

**8/8 PASS**

## Additional analytical validation

The project also contains dedicated validation scripts for:

* Morning baseline construction
* Morning exclusions
* Corridor analysis

These scripts support investigation and reproducibility of the analytical decisions made during development.

---

# 31. Running the Project

## Verify dbt

```bash
~/.local/bin/dbt --version
```

Expected dbt version:

```text
dbt-core: 2.0.6
```

## Parse the project

```bash
~/.local/bin/dbt parse
```

## Run the validated pipeline

```bash
./run_project_phased.sh
```

This is the recommended full-project execution path.

## Run a specific model

For example:

```bash
~/.local/bin/dbt run --threads 1 --select fct_zone_morning_activity
```

or:

```bash
~/.local/bin/dbt run --threads 1 --select fct_morning_corridor_opportunity
```

## Run tests

```bash
~/.local/bin/dbt test --threads 1
```

Expected:

```text
48 total
48 success
```

## Generate documentation

```bash
~/.local/bin/dbt docs generate --threads 1
```

## Serve documentation

```bash
~/.local/bin/dbt docs serve --port 8090
```

---

# 32. Project Structure

```text
taxi_rides_ny/
│
├── models/
│   ├── staging/
│   │   ├── stg_yellow_tripdata.sql
│   │   ├── stg_green_tripdata.sql
│   │   ├── schema.yml
│   │   └── sources.yml
│   │
│   ├── intermediate/
│   │   ├── int_trips_unioned.sql
│   │   ├── int_green_monthly_zone_revenue.sql
│   │   ├── int_yellow_monthly_zone_revenue.sql
│   │   ├── int_green_zone_activity.sql
│   │   ├── int_yellow_zone_activity.sql
│   │   ├── int_green_morning_corridor.sql
│   │   ├── int_yellow_morning_corridor.sql
│   │   ├── int_weekday_morning_spine.sql
│   │   ├── int_normal_weekday_morning_spine.sql
│   │   └── schema.yml
│   │
│   └── marts/
│       ├── fct_trips.sql
│       ├── dim_zones.sql
│       ├── dim_vendors.sql
│       ├── dim_payment_type.sql
│       ├── schema.yml
│       │
│       └── reporting/
│           ├── fct_monthly_zone_revenue.sql
│           ├── fct_zone_activity.sql
│           ├── fct_zone_morning_activity.sql
│           ├── fct_zone_morning_corridor.sql
│           ├── fct_persistent_morning_corridor.sql
│           ├── fct_morning_corridor_opportunity.sql
│           ├── time_spine.sql
│           ├── schema.yml
│           └── saved_queries.yml
│
├── macros/
│   ├── classify_day_type.sql
│   ├── classify_trip_time.sql
│   ├── get_trip_duration_minutes.sql
│   ├── get_vendor_data.sql
│   ├── macros_properties.yml
│   └── safe_cast.sql
│
├── seeds/
│   ├── payment_type_lookup.csv
│   ├── taxi_zone_lookup.csv
│   └── seeds_properties.yml
│
├── scripts/
│   └── validation/
│       ├── validate_source_data.sql
│       ├── validate_core_models.sql
│       ├── validate_morning_activity.sql
│       ├── validate_morning_baseline.sql
│       ├── validate_morning_exclusions.sql
│       └── validate_morning_corridors.sql
│
├── load_missing_green_2019.sh
├── run_project_phased.sh
├── dbt_project.yml
├── packages.yml
└── README.md
```

---

# 33. Final Analytical Checkpoints

The final project state can be summarized as:

```text
Raw TLC Sources
      ↓
Source completeness investigation
      ↓
5,235,874 Green
7,696,174 Yellow
      ↓
12,932,048 validated trips
      ↓
Core trip and revenue models
      ↓
Performance optimization
      ↓
875,670 zone-activity rows
      ↓
261 expected weekdays
      ↓
216 normal comparison weekdays
      ↓
257 observed pickup zones
      ↓
37,398 morning corridor/service combinations
      ↓
664 persistent corridors
      ↓
Business opportunity ranking
      ↓
48/48 dbt tests
      ↓
8/8 analytical validation checks
      ↓
FULL PROJECT RUN COMPLETED
```

---

# 34. Business Analysis: Where Is Recorded Activity?

The first analytical question is:

> **Which pickup zones consistently show recorded taxi activity during weekday morning rush hour?**

Morning rush is defined as:

**07:00–10:00 on weekdays**

The analysis identifies persistent recorded activity in zones including East Harlem North, East Harlem South and Central Harlem.

The important analytical distinction is that persistence is evaluated against a controlled 216-day comparison baseline rather than simply using annual trip volume.

---

# 35. Business Analysis: Where Are the Recurring Corridors?

The corridor analysis extends the zone-level analysis by asking:

> **Where do the completed trips from active pickup zones actually go?**

This provides an additional operational dimension:

```text
Pickup zone
     +
Destination zone
     +
Service type
     ↓
Recurring corridor
```

The most persistent flows can then be compared by:

* Scale
* Intensity
* Yield
* Persistence
* Service type

This is more useful for operational investigation than a simple top-zones ranking.

---

# 36. Interpretation

These results identify zones and corridors with:

**persistent recorded morning-rush taxi activity.**

They do **not** establish that a zone is underserved.

For example:

> High trip volume does not automatically mean insufficient transportation capacity.

A zone could have high completed-trip activity because it has:

* High passenger demand
* High taxi availability
* Strong taxi positioning
* High vehicle turnover
* A combination of these

Similarly, low recorded activity could represent:

* Low demand
* Low taxi availability
* Missing source data
* Alternative transportation options
* Other operational factors

The current dataset records completed taxi trips, so it cannot directly measure:

* Unfulfilled ride requests
* Available taxi supply
* Waiting time
* Rejected requests
* Cancellations
* Unserved passengers
* Fleet utilization

Those measurements require additional demand and supply data.

---

# 37. Analytical Roadmap

The project is structured around progressively stronger business questions.

## 1. Where is activity?

Identify zones, times and services where taxi activity is concentrated.

**Implemented.**

## 2. Where is the money?

Measure revenue concentration by:

* Zone
* Month
* Service type
* Trip characteristics
* Corridor

**Implemented.**

## 3. Where are the recurring corridors?

Analyze:

```text
Pickup Zone → Drop-off Zone
```

during weekday morning rush.

**Implemented.**

The corridor layer measures:

* Corridor volume
* Passenger volume
* Persistence
* Daily intensity
* Revenue per trip
* Revenue per active day
* Green vs Yellow service mix

## 4. Where is transportation demand underserved?

Compare demand against available supply.

This requires additional signals such as:

* Ride requests
* Rejected requests
* Cancelled requests
* Available vehicles
* Wait times
* Vehicle positioning

**Not currently measurable from the trip dataset alone.**

## 5. Why does the gap exist?

Future analysis could incorporate:

* Weather
* Traffic
* Events
* Transit disruptions
* Seasonality
* Major passenger influxes

The objective would be to distinguish a structural service gap from a temporary or externally driven anomaly.

---

# 38. Key Engineering Takeaways

### Data quality comes before analysis

The source data was profiled before analytical baselines were defined.

Missing Green Taxi months, out-of-period records, incomplete dates and placeholder geography were investigated rather than silently accepted.

### Performance is part of model design

The largest performance improvements came from changing query shape:

```text
large raw population
        ↓
service-specific aggregation
        ↓
small intermediate tables
        ↓
final analytical models
```

### Aggregate before joining where possible

Monthly revenue, zone activity and corridor analysis all benefited from pre-aggregation.

### Do not materialize large datasets without a reason

`int_trips_unioned` remains a view because another 12.9 million-row copy provided little analytical value.

### Static dimensions should remain static

The vendor dimension does not need to scan millions of fact rows to return four mappings.

### Tests should reflect business grain

Not every model requires global uniqueness.

A test is useful when it validates an assumption that matters at the model's actual grain.

### Controlled baselines produce stronger analysis

A calendar weekday is not automatically a valid comparison day.

The morning-rush analysis explicitly distinguishes:

```text
expected
observed
missing
incomplete
holiday/outlier
normal comparison
```

### Completed trips are not the same as demand

A trip dataset tells us what happened successfully.

It does not tell us how many passengers requested a ride and failed to obtain one.

### Corridor analysis adds operational context

Zone-level activity identifies where trips originate.

Corridor analysis adds destination behavior and exposes recurring passenger movement.

### Scale, intensity, yield and persistence are different signals

A corridor can be large without being high-yield, high-yield without being persistent, or persistent without being the largest by volume.

Keeping these measures separate produces a more defensible business ranking.

### Resource constraints can reveal better architecture

The DuckDB memory and runtime failures were not solved simply by allocating more memory.

They exposed opportunities to:

* Aggregate earlier
* Split large operations
* Avoid unnecessary scans
* Materialize only useful intermediates
* Reduce global operations
* Control execution concurrency

### Good analytics narrows the next question

The current analysis identifies zones and corridors with persistent recorded activity.

The next analytical step is not to declare those areas underserved.

It is to combine the completed-trip evidence with **demand, supply, waiting-time and operational data** to determine where actual transportation capacity gaps exist.
