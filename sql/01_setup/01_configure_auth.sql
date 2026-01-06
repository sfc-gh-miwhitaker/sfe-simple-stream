/*******************************************************************************
 * Configure Authentication for Data Provider
 *
 * PURPOSE: Set up a service account with key pair auth for external data ingestion
 *
 * RUN THIS ONCE: Before sharing API configuration with data provider
 *
 * TIME: 5 minutes
 ******************************************************************************/

-- ============================================================================
-- STEP 1: Create service account for data ingestion
-- ============================================================================

USE ROLE ACCOUNTADMIN;

CREATE USER IF NOT EXISTS sfe_ingest_user
  COMMENT = 'Service account for external badge event ingestion'
  DEFAULT_ROLE = 'PUBLIC'
  MUST_CHANGE_PASSWORD = FALSE;

CREATE ROLE IF NOT EXISTS sfe_ingest_role
  COMMENT = 'Role for Snowpipe Streaming ingestion';

GRANT ROLE sfe_ingest_role TO USER sfe_ingest_user;

-- ============================================================================
-- STEP 2: Grant privileges to ingest data
-- ============================================================================

USE ROLE SYSADMIN;

GRANT USAGE ON DATABASE SNOWFLAKE_EXAMPLE TO ROLE sfe_ingest_role;
GRANT USAGE ON SCHEMA SNOWFLAKE_EXAMPLE.RAW_INGESTION TO ROLE sfe_ingest_role;
GRANT INSERT ON TABLE SNOWFLAKE_EXAMPLE.RAW_INGESTION.RAW_BADGE_EVENTS TO ROLE sfe_ingest_role;
GRANT OPERATE ON PIPE SNOWFLAKE_EXAMPLE.RAW_INGESTION.SFE_BADGE_EVENTS_PIPE TO ROLE sfe_ingest_role;

-- ============================================================================
-- STEP 3: Generate RSA key pair (requires OpenSSL)
-- ============================================================================

-- Mac/Linux (OpenSSL pre-installed):
--   openssl genrsa 2048 | openssl pkcs8 -topk8 -inform PEM -out rsa_key.p8 -nocrypt
--   openssl rsa -in rsa_key.p8 -pubout -outform DER | openssl base64 -A
--
-- Windows (install OpenSSL first):
--   winget install OpenSSL.Light
--   (then run the Mac/Linux commands above)
--
-- Output:
--   rsa_key.p8              (private key - give to data provider securely)
--   Terminal output string  (public key - copy for Step 4 below)

-- ============================================================================
-- STEP 4: Register public key with Snowflake
-- ============================================================================

-- CRITICAL: The public key MUST be:
--   1. A single line of base64 text (NO line breaks)
--   2. WITHOUT the -----BEGIN/END PUBLIC KEY----- headers
--   3. Copy the output from Step 3 exactly as shown
--
-- Paste the base64 string between the quotes below:

USE ROLE ACCOUNTADMIN;

ALTER USER sfe_ingest_user SET RSA_PUBLIC_KEY='PASTE_BASE64_STRING_HERE';

-- Example (yours will be different):
-- ALTER USER sfe_ingest_user SET RSA_PUBLIC_KEY='MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAy8Zo5dIjnhUp/hgRNXSMTwjU...';

-- ============================================================================
-- STEP 5: Verify setup
-- ============================================================================

SHOW USERS LIKE 'sfe_ingest_user';
SHOW GRANTS TO ROLE sfe_ingest_role;

-- ============================================================================
-- DONE - Authentication configured
-- ============================================================================
--
-- Next: Run @sql/01_setup/02_api_handoff.sql to generate complete documentation
--       for your data provider (API config + credentials)
--
-- ============================================================================
