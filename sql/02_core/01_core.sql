/*******************************************************************************
 * Core Infrastructure
 * 
 * Author: SE Community
 * Created: 2025-12-02
 * Expires: 2026-01-01
 * 
 * Creates: Database, schemas, raw table, pipe, stream
 * Time: 10 seconds
 ******************************************************************************/

USE ROLE SYSADMIN;
USE DATABASE SNOWFLAKE_EXAMPLE;

CREATE SCHEMA IF NOT EXISTS RAW_INGESTION
  COMMENT = 'DEMO: Raw landing layer | Author: SE Community | Expires: 2026-01-01';

CREATE SCHEMA IF NOT EXISTS STAGING_LAYER
  COMMENT = 'DEMO: Deduplication layer | Author: SE Community | Expires: 2026-01-01';

CREATE SCHEMA IF NOT EXISTS ANALYTICS_LAYER
  COMMENT = 'DEMO: Analytics layer | Author: SE Community | Expires: 2026-01-01';

USE SCHEMA RAW_INGESTION;

-- Raw landing table for Snowpipe Streaming
CREATE OR REPLACE TABLE RAW_BADGE_EVENTS (
    badge_id VARCHAR(50) NOT NULL,
    user_id VARCHAR(50) NOT NULL,
    zone_id VARCHAR(50) NOT NULL,
    reader_id VARCHAR(50) NOT NULL,
    event_timestamp TIMESTAMP_NTZ NOT NULL,
    signal_strength NUMBER(5, 2),
    signal_quality VARCHAR(10),
    direction VARCHAR(10),
    ingestion_time TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    raw_json VARIANT
)
COMMENT = 'DEMO: RFID badge events from Snowpipe Streaming REST API | Author: SE Community | Expires: 2026-01-01';

-- Snowpipe with JSON transformation
CREATE OR REPLACE PIPE sfe_badge_events_pipe
  COMMENT = 'DEMO: Snowpipe Streaming endpoint | Author: SE Community | Expires: 2026-01-01'
AS COPY INTO RAW_BADGE_EVENTS
FROM (
  SELECT
    $1:badge_id::STRING AS badge_id,
    $1:user_id::STRING AS user_id,
    $1:zone_id::STRING AS zone_id,
    $1:reader_id::STRING AS reader_id,
    TO_TIMESTAMP_NTZ($1:event_timestamp::STRING) AS event_timestamp,
    COALESCE($1:signal_strength::NUMBER, -999) AS signal_strength,
    UPPER($1:direction::STRING) AS direction,
    CASE
      WHEN $1:signal_strength::NUMBER < -80 THEN 'WEAK'
      WHEN $1:signal_strength::NUMBER < -60 THEN 'MEDIUM'
      ELSE 'STRONG'
    END AS signal_quality,
    CURRENT_TIMESTAMP() AS ingestion_time,
    $1 AS raw_json
  FROM TABLE(DATA_SOURCE(TYPE => 'STREAMING'))
);

-- CDC stream for downstream processing
CREATE OR REPLACE STREAM sfe_badge_events_stream
ON TABLE RAW_BADGE_EVENTS
COMMENT = 'DEMO: Change data capture stream | Author: SE Community | Expires: 2026-01-01';
