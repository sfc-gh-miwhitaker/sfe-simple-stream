/*******************************************************************************
 * Simple Streaming Pipeline - Complete Deployment
 * 
 * ⚠️  DEMONSTRATION PROJECT - EXPIRES: 2025-12-24
 * 
 * Author: SE Community
 * Created: 2025-11-24
 * Expires: 2025-12-24 (30 days)
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
-- This demo expires 30 days after creation to prevent users from encountering
-- outdated syntax or deprecated features.

SELECT
  CASE
    WHEN CURRENT_DATE() > '2025-12-24'::DATE THEN
'
╔════════════════════════════════════════════════════════════════╗
║  ⚠️  DEMO EXPIRED                                              ║
╠════════════════════════════════════════════════════════════════╣
║                                                                ║
║  This demonstration project expired on 2025-12-24.             ║
║                                                                ║
║  Why? To ensure you don''t encounter outdated Snowflake        ║
║  features or deprecated syntax.                                ║
║                                                                ║
║  What now?                                                     ║
║  - Code is viewable (read-only) for reference                 ║
║  - Contact Snowflake SE team for updated version              ║
║  - Review and customize for your production needs             ║
║                                                                ║
║  Created: 2025-11-24 | Expired: 2025-12-24                    ║
║  Author: SE Community                                         ║
║                                                                ║
╚════════════════════════════════════════════════════════════════╝

⛔ DEPLOYMENT BLOCKED - Demo has expired.
'
    WHEN CURRENT_DATE() = '2025-12-24'::DATE THEN
      '⚠️  WARNING: This demo expires TODAY (2025-12-24). Consider updating to latest version.'
    WHEN DATEDIFF('day', CURRENT_DATE(), '2025-12-24'::DATE) <= 7 THEN
      '⚠️  WARNING: This demo expires in ' || DATEDIFF('day', CURRENT_DATE(), '2025-12-24'::DATE) || ' days (2025-12-24)'
    ELSE
      '✓ Demo is active. Expires in ' || DATEDIFF('day', CURRENT_DATE(), '2025-12-24'::DATE) || ' days (2025-12-24)'
  END AS EXPIRATION_STATUS;

-- Block deployment if expired
SELECT
  CASE
    WHEN CURRENT_DATE() > '2025-12-24'::DATE THEN
      (1 / 0)  -- Force error to stop deployment
    ELSE
      1
  END AS DEPLOYMENT_GATE;

-- ============================================================================
-- STEP 1: Git Integration & Database
-- ============================================================================

USE ROLE SYSADMIN;

CREATE DATABASE IF NOT EXISTS SNOWFLAKE_EXAMPLE
  COMMENT = 'DEMO: Example projects | Author: SE Community | Expires: 2025-12-24';

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
  ORIGIN = 'https://github.com/sfc-gh-miwhitaker/sfe-simple-stream';

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
) COMMENT = 'DEMO: Deployment metadata for automation | Expires: 2025-12-24';

-- Store account info (silently)
INSERT OVERWRITE INTO DEPLOYMENT_METADATA (account_identifier, demo_expires_date)
VALUES (CURRENT_ACCOUNT(), '2025-12-24');

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
  IFF(found = expected, '✅ PASS', '❌ FAIL') AS status
FROM object_counts
ORDER BY component;

-- Additional validation for Streams and Tasks (separate queries required)
SHOW STREAMS IN SCHEMA SNOWFLAKE_EXAMPLE.RAW_INGESTION;
SELECT 
  'Streams' AS component,
  COUNT(*) || ' / 1' AS count,
  IFF(COUNT(*) = 1, '✅ PASS', '❌ FAIL') AS status
FROM TABLE(RESULT_SCAN(LAST_QUERY_ID()));

SHOW TASKS IN SCHEMA SNOWFLAKE_EXAMPLE.RAW_INGESTION;
SELECT 
  'Tasks' AS component,
  COUNT(*) || ' / 2' AS count,
  IFF(COUNT(*) = 2, '✅ PASS', '❌ FAIL') AS status
FROM TABLE(RESULT_SCAN(LAST_QUERY_ID()));

-- ============================================================================
-- NEXT STEP: Account Info (Result Pane - FINAL)
-- ============================================================================

SELECT 
  '✅ DEPLOYMENT COMPLETE' AS status,
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

