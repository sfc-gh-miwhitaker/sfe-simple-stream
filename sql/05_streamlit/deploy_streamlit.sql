/*******************************************************************************
 * DEMO PROJECT: sfe-simple-stream
 * Script: Deploy Streamlit Dashboard (Native Snowflake)
 * 
 * ⚠️  NOT FOR PRODUCTION USE - EXAMPLE IMPLEMENTATION ONLY
 * 
 * PURPOSE:
 *   Deploy real-time monitoring dashboard as native Snowflake Streamlit app
 * 
 * OBJECTS CREATED:
 *   - Stage: SFE_STREAMLIT_STAGE (for app files)
 *   - Streamlit App: SFE_SIMPLE_STREAM_MONITOR
 * 
 * DEPLOYMENT METHOD:
 *   Uses Git integration to pull streamlit_app.py directly from repository
 *   No manual file uploads required
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
-- Step 1: Create Stage for Streamlit App Files
-- ============================================================================

CREATE STAGE IF NOT EXISTS SFE_STREAMLIT_STAGE
  COMMENT = 'DEMO: sfe-simple-stream - Stage for Streamlit app files | Expires: 2025-12-24';

-- ============================================================================
-- Step 2: Copy Streamlit App from Git Repository to Stage
-- ============================================================================

-- Copy streamlit_app.py from Git repo to stage
COPY FILES
  INTO @SFE_STREAMLIT_STAGE
  FROM @SNOWFLAKE_EXAMPLE.DEMO_REPO.sfe_simple_stream_repo/branches/main/streamlit/
  FILES = ('streamlit_app.py');

-- Copy requirements.txt for dependencies
COPY FILES
  INTO @SFE_STREAMLIT_STAGE
  FROM @SNOWFLAKE_EXAMPLE.DEMO_REPO.sfe_simple_stream_repo/branches/main/streamlit/
  FILES = ('requirements.txt');

-- Verify files are in stage
LIST @SFE_STREAMLIT_STAGE;

-- ============================================================================
-- Step 3: Create Streamlit App
-- ============================================================================

CREATE OR REPLACE STREAMLIT SFE_SIMPLE_STREAM_MONITOR
  ROOT_LOCATION = '@SNOWFLAKE_EXAMPLE.RAW_INGESTION.SFE_STREAMLIT_STAGE'
  MAIN_FILE = 'streamlit_app.py'
  QUERY_WAREHOUSE = 'COMPUTE_WH'
  COMMENT = 'DEMO: sfe-simple-stream - Real-time monitoring dashboard | Expires: 2025-12-24';

-- ============================================================================
-- Step 4: Grant Access Permissions
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

SELECT '
╔════════════════════════════════════════════════════════════════╗
║  ✅ STREAMLIT DASHBOARD DEPLOYED                               ║
╠════════════════════════════════════════════════════════════════╣
║                                                                ║
║  Dashboard Name: SFE_SIMPLE_STREAM_MONITOR                     ║
║  Location: SNOWFLAKE_EXAMPLE.RAW_INGESTION                     ║
║                                                                ║
║  📊 TO ACCESS:                                                 ║
║  1. Open Snowsight                                            ║
║  2. Navigate to: Projects > Streamlit                         ║
║  3. Click: SFE_SIMPLE_STREAM_MONITOR                          ║
║                                                                ║
║  🔄 TO UPDATE:                                                 ║
║  1. Update streamlit_app.py in Git repository                 ║
║  2. Re-run this script to deploy latest version              ║
║                                                                ║
║  📈 FEATURES:                                                  ║
║  - Real-time pipeline health monitoring                       ║
║  - Ingestion metrics and throughput charts                    ║
║  - End-to-end latency tracking                                ║
║  - Cost analysis and optimization insights                    ║
║  - Task execution monitoring                                  ║
║  - Query performance analytics                                ║
║                                                                ║
║  Auto-refresh: 60 seconds                                     ║
║  Data source: Monitoring views in RAW_INGESTION schema        ║
║                                                                ║
╚════════════════════════════════════════════════════════════════╝
' AS DEPLOYMENT_COMPLETE;

-- ============================================================================
-- TROUBLESHOOTING
-- ============================================================================
-- 
-- Issue: "Streamlit app not found"
-- Solution: Verify stage contains files:
--   LIST @SFE_STREAMLIT_STAGE;
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

