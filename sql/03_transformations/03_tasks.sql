/*******************************************************************************
 * Automated Tasks
 * Creates: CDC tasks (raw to staging, staging to analytics)
 * Time: 5 seconds
 ******************************************************************************/

USE ROLE SYSADMIN;
USE DATABASE SNOWFLAKE_EXAMPLE;
USE SCHEMA RAW_INGESTION;

-- Suspend if re-running
ALTER TASK IF EXISTS sfe_raw_to_staging_task SUSPEND;
CALL SYSTEM$WAIT(2);

-- Task 1: Deduplicate RAW to STAGING (runs every 1 minute)
CREATE OR REPLACE TASK sfe_raw_to_staging_task
    WAREHOUSE = COMPUTE_WH
    SCHEDULE = '1 MINUTE'
    COMMENT = 'DEMO: Deduplication task'
WHEN SYSTEM$STREAM_HAS_DATA('sfe_badge_events_stream')
AS
    INSERT INTO SNOWFLAKE_EXAMPLE.STAGING_LAYER.STG_BADGE_EVENTS (
        badge_id,
        user_id,
        zone_id,
        reader_id,
        event_timestamp,
        signal_strength,
        signal_quality,
        direction,
        ingestion_time
    )
    SELECT
        badge_id,
        user_id,
        zone_id,
        reader_id,
        event_timestamp,
        signal_strength,
        signal_quality,
        direction,
        ingestion_time
    FROM sfe_badge_events_stream
    WHERE METADATA$ACTION = 'INSERT'
    QUALIFY ROW_NUMBER() OVER (PARTITION BY badge_id, event_timestamp ORDER BY ingestion_time DESC) = 1;

-- Stored procedure: Enrich STAGING to ANALYTICS
USE SCHEMA STAGING_LAYER;

CREATE OR REPLACE PROCEDURE sfe_process_badge_events()
RETURNS VARCHAR
LANGUAGE SQL
COMMENT = 'DEMO: Enrichment logic'
EXECUTE AS OWNER
AS
$$
BEGIN
    -- Auto-create unknown users
    MERGE INTO SNOWFLAKE_EXAMPLE.ANALYTICS_LAYER.DIM_USERS d
    USING (
        SELECT DISTINCT user_id
        FROM SNOWFLAKE_EXAMPLE.STAGING_LAYER.STG_BADGE_EVENTS
    ) s
    ON d.user_id = s.user_id AND d.is_current = TRUE
    WHEN NOT MATCHED THEN
        INSERT (
            user_id,
            user_name,
            user_type,
            department,
            clearance_level,
            is_active,
            is_current,
            effective_start_date
        )
        VALUES (
            s.user_id,
            'UNKNOWN',
            'UNKNOWN',
            'UNKNOWN',
            'PUBLIC',
            TRUE,
            TRUE,
            CURRENT_TIMESTAMP()
        );

    -- Load fact table with enriched data
    INSERT INTO SNOWFLAKE_EXAMPLE.ANALYTICS_LAYER.FCT_ACCESS_EVENTS (
        user_key,
        zone_key,
        badge_id,
        reader_id,
        event_timestamp,
        event_date,
        event_hour,
        event_day_of_week,
        direction,
        signal_strength,
        signal_quality,
        is_restricted_access,
        is_after_hours,
        is_weekend,
        ingestion_time
    )
    SELECT
        u.user_key,
        z.zone_key,
        s.badge_id,
        s.reader_id,
        s.event_timestamp,
        DATE(s.event_timestamp),
        HOUR(s.event_timestamp),
        DAYOFWEEK(s.event_timestamp),
        s.direction,
        s.signal_strength,
        s.signal_quality,
        z.is_restricted,
        IFF(HOUR(s.event_timestamp) < 6 OR HOUR(s.event_timestamp) >= 22, TRUE, FALSE),
        IFF(DAYOFWEEK(s.event_timestamp) IN (0, 6), TRUE, FALSE),
        s.ingestion_time
    FROM SNOWFLAKE_EXAMPLE.STAGING_LAYER.STG_BADGE_EVENTS s
    JOIN SNOWFLAKE_EXAMPLE.ANALYTICS_LAYER.DIM_USERS u
        ON s.user_id = u.user_id AND u.is_current = TRUE
    JOIN SNOWFLAKE_EXAMPLE.ANALYTICS_LAYER.DIM_ZONES z
        ON s.zone_id = z.zone_id
    LEFT JOIN SNOWFLAKE_EXAMPLE.ANALYTICS_LAYER.FCT_ACCESS_EVENTS f
        ON s.badge_id = f.badge_id
        AND s.event_timestamp = f.event_timestamp
    WHERE f.event_key IS NULL;

    RETURN 'COMPLETED';
END;
$$;

-- Task 2: Call enrichment procedure (dependent on Task 1)
USE SCHEMA RAW_INGESTION;

CREATE OR REPLACE TASK sfe_staging_to_analytics_task
    WAREHOUSE = COMPUTE_WH
    COMMENT = 'DEMO: Enrichment task'
    AFTER sfe_raw_to_staging_task
AS
    CALL SNOWFLAKE_EXAMPLE.STAGING_LAYER.sfe_process_badge_events();

-- Resume tasks (child first, then parent)
ALTER TASK IF EXISTS sfe_staging_to_analytics_task SUSPEND;
ALTER TASK IF EXISTS sfe_raw_to_staging_task SUSPEND;
CALL SYSTEM$WAIT(2);

ALTER TASK sfe_staging_to_analytics_task RESUME;
ALTER TASK sfe_raw_to_staging_task RESUME;
