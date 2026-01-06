# Monitoring Guide - Simple Stream

**Time to Review:** ~5 minutes
**Prerequisites:** Completed [`03-TESTING.md`](03-TESTING.md) with active data flow

---

## Purpose

This guide explains how to monitor the Simple Stream pipeline using the built-in monitoring views and Snowflake system tables.

## Monitoring Overview

The pipeline includes **7 pre-built monitoring views** that provide real-time insights into:
- Ingestion rates and volumes
- End-to-end latency
- Task execution health
- Data quality metrics
- Cost tracking
- Channel status
- Active badges

All views are in the `RAW_INGESTION` schema.

---

## Core Monitoring Views

### 1. Ingestion Metrics (V_INGESTION_METRICS)

**Purpose:** Track ingestion rate, volume, and trends over time

**Query:**
```sql
SELECT
  ingestion_hour,
  event_count,
  events_per_second,
  unique_badges,
  unique_zones,
  avg_signal_strength,
  weak_signal_count,
  weak_signal_pct,
  entry_count,
  exit_count,
  net_occupancy_change
FROM RAW_INGESTION.V_INGESTION_METRICS
ORDER BY ingestion_hour DESC
LIMIT 24;
```

**Columns:**
| Column | Description | Example |
|--------|-------------|---------|
| `ingestion_hour` | Truncated hour timestamp | 2025-12-02 14:00:00 |
| `event_count` | Total events ingested in hour | 600 |
| `avg_events_per_minute` | Average rate | 10 |
| `unique_badges` | Distinct badge IDs seen | 15 |
| `unique_users` | Distinct user IDs seen | 12 |
| `unique_zones` | Distinct zone IDs seen | 4 |

**Use Cases:**
- Identify peak ingestion times
- Detect ingestion gaps or drops
- Capacity planning (events/hour trends)

**Alerts:**
- WARNING `event_count = 0` for >2 hours -> Ingestion stopped
- WARNING Sudden drop >50% -> Data source issue

---

### 2. End-to-End Latency (V_END_TO_END_LATENCY)

**Purpose:** Measure time from event occurrence to analytics availability

**Query:**
```sql
SELECT
  layer,
  last_update,
  seconds_since_update,
  row_count,
  health_status
FROM RAW_INGESTION.V_END_TO_END_LATENCY
ORDER BY seconds_since_update DESC
LIMIT 10;
```

**Columns:**
| Column | Description | Target |
|--------|-------------|--------|
| `lag_bucket` | Latency range (e.g., "0-60s") | - |
| `event_count` | Events in this bucket | - |
| `avg_latency_seconds` | Average latency | < 120s |
| `max_latency_seconds` | Maximum latency | < 180s |
| `p95_latency_seconds` | 95th percentile | < 150s |

**Use Cases:**
- SLA monitoring (are we meeting < 2 min target?)
- Identify processing bottlenecks
- Detect task scheduling delays

**Alerts:**
- WARNING `avg_latency_seconds > 180` -> Tasks not keeping up
- WARNING `max_latency_seconds > 300` -> Investigate warehouse sizing

**Troubleshooting:**
```sql
-- If latency is high, check task execution frequency
SELECT
    NAME,
    STATE,
    SCHEDULE,
    LAST_COMMITTED_ON
FROM TABLE(INFORMATION_SCHEMA.TASK_HISTORY())
WHERE NAME LIKE 'sfe_%'
ORDER BY SCHEDULED_TIME DESC
LIMIT 10;
```

---

### 3. Task Execution History (V_TASK_EXECUTION_HISTORY)

**Purpose:** Monitor task success rates, duration, and errors

**Query:**
```sql
SELECT
  task_name,
  state,
  scheduled_time,
  completed_time,
  duration_seconds,
  error_code,
  error_message,
  execution_status
FROM RAW_INGESTION.V_TASK_EXECUTION_HISTORY
ORDER BY scheduled_time DESC
LIMIT 20;
```

**Columns:**
| Column | Description | Healthy Value |
|--------|-------------|---------------|
| `task_name` | Task identifier | - |
| `scheduled_time` | When task was scheduled | Recent |
| `completed_time` | When task finished | Within 10s |
| `state` | SUCCESS / FAILED / SKIPPED | SUCCESS |
| `duration_seconds` | Execution time | < 10s |
| `error_message` | Failure details if any | NULL |
| `rows_processed` | Rows affected by task | > 0 |

**Use Cases:**
- Detect task failures
- Monitor processing performance
- Track rows processed per execution

**Alerts:**
- CRITICAL `state = 'FAILED'` -> Immediate investigation
- WARNING `duration_seconds > 30` -> Warehouse may be undersized
- WARNING `rows_processed = 0` for >5 executions -> No new data

**Common Error Patterns:**
```sql
-- Find recent task failures
SELECT
    task_name,
    error_message,
    COUNT(*) AS failure_count
FROM RAW_INGESTION.V_TASK_EXECUTION_HISTORY
WHERE state = 'FAILED'
  AND scheduled_time >= DATEADD('day', -1, CURRENT_TIMESTAMP())
GROUP BY 1, 2
ORDER BY failure_count DESC;
```

---

### 4. Data Quality Metrics (V_DATA_QUALITY_METRICS)

**Purpose:** Track data quality issues (duplicates, orphans, signal quality)

**Query:**
```sql
SELECT
  total_raw_events,
  total_staged_events,
  total_fact_events,
  duplicate_count,
  duplicate_rate_pct,
  orphan_user_count,
  orphan_zone_count,
  orphan_rate_pct,
  weak_signal_count,
  weak_signal_rate_pct
FROM RAW_INGESTION.V_DATA_QUALITY_METRICS;
```

**Metrics:**
| Metric | Description | Acceptable Range |
|--------|-------------|------------------|
| `total_raw_events` | Events in RAW table | Growing |
| `total_staged_events` | Events in STG table | ~95-98% of raw |
| `total_fact_events` | Events in FCT table | ~95-100% of staged |
| `duplicate_count` | Duplicates filtered | < 5% of raw |
| `duplicate_rate_pct` | Percentage duplicates (last 24h) | < 5% |
| `orphan_user_count` | Events with unknown user_id | 0 |
| `orphan_zone_count` | Events with unknown zone_id | 0 |
| `orphan_rate_pct` | Percentage orphans (last 24h) | 0% |
| `weak_signal_count` | Events with RSSI < -80 dBm | Varies |
| `weak_signal_rate_pct` | Percentage weak signals (last 24h) | < 10% |

**Use Cases:**
- Detect data quality degradation
- Identify missing dimension data
- Monitor RFID hardware health (signal strength)

**Alerts:**
- CRITICAL `orphan_rate > 5%` -> Dimension tables out of sync
- WARNING `duplicate_rate > 10%` -> Source system issue
- WARNING `weak_signal_rate > 20%` -> RFID reader placement or hardware issues

---

### 5. Streaming Costs (V_STREAMING_COSTS)

**Purpose:** Estimate credit consumption for cost tracking

**Query:**
```sql
SELECT
  ingestion_date,
  gb_ingested,
  rows_ingested,
  actual_credits_used,
  rows_per_gb
FROM RAW_INGESTION.V_STREAMING_COSTS
ORDER BY ingestion_date DESC
LIMIT 30;
```

**Columns:**
| Column | Description | Notes |
|--------|-------------|-------|
| `ingestion_date` | Date of ingestion activity | Daily aggregation |
| `gb_ingested` | Data volume ingested | - |
| `rows_ingested` | Rows ingested | - |
| `actual_credits_used` | Actual credits used | From SNOWPIPE streaming history |
| `rows_per_gb` | Ingestion density | Rows per GB |

**Formula:**
```
Credits = (GB ingested x 0.06) + (Task execution seconds / 3600 x Warehouse size)
Cost = Credits x Price per credit
```

**Use Cases:**
- Budget tracking and forecasting
- Cost anomaly detection
- Chargeback/showback reporting

**Alerts:**
- WARNING Daily cost increases >50% -> Investigate volume spike
- WARNING Cost per event increases -> Inefficient processing

---

### 6. Channel Status (V_CHANNEL_STATUS)

**Purpose:** Monitor Snowpipe Streaming channel health

**Query:**
```sql
SELECT
  pipe_name,
  last_ingestion_time,
  seconds_since_last_ingestion,
  total_rows_inserted,
  total_gb_inserted,
  active_minutes_last_hour,
  avg_rows_per_insert,
  max_rows_per_insert,
  total_credits_used
FROM RAW_INGESTION.V_CHANNEL_STATUS
ORDER BY last_ingestion_time DESC;
```

**Columns:**
| Column | Description | Healthy State |
|--------|-------------|---------------|
| `channel_name` | Unique channel identifier | - |
| `status` | OPEN / CLOSED / ERROR | OPEN or CLOSED |
| `last_poll_time` | Most recent activity | Recent |
| `rows_ingested` | Total rows via this channel | Growing |
| `bytes_ingested` | Total bytes | Growing |
| `error_count` | Errors encountered | 0 |

**Use Cases:**
- Detect channel errors or stalls
- Track active vs. closed channels
- Monitor ingestion volume per channel

**Alerts:**
- CRITICAL `status = 'ERROR'` -> Check pipe error messages
- WARNING `last_poll_time > 5 minutes ago` + `status = OPEN` -> Channel stalled

---

### 7. Active Badges (V_ACTIVE_BADGES)

**Purpose:** Track currently active badges in the system

**Query:**
```sql
SELECT
  badge_id,
  user_id,
  user_name,
  last_zone,
  last_seen,
  event_count_today
FROM RAW_INGESTION.V_ACTIVE_BADGES
ORDER BY last_seen DESC
LIMIT 50;
```

**Columns:**
| Column | Description | Use |
|--------|-------------|-----|
| `badge_id` | Badge identifier | - |
| `user_id` | Associated user | - |
| `user_name` | User full name | From dimension |
| `last_zone` | Last seen zone | - |
| `last_seen` | Most recent event | - |
| `event_count_today` | Events today | Activity level |

**Use Cases:**
- Real-time occupancy monitoring
- Identify inactive badges
- Security (unexpected badges)

---

## System-Level Monitoring

### Warehouse Utilization

**Check warehouse credit consumption:**
```sql
SELECT
    WAREHOUSE_NAME,
    START_TIME,
    END_TIME,
    CREDITS_USED,
    CREDITS_USED_COMPUTE,
    CREDITS_USED_CLOUD_SERVICES
FROM SNOWFLAKE.ACCOUNT_USAGE.WAREHOUSE_METERING_HISTORY
WHERE WAREHOUSE_NAME = 'COMPUTE_WH'
  AND START_TIME >= DATEADD('day', -7, CURRENT_TIMESTAMP())
ORDER BY START_TIME DESC;
```

**Warehouse efficiency:**
```sql
-- Check for idle time (credits wasted)
SELECT
    DATE_TRUNC('day', START_TIME) AS day,
    SUM(CREDITS_USED) AS total_credits,
    SUM(CASE WHEN CREDITS_USED_COMPUTE = 0 THEN CREDITS_USED ELSE 0 END) AS idle_credits,
    idle_credits / total_credits * 100 AS idle_percent
FROM SNOWFLAKE.ACCOUNT_USAGE.WAREHOUSE_METERING_HISTORY
WHERE WAREHOUSE_NAME = 'COMPUTE_WH'
  AND START_TIME >= DATEADD('day', -30, CURRENT_TIMESTAMP())
GROUP BY 1
ORDER BY 1 DESC;
```

**Target:** `idle_percent < 10%`

### Storage Growth

**Monitor database storage:**
```sql
SELECT
    TABLE_CATALOG AS database_name,
    TABLE_SCHEMA AS schema_name,
    SUM(ACTIVE_BYTES) / POWER(1024, 3) AS active_storage_gb,
    SUM(TIME_TRAVEL_BYTES) / POWER(1024, 3) AS time_travel_storage_gb,
    SUM(FAILSAFE_BYTES) / POWER(1024, 3) AS failsafe_storage_gb,
    SUM(ACTIVE_BYTES + TIME_TRAVEL_BYTES + FAILSAFE_BYTES) / POWER(1024, 3) AS total_storage_gb
FROM SNOWFLAKE.ACCOUNT_USAGE.TABLE_STORAGE_METRICS
WHERE TABLE_CATALOG = 'SNOWFLAKE_EXAMPLE'
  AND ACTIVE_BYTES > 0
GROUP BY 1, 2
ORDER BY total_storage_gb DESC;
```

**Alert:** Unexpected storage growth (>10% per day without corresponding event increase)

### Query Performance

**Check slowest queries:**
```sql
SELECT
    QUERY_ID,
    QUERY_TEXT,
    EXECUTION_STATUS,
    TOTAL_ELAPSED_TIME / 1000 AS execution_time_sec,
    BYTES_SCANNED / POWER(1024, 3) AS gb_scanned,
    PARTITIONS_SCANNED,
    PARTITIONS_TOTAL
FROM SNOWFLAKE.ACCOUNT_USAGE.QUERY_HISTORY
WHERE EXECUTION_STATUS = 'SUCCESS'
  AND START_TIME >= DATEADD('day', -1, CURRENT_TIMESTAMP())
  AND DATABASE_NAME = 'SNOWFLAKE_EXAMPLE'
ORDER BY TOTAL_ELAPSED_TIME DESC
LIMIT 10;
```

**Optimization Targets:**
- `execution_time_sec < 5` for OLTP queries
- `partitions_scanned / partitions_total < 0.1` (good pruning)

---

## Monitoring Dashboard SQL

**Copy/paste this into Snowsight for a real-time dashboard:**

```sql
-- ============================================================================
-- SIMPLE STREAM MONITORING DASHBOARD
-- Refresh this worksheet every 1-2 minutes for live monitoring
-- ============================================================================

USE SCHEMA RAW_INGESTION;

-- Summary Stats (Last Hour)
SELECT
    'Last Hour Summary' AS metric_group,
    COUNT(*) AS raw_events,
    COUNT(DISTINCT badge_id) AS unique_badges,
    COUNT(DISTINCT user_id) AS unique_users,
    AVG(signal_strength) AS avg_signal_strength
FROM RAW_BADGE_EVENTS
WHERE ingestion_time >= DATEADD('hour', -1, CURRENT_TIMESTAMP());

-- Recent Ingestion Rate (Last 10 Minutes)
SELECT
    'Ingestion Rate (Last 10 Min)' AS metric_group,
    COUNT(*) AS events,
    COUNT(*) / 10.0 AS events_per_minute
FROM RAW_BADGE_EVENTS
WHERE ingestion_time >= DATEADD('minute', -10, CURRENT_TIMESTAMP());

-- Task Health (Last 5 Executions)
SELECT
    'Task Health' AS metric_group,
    task_name,
    state,
    duration_seconds,
    rows_processed
FROM V_TASK_EXECUTION_HISTORY
WHERE scheduled_time >= DATEADD('hour', -1, CURRENT_TIMESTAMP())
ORDER BY scheduled_time DESC
LIMIT 5;

-- End-to-End Latency
SELECT
    'Latency' AS metric_group,
    avg_latency_seconds,
    max_latency_seconds,
    p95_latency_seconds
FROM V_END_TO_END_LATENCY
WHERE lag_bucket = '60-120s'
LIMIT 1;

-- Data Quality (Current)
SELECT
    'Data Quality' AS metric_group,
    duplicate_rate,
    orphan_rate,
    weak_signal_rate
FROM V_DATA_QUALITY_METRICS;

-- Active Right Now
SELECT
    'Active Badges (Last 5 Min)' AS metric_group,
    COUNT(DISTINCT badge_id) AS active_badges
FROM RAW_BADGE_EVENTS
WHERE ingestion_time >= DATEADD('minute', -5, CURRENT_TIMESTAMP());
```

---

## Alerting Recommendations

### Critical Alerts (Page On-Call)

| Condition | Query | Action |
|-----------|-------|--------|
| Task failure | `state = 'FAILED' IN V_TASK_EXECUTION_HISTORY` | Check error_message, resume task |
| Ingestion stopped | `event_count = 0 for >2 hours IN V_INGESTION_METRICS` | Check pipe status, verify data source |
| High orphan rate | `orphan_rate > 10% IN V_DATA_QUALITY_METRICS` | Sync dimension tables |

### Warning Alerts (Email/Slack)

| Condition | Query | Action |
|-----------|-------|--------|
| High latency | `avg_latency_seconds > 180 IN V_END_TO_END_LATENCY` | Check warehouse size, task frequency |
| High duplicate rate | `duplicate_rate > 10% IN V_DATA_QUALITY_METRICS` | Investigate source system |
| Cost spike | `Daily cost increase >50% IN V_STREAMING_COSTS` | Review event volume, optimize queries |

### Informational (Dashboard Only)

| Metric | View |
|--------|------|
| Hourly ingestion trends | V_INGESTION_METRICS |
| Active badge count | V_ACTIVE_BADGES |
| Signal strength distribution | V_DATA_QUALITY_METRICS |

---

## Troubleshooting Workflows

### Issue: "No data flowing"

**Steps:**
1. Check pipe status: `SHOW PIPES;`
2. Check channel status: `SELECT pipe_name, last_ingestion_time, seconds_since_last_ingestion, total_rows_inserted, total_credits_used FROM V_CHANNEL_STATUS;`
3. Check task status: `SHOW TASKS;` (should be `started`, not `suspended`)
4. Check for task errors: `SELECT task_name, state, scheduled_time, error_code, error_message FROM V_TASK_EXECUTION_HISTORY WHERE state = 'FAILED';`

### Issue: "High latency"

**Steps:**
1. Check task execution frequency: `V_TASK_EXECUTION_HISTORY`
2. Check warehouse size: `SHOW WAREHOUSES;`
3. Check for spill to disk: `Query profile for tasks -> look for bytes_spilled`
4. Consider increasing warehouse size or reducing task interval

### Issue: "Orphan records"

**Steps:**
1. Find orphaned IDs:
   ```sql
   SELECT DISTINCT user_id
   FROM RAW_BADGE_EVENTS
   WHERE user_id NOT IN (SELECT user_id FROM ANALYTICS_LAYER.DIM_USERS WHERE is_current = TRUE);
   ```
2. Add missing dimensions or fix source data to use valid IDs

---

## What's Next?

OK **Monitoring Setup Complete!**

**-> For Data Providers:**
- [`06-DATA-PROVIDER-QUICKSTART.md`](06-DATA-PROVIDER-QUICKSTART.md) - Send this to vendors (10-minute integration)
- [`05-API-HANDOFF.md`](05-API-HANDOFF.md) - Complete API reference (troubleshooting)

**Cleanup:** When done testing, see [`../sql/99_cleanup/cleanup.sql`](../sql/99_cleanup/cleanup.sql) to remove all objects

---

## Related Documentation

### Internal Team
- [`01-SETUP.md`](01-SETUP.md) - Prerequisites and setup
- [`02-DEPLOYMENT.md`](02-DEPLOYMENT.md) - Pipeline deployment
- [`03-TESTING.md`](03-TESTING.md) - Configure auth and test

### External Data Providers
- [`06-DATA-PROVIDER-QUICKSTART.md`](06-DATA-PROVIDER-QUICKSTART.md) - **Send to vendors** (10-minute integration)
- [`05-API-HANDOFF.md`](05-API-HANDOFF.md) - Complete API reference
- [`../diagrams/`](../diagrams/) - Architecture diagrams
