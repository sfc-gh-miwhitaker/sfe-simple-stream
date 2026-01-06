/*******************************************************************************
 * DEMO PROJECT: sfe-simple-stream
 * Script: Deploy Streamlit Dashboard (Native Snowflake)
 *
 * NOT FOR PRODUCTION USE - EXAMPLE IMPLEMENTATION ONLY
 *
 * PURPOSE:
 *   Deploy real-time monitoring dashboard as native Snowflake Streamlit app
 *
 * OBJECTS CREATED:
 *   - Streamlit App: SFE_SIMPLE_STREAM_MONITOR
 *
 * DEPLOYMENT METHOD:
 *   Uses Git integration with FROM clause to deploy directly from repository
 *   No staging or file copying required - enables Git sync and multi-file editing
 *
 * ACCESS:
 *   After deployment, access app via Snowsight:
 *   Projects > Streamlit > SFE_SIMPLE_STREAM_MONITOR
 *
 * PREREQUISITES:
 *   - Monitoring views created (sql/04_monitoring/04_monitoring.sql)
 *   - Git repository configured (done in deploy_all.sql)
 *
 * CLEANUP:
 *   See sql/99_cleanup/cleanup.sql
 ******************************************************************************/

-- ============================================================================
-- PREREQUISITE: Switch to correct context
-- ============================================================================

USE ROLE SYSADMIN;
USE DATABASE SNOWFLAKE_EXAMPLE;
USE SCHEMA RAW_INGESTION;

-- ============================================================================
-- Create Streamlit App (Direct from Git Repository)
-- ============================================================================
-- Uses modern FROM syntax instead of legacy ROOT_LOCATION
-- Benefits:
--   - Git integration supported (changes sync automatically)
--   - Multi-file editing in Snowsight
--   - No staging or COPY FILES required
--   - Future-proofed (ROOT_LOCATION is deprecated)

CREATE OR REPLACE STREAMLIT SFE_SIMPLE_STREAM_MONITOR
  FROM @SNOWFLAKE_EXAMPLE.DEMO_REPO.sfe_simple_stream_repo/branches/main/streamlit/
  MAIN_FILE = 'streamlit_app.py'
  QUERY_WAREHOUSE = 'COMPUTE_WH'
  COMMENT = 'DEMO: sfe-simple-stream - Real-time monitoring dashboard | Expires: 2026-02-05';

-- ============================================================================
-- Grant Access Permissions
-- ============================================================================

-- Grant usage on Streamlit app to SYSADMIN role
GRANT USAGE ON STREAMLIT SFE_SIMPLE_STREAM_MONITOR TO ROLE SYSADMIN;

-- Grant usage to PUBLIC role (optional - for demo access)
-- Uncomment the line below to allow all users to access the dashboard
-- GRANT USAGE ON STREAMLIT SFE_SIMPLE_STREAM_MONITOR TO ROLE PUBLIC;

-- ============================================================================
-- Verification
-- ============================================================================

-- Show Streamlit apps in schema
SHOW STREAMLITS IN SCHEMA RAW_INGESTION;

-- ============================================================================
-- ACCESS INSTRUCTIONS
-- ============================================================================

SELECT
  'STREAMLIT DASHBOARD DEPLOYED' AS status,
  'SFE_SIMPLE_STREAM_MONITOR' AS streamlit_app,
  'SNOWFLAKE_EXAMPLE.RAW_INGESTION' AS location,
  'Snowsight -> Projects -> Streamlit' AS access_path,
  'Auto-refresh: 60 seconds' AS notes;

-- ============================================================================
-- TROUBLESHOOTING
-- ============================================================================
--
-- Issue: "Streamlit app not found"
-- Solution: Verify Git repository is configured:
--   SHOW GIT REPOSITORIES IN SCHEMA DEMO_REPO;
--
-- Issue: "Permission denied"
-- Solution: Grant access to your role:
--   GRANT USAGE ON STREAMLIT SFE_SIMPLE_STREAM_MONITOR TO ROLE YOUR_ROLE;
--
-- Issue: "Views not found"
-- Solution: Create monitoring views first:
--   @sql/04_monitoring/04_monitoring.sql
--
-- Issue: "App shows errors"
-- Solution: Check warehouse is running:
--   SHOW WAREHOUSES LIKE 'COMPUTE_WH';
--
-- ============================================================================
