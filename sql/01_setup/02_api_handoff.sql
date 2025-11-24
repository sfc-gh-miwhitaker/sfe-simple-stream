/*******************************************************************************
 * DEMO PROJECT: simple-stream
 * Script: API Provider Handoff Document Generator
 * ⚠️  NOT FOR PRODUCTION USE - EXAMPLE IMPLEMENTATION ONLY
 ******************************************************************************/

-- ============================================================================
-- PURPOSE: Generate complete API configuration and credentials for data provider
-- ============================================================================

USE ROLE SYSADMIN;
USE DATABASE SNOWFLAKE_EXAMPLE;

SELECT 
'================================================================================
SNOWPIPE STREAMING API - DATA PROVIDER HANDOFF
================================================================================

BASE CONFIGURATION:
  Control plane URL: https://' || LOWER(REPLACE(CURRENT_ORGANIZATION_NAME() || '-' || CURRENT_ACCOUNT_NAME(), '_', '-')) || '.snowflakecomputing.com
  Target table:      SNOWFLAKE_EXAMPLE.RAW_INGESTION.RAW_BADGE_EVENTS

CREDENTIALS:
  Account:      ' || CURRENT_ORGANIZATION_NAME() || '-' || CURRENT_ACCOUNT_NAME() || '
  Username:     sfe_ingest_user
  Role:         sfe_ingest_role
  Private Key:  rsa_key.p8 (provided separately via secure channel)

AUTH METHOD:
  Key Pair JWT (RSA 2048-bit)

SIMPLE SQL API WORKFLOW:
  1. Generate a JWT using the private key (valid for ~59 minutes)
  2. Call https://<control_host>/api/v2/statements with Authorization: Bearer <jwt_token>
  3. Execute INSERT statements into SNOWFLAKE_EXAMPLE.RAW_INGESTION.RAW_BADGE_EVENTS
  4. Optional: poll the SQL API status endpoint until the statement reports success

--------------------------------------------------------------------------------
QUICKSTART DEMO
--------------------------------------------------------------------------------

Working scripts that demonstrate the SQL API workflow:

  https://github.com/sfc-gh-miwhitaker/sfe-simple-stream

  Unix/Mac:  ./send_events.sh
  Windows:   send_events.bat

Scripts prompt for ACCOUNT_ID updates, generate the JWT, run a three-row INSERT via the SQL API, and print a success message.

--------------------------------------------------------------------------------
DOCUMENTATION
--------------------------------------------------------------------------------

Complete Guide:
  https://github.com/sfc-gh-miwhitaker/sfe-simple-stream

Snowflake Docs:
  https://docs.snowflake.com/en/developer-guide/sql-api/intro
  https://docs.snowflake.com/en/user-guide/key-pair-auth

--------------------------------------------------------------------------------
MONITORING VIEWS
--------------------------------------------------------------------------------

SELECT * FROM SNOWFLAKE_EXAMPLE.RAW_INGESTION.V_INGESTION_METRICS;
SELECT * FROM SNOWFLAKE_EXAMPLE.RAW_INGESTION.V_END_TO_END_LATENCY;
SELECT * FROM SNOWFLAKE_EXAMPLE.RAW_INGESTION.V_STREAMING_COSTS;

(Contact Snowflake admin to grant SELECT privileges if needed)

================================================================================
' AS api_handoff_document;

-- ============================================================================
-- VERIFY CREDENTIALS EXIST
-- ============================================================================

USE ROLE ACCOUNTADMIN;

SELECT 
    'sfe_ingest_user' AS username,
    CASE 
        WHEN rsa_public_key_fp IS NOT NULL THEN '✓ Public key registered'
        ELSE '✗ NO PUBLIC KEY - Run sql/01_setup/01_configure_auth.sql Step 4'
    END AS key_status,
    default_role AS role,
    disabled AS account_disabled
FROM SNOWFLAKE.ACCOUNT_USAGE.USERS
WHERE name = 'SFE_INGEST_USER'
AND deleted_on IS NULL;

-- ============================================================================
-- DONE
-- ============================================================================
-- 
-- Copy the API handoff document above and share with your data provider
-- along with the rsa_key.p8 file via a secure channel.
-- 
-- ============================================================================

