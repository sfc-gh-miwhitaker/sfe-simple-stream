/*******************************************************************************
 * DEMO PROJECT: sfe-simple-stream | Script: Complete Teardown
 * WARNING: DESTRUCTIVE OPERATION - ALL DATA WILL BE PERMANENTLY DELETED
 * PURPOSE: Remove all demo objects while preserving SNOWFLAKE_EXAMPLE database.
 * CLEANUP RULE: Drop schemas, tables, streams, tasks, pipes, secrets, repo, warehouse.
 * PRESERVED: API Integration (SFE_GIT_API_INTEGRATION) - shared across demo projects
 ******************************************************************************/

-- ============================================================================
-- STEP 1: Suspend and Drop Tasks
-- ============================================================================
-- For SUSPENDING: Root/parent task must be suspended FIRST (stops the DAG)
-- For DROPPING: Child tasks must be dropped first (reverse dependency order)

USE ROLE SYSADMIN;
use database SNOWFLAKE_EXAMPLE;

-- Check if RAW_INGESTION schema exists before trying to suspend tasks
DECLARE
  schema_exists BOOLEAN;
BEGIN
  SELECT COUNT(*) > 0 INTO :schema_exists
  FROM INFORMATION_SCHEMA.SCHEMATA
  WHERE SCHEMA_NAME = 'RAW_INGESTION' AND CATALOG_NAME = 'SNOWFLAKE_EXAMPLE';

  IF (schema_exists) THEN
    USE DATABASE SNOWFLAKE_EXAMPLE;

    -- Suspend ROOT/PARENT task FIRST (stops the entire DAG)
    ALTER TASK IF EXISTS RAW_INGESTION.sfe_raw_to_staging_task SUSPEND;
    CALL SYSTEM$WAIT(2);

    -- Suspend child tasks
    ALTER TASK IF EXISTS RAW_INGESTION.sfe_staging_to_analytics_task SUSPEND;
    ALTER TASK IF EXISTS RAW_INGESTION.sfe_alert_on_data_quality_violations SUSPEND;
    CALL SYSTEM$WAIT(3);
  END IF;
END;

-- ============================================================================
-- STEP 2: Drop Schemas with CASCADE (removes all contained objects)
-- ============================================================================
-- CASCADE will automatically drop all objects within the schema
-- This eliminates the need to drop individual tables, views, streams, pipes, etc.

USE ROLE SYSADMIN;
USE DATABASE SNOWFLAKE_EXAMPLE;

-- Unset database-level event table configuration first
ALTER DATABASE IF EXISTS SNOWFLAKE_EXAMPLE UNSET EVENT_TABLE;

-- Drop schemas with CASCADE (removes everything inside automatically)
-- This includes: tables, views, streams, tasks, pipes, stages, Streamlit apps
DROP SCHEMA IF EXISTS ANALYTICS_LAYER CASCADE;
DROP SCHEMA IF EXISTS STAGING_LAYER CASCADE;
DROP SCHEMA IF EXISTS RAW_INGESTION CASCADE;
-- Note: RAW_INGESTION CASCADE drops SFE_SIMPLE_STREAM_MONITOR Streamlit app and SFE_STREAMLIT_STAGE

-- ============================================================================
-- STEP 3: Drop DEMO_REPO Schema with CASCADE
-- ============================================================================
-- The schema is owned by SYSADMIN, but secrets require ACCOUNTADMIN to drop
-- We switch to ACCOUNTADMIN to ensure we can drop secrets, then drop the schema

USE ROLE ACCOUNTADMIN;

-- Drop DEMO_REPO schema with CASCADE (removes all secrets, Git repo, procedures)
DROP SCHEMA IF EXISTS SNOWFLAKE_EXAMPLE.DEMO_REPO CASCADE;

-- ============================================================================
-- STEP 4: Shared Warehouse (No Drop Required)
-- ============================================================================
-- Using pre-existing COMPUTE_WH for this demo, so there is no dedicated
-- warehouse to remove during teardown. API Integration is preserved as well.

-- ============================================================================
-- VERIFICATION (Optional - run to confirm cleanup)
-- ============================================================================

USE ROLE ACCOUNTADMIN;

-- Verify API Integration still exists (should be preserved)
SHOW API INTEGRATIONS LIKE 'SFE_GIT%';

-- Verify SNOWFLAKE_EXAMPLE database still exists but demo schemas are gone
SHOW SCHEMAS IN DATABASE SNOWFLAKE_EXAMPLE;
-- Expected: Only INFORMATION_SCHEMA and PUBLIC should remain

-- ============================================================================
-- CLEANUP COMPLETE
-- ============================================================================
-- All demo objects removed
-- SNOWFLAKE_EXAMPLE database preserved (as per cleanup rule)
-- Ready for fresh deployment
--
-- This script is fully idempotent and safe to run multiple times without errors.
