/*******************************************************************************
 * Simple Streaming Pipeline - Complete Deployment
 *
 * DEMONSTRATION PROJECT (timeboxed)
 * CREATED: 2025-12-02
 * EXPIRES: 2026-02-05
 *
 * Author: SE Community
 *
 * PURPOSE: Deploy complete Snowpipe Streaming pipeline from Git in one command
 * DEPLOYS: Git integration + infrastructure + analytics + tasks + monitoring
 * TIME: 45 seconds
 *
 * USAGE IN SNOWSIGHT:
 *   1. Copy this ENTIRE script
 *   2. Open Snowsight -> New Worksheet
 *   3. Paste the script
 *   4. Click "Run All"
 *   5. Wait ~45 seconds for complete deployment
 *   6. Check last result pane for your account identifier
 ******************************************************************************/

-- ============================================================================
-- EXPIRATION CHECK (MANDATORY FOR PUBLIC DEMOS)
-- ============================================================================
-- Single source of truth: this file header line "EXPIRES: YYYY-MM-DD"

SELECT
  CASE
    WHEN CURRENT_DATE() > TO_DATE('2026-02-05') THEN
      'DEMO EXPIRED: This demo expired on 2026-02-05. Deployment is blocked.'
    WHEN CURRENT_DATE() = TO_DATE('2026-02-05') THEN
      'WARNING: This demo expires today (2026-02-05).'
    WHEN DATEDIFF('day', CURRENT_DATE(), TO_DATE('2026-02-05')) <= 7 THEN
      'WARNING: This demo expires in ' || DATEDIFF('day', CURRENT_DATE(), TO_DATE('2026-02-05')) || ' days (2026-02-05).'
    ELSE
      'OK: Demo is active. Expires in ' || DATEDIFF('day', CURRENT_DATE(), TO_DATE('2026-02-05')) || ' days (2026-02-05).'
  END AS expiration_status;

-- Block deployment if expired (Snowflake Scripting; safe in Snowsight "Run All")
EXECUTE IMMEDIATE $$
DECLARE
  demo_expired EXCEPTION (-20001, 'DEMO EXPIRED: This demo expired on 2026-02-05. Deployment is blocked.');
  expires_on DATE;
BEGIN
  expires_on := TO_DATE('2026-02-05');
  IF (CURRENT_DATE() > expires_on) THEN
    RAISE demo_expired;
  END IF;
END;
$$;

-- ============================================================================
-- STEP 1: Git Integration & Database
-- ============================================================================

USE ROLE SYSADMIN;

CREATE DATABASE IF NOT EXISTS SNOWFLAKE_EXAMPLE
  COMMENT = 'DEMO: Example projects | Author: SE Community | Expires: 2026-02-05';

CREATE SCHEMA IF NOT EXISTS SNOWFLAKE_EXAMPLE.DEMO_REPO;

USE ROLE ACCOUNTADMIN;

CREATE API INTEGRATION IF NOT EXISTS SFE_GIT_API_INTEGRATION
  API_PROVIDER = git_https_api
  API_ALLOWED_PREFIXES = ('https://github.com/')
  ENABLED = TRUE;

GRANT USAGE ON INTEGRATION SFE_GIT_API_INTEGRATION TO ROLE SYSADMIN;

USE ROLE SYSADMIN;

CREATE OR REPLACE GIT REPOSITORY SNOWFLAKE_EXAMPLE.DEMO_REPO.sfe_simple_stream_repo
  API_INTEGRATION = SFE_GIT_API_INTEGRATION
  ORIGIN = 'https://github.com/sfc-gh-se-community/sfe-simple-stream';

-- ============================================================================
-- STEP 2: Deploy Pipeline from Git
-- ============================================================================

EXECUTE IMMEDIATE FROM @SNOWFLAKE_EXAMPLE.DEMO_REPO.sfe_simple_stream_repo/branches/main/sql/02_core/01_core.sql;
EXECUTE IMMEDIATE FROM @SNOWFLAKE_EXAMPLE.DEMO_REPO.sfe_simple_stream_repo/branches/main/sql/03_transformations/02_analytics.sql;
EXECUTE IMMEDIATE FROM @SNOWFLAKE_EXAMPLE.DEMO_REPO.sfe_simple_stream_repo/branches/main/sql/03_transformations/03_tasks.sql;
EXECUTE IMMEDIATE FROM @SNOWFLAKE_EXAMPLE.DEMO_REPO.sfe_simple_stream_repo/branches/main/sql/04_monitoring/04_monitoring.sql;

-- ============================================================================
-- METADATA: Store Deployment Info (Silent - No Output)
-- ============================================================================

USE SCHEMA RAW_INGESTION;

-- Create metadata table
CREATE TABLE IF NOT EXISTS DEPLOYMENT_METADATA (
  deployment_timestamp TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
  account_identifier VARCHAR(200),
  demo_expires_date DATE
) COMMENT = 'DEMO: Deployment metadata for automation | Expires: 2026-02-05';

-- Store account info (silently)
INSERT OVERWRITE INTO DEPLOYMENT_METADATA (account_identifier, demo_expires_date)
VALUES (CURRENT_ACCOUNT(), '2026-02-05');

-- ============================================================================
-- VALIDATION: Single Comprehensive Query (Result Pane 2)
-- ============================================================================

-- Count all major object types in one query
WITH object_counts AS (
  SELECT 'Schemas' AS component, COUNT(*) AS found, 3 AS expected
  FROM SNOWFLAKE_EXAMPLE.INFORMATION_SCHEMA.SCHEMATA
  WHERE SCHEMA_NAME IN ('RAW_INGESTION', 'STAGING_LAYER', 'ANALYTICS_LAYER')

  UNION ALL

  SELECT 'Tables', COUNT(*), 7
  FROM SNOWFLAKE_EXAMPLE.INFORMATION_SCHEMA.TABLES
  WHERE TABLE_SCHEMA IN ('RAW_INGESTION', 'STAGING_LAYER', 'ANALYTICS_LAYER')
    AND TABLE_TYPE = 'BASE TABLE'

  UNION ALL

  SELECT 'Views', COUNT(*), 7
  FROM SNOWFLAKE_EXAMPLE.INFORMATION_SCHEMA.VIEWS
  WHERE TABLE_SCHEMA = 'RAW_INGESTION'
)
SELECT
  component,
  found || ' / ' || expected AS count,
  IFF(found = expected, 'PASS', 'FAIL') AS status
FROM object_counts
ORDER BY component;

-- Additional validation for Streams and Tasks (separate queries required)
SHOW STREAMS IN SCHEMA SNOWFLAKE_EXAMPLE.RAW_INGESTION;
SELECT
  'Streams' AS component,
  COUNT(*) || ' / 1' AS count,
  IFF(COUNT(*) = 1, 'PASS', 'FAIL') AS status
FROM TABLE(RESULT_SCAN(LAST_QUERY_ID()));

SHOW TASKS IN SCHEMA SNOWFLAKE_EXAMPLE.RAW_INGESTION;
SELECT
  'Tasks' AS component,
  COUNT(*) || ' / 2' AS count,
  IFF(COUNT(*) = 2, 'PASS', 'FAIL') AS status
FROM TABLE(RESULT_SCAN(LAST_QUERY_ID()));

-- ============================================================================
-- NEXT STEP: Account Info (Result Pane - FINAL)
-- ============================================================================

SELECT
  'DEPLOYMENT COMPLETE' AS status,
  CURRENT_ORGANIZATION_NAME() || '-' || CURRENT_ACCOUNT_NAME() AS snowflake_account,
  'Next: Run ./tools/02_setup_and_test.sh in terminal' AS next_step,
  'Provide this account when prompted: ' ||
    CURRENT_ORGANIZATION_NAME() || '-' || CURRENT_ACCOUNT_NAME() AS instruction;

-- ============================================================================
-- Alternative: Use Your Own Ingestion
-- ============================================================================
--
-- Skip Python setup and point your system to:
--   Database: SNOWFLAKE_EXAMPLE
--   Schema:   RAW_INGESTION
--   Table:    RAW_BADGE_EVENTS
--   Format:   JSON (see docs/05-API-HANDOFF.md)
--
-- ============================================================================
