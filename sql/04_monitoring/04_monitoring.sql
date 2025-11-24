/*******************************************************************************
 * DEMO PROJECT: sfe-simple-stream
 * Script: Monitoring Views
 * 
 * WARNING:  NOT FOR PRODUCTION USE - EXAMPLE IMPLEMENTATION ONLY
 * 
 * PURPOSE:
 *   Create comprehensive monitoring views for tracking ingestion health,
 *   performance, and data quality across the pipeline.
 * 
 * VIEWS CREATED:
 *   1. V_CHANNEL_STATUS: Channel health (FILE_MIGRATION_HISTORY)
 *   2. V_INGESTION_METRICS: Throughput and volume metrics
 *   3. V_END_TO_END_LATENCY: Pipeline latency tracking
 *   4. V_DATA_FRESHNESS: Last event timestamps
 *   5. V_PARTITION_EFFICIENCY: Query performance metrics (QUERY_HISTORY)
 *   6. V_STREAMING_COSTS: Cost tracking with actual credits (FILE_MIGRATION_HISTORY)
 *   7. V_TASK_EXECUTION_HISTORY: Task performance (TASK_HISTORY)
 * 
 * WARNING:  NOTE: ACCOUNT_USAGE views have latency (up to 120 minutes).
 *     V_CHANNEL_STATUS and V_STREAMING_COSTS use FILE_MIGRATION_HISTORY.
 *     For real-time event monitoring, query RAW_BADGE_EVENTS directly.
 * 
 * CLEANUP:
 *   See sql/99_cleanup/teardown_all.sql for complete removal
 ******************************************************************************/

-- ============================================================================
-- PREREQUISITE: Core setup must be complete
-- ============================================================================
-- Run sql/01_setup/01_core_setup.sql first

USE ROLE SYSADMIN;
USE DATABASE SNOWFLAKE_EXAMPLE;
USE SCHEMA RAW_INGESTION;

-- ============================================================================
-- View 1: Channel Status
-- ============================================================================

CREATE OR REPLACE VIEW V_CHANNEL_STATUS
COMMENT = 'DEMO: sfe-simple-stream - Snowpipe Streaming channel health (uses FILE_MIGRATION_HISTORY)'
AS
SELECT 
    table_name AS pipe_name,
    MAX(end_time) AS last_ingestion_time,
    DATEDIFF('second', MAX(end_time), CURRENT_TIMESTAMP()) AS seconds_since_last_ingestion,
    SUM(num_rows_migrated) AS total_rows_inserted,
    SUM(num_bytes_migrated) / POWER(1024, 3) AS total_gb_inserted,
    COUNT(DISTINCT DATE_TRUNC('minute', end_time)) AS active_minutes_last_hour,
    AVG(num_rows_migrated) AS avg_rows_per_insert,
    MAX(num_rows_migrated) AS max_rows_per_insert,
    SUM(credits_used) AS total_credits_used
FROM SNOWFLAKE.ACCOUNT_USAGE.SNOWPIPE_STREAMING_FILE_MIGRATION_HISTORY
WHERE table_name = 'RAW_BADGE_EVENTS'
    AND end_time >= DATEADD('hour', -1, CURRENT_TIMESTAMP())
GROUP BY table_name;

-- ============================================================================
-- View 2: Ingestion Metrics
-- ============================================================================

CREATE OR REPLACE VIEW V_INGESTION_METRICS
COMMENT = 'DEMO: sfe-simple-stream - Hourly ingestion metrics for the last 24 hours'
AS
WITH hourly_stats AS (
    SELECT 
        DATE_TRUNC('hour', ingestion_time) AS ingestion_hour,
        COUNT(*) AS event_count,
        COUNT(DISTINCT badge_id) AS unique_badges,
        COUNT(DISTINCT zone_id) AS unique_zones,
        AVG(signal_strength) AS avg_signal_strength,
        SUM(CASE WHEN signal_quality = 'WEAK' THEN 1 ELSE 0 END) AS weak_signal_count,
        SUM(CASE WHEN direction = 'ENTRY' THEN 1 ELSE 0 END) AS entry_count,
        SUM(CASE WHEN direction = 'EXIT' THEN 1 ELSE 0 END) AS exit_count
    FROM RAW_BADGE_EVENTS
    WHERE ingestion_time >= DATEADD('day', -1, CURRENT_TIMESTAMP())
    GROUP BY DATE_TRUNC('hour', ingestion_time)
)
SELECT 
    ingestion_hour,
    event_count,
    event_count / 3600.0 AS events_per_second,
    unique_badges,
    unique_zones,
    ROUND(avg_signal_strength, 2) AS avg_signal_strength,
    weak_signal_count,
    ROUND(100.0 * weak_signal_count / NULLIF(event_count, 0), 2) AS weak_signal_pct,
    entry_count,
    exit_count,
    entry_count - exit_count AS net_occupancy_change
FROM hourly_stats
ORDER BY ingestion_hour DESC;

-- ============================================================================
-- View 3: End-to-End Latency
-- ============================================================================

CREATE OR REPLACE VIEW V_END_TO_END_LATENCY
COMMENT = 'DEMO: sfe-simple-stream - End-to-end pipeline latency and health status'
AS
WITH latest_events AS (
    SELECT 
        'RAW' AS layer,
        MAX(ingestion_time) AS last_update,
        COUNT(*) AS row_count
    FROM RAW_BADGE_EVENTS
    WHERE ingestion_time >= DATEADD('hour', -1, CURRENT_TIMESTAMP())
    
    UNION ALL
    
    SELECT 
        'STAGING' AS layer,
        MAX(staging_time) AS last_update,
        COUNT(*) AS row_count
    FROM SNOWFLAKE_EXAMPLE.STAGING_LAYER.STG_BADGE_EVENTS
    WHERE staging_time >= DATEADD('hour', -1, CURRENT_TIMESTAMP())
    
    UNION ALL
    
    SELECT 
        'ANALYTICS' AS layer,
        MAX(fact_load_time) AS last_update,
        COUNT(*) AS row_count
    FROM SNOWFLAKE_EXAMPLE.ANALYTICS_LAYER.FCT_ACCESS_EVENTS
    WHERE fact_load_time >= DATEADD('hour', -1, CURRENT_TIMESTAMP())
)
SELECT 
    layer,
    last_update,
    DATEDIFF('second', last_update, CURRENT_TIMESTAMP()) AS seconds_since_update,
    row_count,
    CASE 
        WHEN DATEDIFF('second', last_update, CURRENT_TIMESTAMP()) > 300 THEN 'STALE'
        WHEN DATEDIFF('second', last_update, CURRENT_TIMESTAMP()) > 120 THEN 'WARNING'
        ELSE 'HEALTHY'
    END AS health_status
FROM latest_events
ORDER BY 
    CASE layer
        WHEN 'RAW' THEN 1
        WHEN 'STAGING' THEN 2
        WHEN 'ANALYTICS' THEN 3
    END;

-- ============================================================================
-- View 4: Data Freshness
-- ============================================================================

CREATE OR REPLACE VIEW V_DATA_FRESHNESS
COMMENT = 'DEMO: sfe-simple-stream - Data freshness metrics across all layers'
AS
SELECT 
    'RAW_BADGE_EVENTS' AS table_name,
    MAX(event_timestamp) AS last_event_timestamp,
    MAX(ingestion_time) AS last_ingestion_timestamp,
    DATEDIFF('second', MAX(event_timestamp), CURRENT_TIMESTAMP()) AS event_age_seconds,
    DATEDIFF('second', MAX(ingestion_time), CURRENT_TIMESTAMP()) AS ingestion_age_seconds,
    COUNT(*) AS total_rows,
    SUM(CASE WHEN ingestion_time >= DATEADD('hour', -1, CURRENT_TIMESTAMP()) THEN 1 ELSE 0 END) AS rows_last_hour
FROM RAW_BADGE_EVENTS

UNION ALL

SELECT 
    'FCT_ACCESS_EVENTS' AS table_name,
    MAX(event_timestamp) AS last_event_timestamp,
    MAX(fact_load_time) AS last_ingestion_timestamp,
    DATEDIFF('second', MAX(event_timestamp), CURRENT_TIMESTAMP()) AS event_age_seconds,
    DATEDIFF('second', MAX(fact_load_time), CURRENT_TIMESTAMP()) AS ingestion_age_seconds,
    COUNT(*) AS total_rows,
    SUM(CASE WHEN fact_load_time >= DATEADD('hour', -1, CURRENT_TIMESTAMP()) THEN 1 ELSE 0 END) AS rows_last_hour
FROM SNOWFLAKE_EXAMPLE.ANALYTICS_LAYER.FCT_ACCESS_EVENTS;

-- ============================================================================
-- View 5: Partition Efficiency
-- ============================================================================

CREATE OR REPLACE VIEW V_PARTITION_EFFICIENCY
COMMENT = 'DEMO: sfe-simple-stream - Query pruning efficiency - uses TABLE_QUERY_PRUNING_HISTORY'
AS
SELECT 
    table_name,
    SUM(num_queries) AS query_count,
    ROUND(100.0 * SUM(partitions_scanned) / NULLIF(SUM(partitions_scanned + partitions_pruned), 0), 2) AS avg_scan_ratio_pct,
    ROUND(SUM(rows_scanned) / POWER(1024, 3), 2) AS total_gb_scanned_approx,
    ROUND(100.0 * SUM(rows_pruned) / NULLIF(SUM(rows_scanned + rows_pruned), 0), 2) AS row_prune_ratio_pct,
    CASE 
        WHEN 100.0 * SUM(partitions_scanned) / NULLIF(SUM(partitions_scanned + partitions_pruned), 0) < 20 THEN 'EXCELLENT'
        WHEN 100.0 * SUM(partitions_scanned) / NULLIF(SUM(partitions_scanned + partitions_pruned), 0) < 50 THEN 'GOOD'
        WHEN 100.0 * SUM(partitions_scanned) / NULLIF(SUM(partitions_scanned + partitions_pruned), 0) < 80 THEN 'FAIR'
        ELSE 'POOR'
    END AS pruning_efficiency
FROM SNOWFLAKE.ACCOUNT_USAGE.TABLE_QUERY_PRUNING_HISTORY
WHERE table_name IN ('RAW_BADGE_EVENTS', 'FCT_ACCESS_EVENTS')
    AND interval_start_time >= DATEADD('day', -1, CURRENT_TIMESTAMP())
GROUP BY table_name;

-- ============================================================================
-- View 6: Streaming Costs (Throughput-Based Pricing)
-- ============================================================================

CREATE OR REPLACE VIEW V_STREAMING_COSTS
COMMENT = 'DEMO: sfe-simple-stream - Snowpipe Streaming cost tracking from FILE_MIGRATION_HISTORY'
AS
WITH daily_throughput AS (
    SELECT 
        DATE(end_time) AS ingestion_date,
        SUM(num_bytes_migrated) / POWER(1024, 3) AS gb_ingested,
        SUM(num_rows_migrated) AS rows_ingested,
        SUM(credits_used) AS actual_credits_used
    FROM SNOWFLAKE.ACCOUNT_USAGE.SNOWPIPE_STREAMING_FILE_MIGRATION_HISTORY
    WHERE table_name = 'RAW_BADGE_EVENTS'
        AND end_time >= DATEADD('day', -30, CURRENT_TIMESTAMP())
    GROUP BY DATE(end_time)
)
SELECT 
    ingestion_date,
    gb_ingested,
    rows_ingested,
    actual_credits_used,
    ROUND(rows_ingested / NULLIF(gb_ingested, 0), 0) AS rows_per_gb
FROM daily_throughput
ORDER BY ingestion_date DESC;

-- ============================================================================
-- View 7: Task Execution History
-- ============================================================================

CREATE OR REPLACE VIEW V_TASK_EXECUTION_HISTORY
COMMENT = 'DEMO: sfe-simple-stream - Task execution history for the last 24 hours'
AS
SELECT 
    name AS task_name,
    state,
    scheduled_time,
    completed_time,
    DATEDIFF('second', scheduled_time, completed_time) AS duration_seconds,
    error_code,
    error_message,
    CASE 
        WHEN state = 'SUCCEEDED' THEN 'SUCCESS'
        WHEN state = 'FAILED' THEN 'FAILED'
        WHEN state = 'SKIPPED' THEN 'SKIPPED'
        ELSE 'UNKNOWN'
    END AS execution_status
FROM TABLE(
    INFORMATION_SCHEMA.TASK_HISTORY(
        SCHEDULED_TIME_RANGE_START => DATEADD('day', -1, CURRENT_TIMESTAMP()),
        RESULT_LIMIT => 1000
    )
)
WHERE database_name = 'SNOWFLAKE_EXAMPLE'
ORDER BY scheduled_time DESC;

-- ============================================================================
-- Verify view creation
-- ============================================================================

SHOW VIEWS LIKE 'V_%' IN SCHEMA RAW_INGESTION;

-- ============================================================================
-- USAGE EXAMPLES
-- ============================================================================
-- 
-- Check overall system health:
--   SELECT * FROM V_END_TO_END_LATENCY;
-- 
-- Monitor real-time ingestion:
--   SELECT * FROM V_CHANNEL_STATUS;
-- 
-- Review hourly ingestion patterns:
--   SELECT * FROM V_INGESTION_METRICS LIMIT 24;
-- 
-- Check data freshness:
--   SELECT * FROM V_DATA_FRESHNESS;
-- 
-- Verify query performance:
--   SELECT * FROM V_PARTITION_EFFICIENCY;
-- 
-- Track costs:
--   SELECT SUM(actual_credits_used) AS total_credits_last_30_days
--   FROM V_STREAMING_COSTS;
-- 
-- Review task performance:
--   SELECT task_name, COUNT(*) AS executions, AVG(duration_seconds) AS avg_duration
--   FROM V_TASK_EXECUTION_HISTORY
--   WHERE execution_status = 'SUCCESS'
--   GROUP BY task_name;
-- ============================================================================

