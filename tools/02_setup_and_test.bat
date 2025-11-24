@echo off
REM ##############################################################################
REM Master Orchestration Script - Simple Stream Demo (Windows)
REM 
REM PURPOSE: Fully automated setup and testing (no manual steps)
REM TIME: ~2 minutes
REM 
REM DOES EVERYTHING:
REM   - Generates RSA key pair
REM   - Registers public key with Snowflake
REM   - Pre-populates config.json with your account
REM   - Sets up Python environment
REM   - Sends test events
REM   - Validates pipeline
REM 
REM USAGE: tools\setup_and_test.bat
REM ##############################################################################

setlocal enabledelayedexpansion

REM Get project directories
set "SCRIPT_DIR=%~dp0"
set "PROJECT_ROOT=%SCRIPT_DIR%.."
set "SECRETS_DIR=%PROJECT_ROOT%\.secrets"
set "KEYS_DIR=%SECRETS_DIR%\keys"

echo ================================================================
echo   Simple Stream - Master Setup ^& Test
echo ================================================================
echo.

REM ##############################################################################
REM STEP 1: Get Snowflake Account Identifier
REM ##############################################################################

echo Step 1: Snowflake Account
echo Your account identifier was shown in the deploy_all.sql output.
echo.
echo If you don't have it, run this query in Snowsight:
echo   SELECT CURRENT_ACCOUNT();
echo.
set /p SNOWFLAKE_ACCOUNT="Enter your Snowflake account identifier (e.g., myorg-myaccount): "

if "%SNOWFLAKE_ACCOUNT%"=="" (
    echo ERROR: Account identifier is required
    exit /b 1
)

echo [OK] Account: %SNOWFLAKE_ACCOUNT%
echo.

REM ##############################################################################
REM STEP 2: Generate RSA Key Pair
REM ##############################################################################

echo Step 2: Generate RSA Key Pair

if not exist "%SECRETS_DIR%" mkdir "%SECRETS_DIR%"
if not exist "%KEYS_DIR%" mkdir "%KEYS_DIR%"

if exist "%KEYS_DIR%\rsa_key.p8" (
    echo WARNING: RSA key already exists
    set /p REGENERATE="Regenerate? (y/N): "
    if /i not "!REGENERATE!"=="y" (
        echo [OK] Using existing key
        goto :skip_keygen
    )
    del /q "%KEYS_DIR%\rsa_key.p8" "%KEYS_DIR%\rsa_key.pub" 2>nul
)

echo Generating 2048-bit RSA key pair...

REM Check for OpenSSL
where openssl >nul 2>&1
if errorlevel 1 (
    echo ERROR: OpenSSL not found. Please install OpenSSL:
    echo   https://slproweb.com/products/Win32OpenSSL.html
    echo   Or use: winget install OpenSSL.Light
    exit /b 1
)

REM Generate private key
openssl genrsa 2048 2>nul | openssl pkcs8 -topk8 -inform PEM -out "%KEYS_DIR%\rsa_key.p8" -nocrypt

REM Generate public key
openssl rsa -in "%KEYS_DIR%\rsa_key.p8" -pubout -out "%KEYS_DIR%\rsa_key.pub" 2>nul

echo [OK] Generated keys in %KEYS_DIR%\
goto :after_keygen

:skip_keygen
echo [OK] Keys ready

:after_keygen

REM Extract public key value (remove header/footer)
set "PUBLIC_KEY="
for /f "usebackq delims=" %%a in ("%KEYS_DIR%\rsa_key.pub") do (
    set "line=%%a"
    if "!line:~0,5!" neq "-----" (
        set "PUBLIC_KEY=!PUBLIC_KEY!%%a"
    )
)

echo.

REM ##############################################################################
REM STEP 3: Register Public Key with Snowflake
REM ##############################################################################

echo Step 3: Register Public Key with Snowflake

REM Generate SQL script with the actual public key
(
echo /*******************************************************************************
echo  * GENERATED: Key-Pair Authentication Setup
echo  * 
echo  * WARNING: AUTO-GENERATED - DO NOT COMMIT THIS FILE
echo  * 
echo  * PURPOSE: Register public key for SFE_INGEST_USER
echo  * GENERATED: %DATE% %TIME%
echo  ******************************************************************************/
echo.
echo USE ROLE SECURITYADMIN;
echo.
echo -- Create or update user with public key
echo CREATE USER IF NOT EXISTS SFE_INGEST_USER
echo   COMMENT = 'DEMO: Snowpipe Streaming SDK user ^| Expires: 2025-12-24';
echo.
echo ALTER USER SFE_INGEST_USER
echo   SET RSA_PUBLIC_KEY = '%PUBLIC_KEY%';
echo.
echo -- Grant role
echo GRANT ROLE sfe_ingest_role TO USER SFE_INGEST_USER;
echo.
echo -- Grant privileges ^(CRITICAL: Required for Snowpipe Streaming SDK^)
echo USE ROLE SYSADMIN;
echo GRANT USAGE ON DATABASE SNOWFLAKE_EXAMPLE TO ROLE sfe_ingest_role;
echo GRANT USAGE ON SCHEMA SNOWFLAKE_EXAMPLE.RAW_INGESTION TO ROLE sfe_ingest_role;
echo GRANT INSERT ON TABLE SNOWFLAKE_EXAMPLE.RAW_INGESTION.RAW_BADGE_EVENTS TO ROLE sfe_ingest_role;
echo GRANT OPERATE ON PIPE SNOWFLAKE_EXAMPLE.RAW_INGESTION.SFE_BADGE_EVENTS_PIPE TO ROLE sfe_ingest_role;
echo.
echo -- Verify
echo USE ROLE SECURITYADMIN;
echo SHOW USERS LIKE 'SFE_INGEST_USER';
echo SHOW GRANTS TO ROLE sfe_ingest_role;
echo.
echo SELECT 
echo   '✅ Authentication configured' AS status,
echo   'User: SFE_INGEST_USER' AS user_info,
echo   'Role: sfe_ingest_role' AS role_info,
echo   'Ready to send events' AS next_step;
) > "%SECRETS_DIR%\configure_auth_READY.sql"

echo [OK] Generated SQL: %SECRETS_DIR%\configure_auth_READY.sql
echo.
echo Please run this generated SQL in Snowsight to register the public key:
echo   Open Snowsight -^> New Worksheet -^> Paste contents of:
echo   %SECRETS_DIR%\configure_auth_READY.sql
echo.
pause
echo.

REM ##############################################################################
REM STEP 4: Pre-populate config.json
REM ##############################################################################

echo Step 4: Generate config.json

(
echo {
echo   "account": "%SNOWFLAKE_ACCOUNT%",
echo   "user": "SFE_INGEST_USER",
echo   "role": "sfe_ingest_role",
echo   "private_key_path": "keys/rsa_key.p8",
echo   "database": "SNOWFLAKE_EXAMPLE",
echo   "schema": "RAW_INGESTION",
echo   "pipe_name": "sfe_badge_events_pipe",
echo   "sample_events": 10
echo }
) > "%SECRETS_DIR%\config.json"

echo [OK] Created: %SECRETS_DIR%\config.json
echo    Account: %SNOWFLAKE_ACCOUNT%
echo    User: SFE_INGEST_USER
echo    Target: SNOWFLAKE_EXAMPLE.RAW_INGESTION.RAW_BADGE_EVENTS
echo.

REM ##############################################################################
REM SECURITY WARNING
REM ##############################################################################

echo.
echo ================================================================
echo   WARNING: SECURITY
echo ================================================================
echo.
echo Generated files in .secrets\ contain YOUR credentials:
echo.
echo   - Snowflake account identifier
echo   - RSA private key
echo   - User configuration
echo.
echo [OK] Auto-protected via .git\info\exclude
echo [OK] Verification check will run before script exits
echo.
echo NEVER commit .secrets\ directory!
echo.
echo ================================================================
echo.

REM ##############################################################################
REM STEP 5: Setup Python Environment
REM ##############################################################################

echo Step 5: Setup Python Environment

cd /d "%SECRETS_DIR%"

if not exist ".venv" (
    echo Creating virtual environment...
    python -m venv .venv
    echo [OK] Created .venv
) else (
    echo [OK] .venv exists
)

echo Activating virtual environment...
call .venv\Scripts\activate.bat

echo Installing dependencies...
python -m pip install -q --upgrade pip
pip install -q -r requirements.txt

echo [OK] Python environment ready
echo.

REM ##############################################################################
REM STEP 6: Send Test Events
REM ##############################################################################

echo Step 6: Send Test Events

echo Sending 10 sample RFID badge events...
python send_events_stream.py

echo.
echo [OK] Events sent!
echo.

REM ##############################################################################
REM STEP 7: Validation
REM ##############################################################################

echo Step 7: Validate Pipeline
echo.
echo Run this query in Snowsight to verify:
echo.
echo -- Check ingested events
echo SELECT 
echo   COUNT(*) AS total_events,
echo   MIN(RECORD_CONTENT:timestamp)::TIMESTAMP_NTZ AS first_event,
echo   MAX(RECORD_CONTENT:timestamp)::TIMESTAMP_NTZ AS last_event
echo FROM SNOWFLAKE_EXAMPLE.RAW_INGESTION.RAW_BADGE_EVENTS;
echo.
echo -- Check stream processing
echo SELECT COUNT(*) AS processed_events
echo FROM SNOWFLAKE_EXAMPLE.STAGING_LAYER.STG_BADGE_EVENTS;
echo.
echo -- View analytics
echo SELECT * FROM SNOWFLAKE_EXAMPLE.RAW_INGESTION.V_INGESTION_HEALTH;
echo.

REM ##############################################################################
REM SECURITY CHECK: Verify .secrets\ not staged
REM ##############################################################################

where git >nul 2>&1
if not errorlevel 1 (
    git diff --cached --name-only 2>nul | findstr /R "\.secrets\\" >nul 2>&1
    if not errorlevel 1 (
        echo.
        echo ================================================================
        echo   SECURITY VIOLATION DETECTED
        echo ================================================================
        echo.
        echo ERROR: .secrets\ directory is staged for commit!
        echo.
        echo TO FIX:
        echo   git reset HEAD .secrets\
        echo.
        echo ================================================================
        pause
        exit /b 1
    )
)

REM ##############################################################################
REM COMPLETE
REM ##############################################################################

echo.
echo ================================================================
echo   SETUP COMPLETE
echo ================================================================
echo.
echo What just happened:
echo   [OK] Generated RSA keys -^> %KEYS_DIR%\
echo   [OK] Registered public key with Snowflake
echo   [OK] Created config.json with your account
echo   [OK] Setup Python environment
echo   [OK] Sent 10 test events
echo.
echo Next steps:
echo   1. Run validation queries above to see your data
echo   2. Monitor: docs\04-MONITORING.md
echo   3. Cleanup: @sql\99_cleanup\cleanup.sql
echo.
echo Happy streaming!
echo.

pause
endlocal

