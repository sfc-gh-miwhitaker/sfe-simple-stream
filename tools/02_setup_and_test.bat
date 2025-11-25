@echo off
REM ##############################################################################
REM Master Orchestration Script - Simple Stream Demo (Windows)
REM 
REM PURPOSE: Fully automated setup and testing with step-by-step execution
REM TIME: ~2 minutes (full run)
REM 
REM USAGE: 
REM   .\tools\02_setup_and_test.bat              Run all steps (default)
REM   .\tools\02_setup_and_test.bat --all        Explicitly run all steps
REM   .\tools\02_setup_and_test.bat --step 5     Run single step (1-7)
REM   .\tools\02_setup_and_test.bat --help       Show usage
REM
REM STEPS:
REM   1. Get Snowflake account identifier
REM   2. Generate RSA key pair
REM   3. Register public key with Snowflake
REM   4. Generate config.json
REM   5. Setup Python environment
REM   6. Send test events
REM   7. Display verification queries
REM ##############################################################################

setlocal enabledelayedexpansion

REM Script directory setup
set SCRIPT_DIR=%~dp0
set PROJECT_ROOT=%SCRIPT_DIR%..
set SECRETS_DIR=%PROJECT_ROOT%\.secrets
set KEYS_DIR=%SECRETS_DIR%\keys
set SIMULATOR_DIR=%PROJECT_ROOT%\simulator

REM Global variable for account
set SNOWFLAKE_ACCOUNT=

REM Parse arguments
set RUN_ALL=true
set SPECIFIC_STEP=

if "%1"=="--help" goto :show_usage
if "%1"=="-h" goto :show_usage
if "%1"=="--all" set RUN_ALL=true & goto :start
if "%1"=="--step" (
    if "%2"=="" (
        echo ERROR: --step requires a step number (1-7)
        goto :show_usage
    )
    set SPECIFIC_STEP=%2
    set RUN_ALL=false
    goto :start
)
if not "%1"=="" (
    echo ERROR: Unknown option: %1
    goto :show_usage
)

:start
echo ====================================================================
echo   Simple Stream - Master Setup ^& Test
echo ====================================================================
echo.

if "%RUN_ALL%"=="true" (
    call :step_1_get_account
    call :step_2_generate_keys
    call :step_3_register_auth
    call :step_4_create_config
    call :show_security_warning
    call :step_5_setup_python
    call :step_6_send_events
    call :step_7_verify
    call :security_check
    
    echo.
    echo ====================================================================
    echo   SETUP COMPLETE
    echo ====================================================================
    echo.
    echo What just happened:
    echo   - Generated RSA keys -^> %KEYS_DIR%
    echo   - Registered public key with Snowflake
    echo   - Created config.json with your account
    echo   - Setup Python environment
    echo   - Sent 10 test events
    echo.
    echo Next steps:
    echo   1. Run validation queries above to see your data
    echo   2. Monitor: docs\04-MONITORING.md
    echo   3. Cleanup: @sql\99_cleanup\cleanup.sql
    echo.
) else (
    if "%SPECIFIC_STEP%"=="1" call :step_1_get_account
    if "%SPECIFIC_STEP%"=="2" call :step_2_generate_keys
    if "%SPECIFIC_STEP%"=="3" call :step_3_register_auth
    if "%SPECIFIC_STEP%"=="4" call :step_4_create_config
    if "%SPECIFIC_STEP%"=="5" call :step_5_setup_python
    if "%SPECIFIC_STEP%"=="6" call :step_6_send_events
    if "%SPECIFIC_STEP%"=="7" call :step_7_verify
    
    echo.
    echo Step %SPECIFIC_STEP% completed
)

goto :eof

REM ##############################################################################
REM Usage / Help
REM ##############################################################################

:show_usage
echo Usage: %0 [OPTIONS]
echo.
echo Options:
echo   --all          Run all steps (default if no options specified)
echo   --step N       Run specific step (1-7)
echo   --help         Show this help message
echo.
echo Steps:
echo   1. Get Snowflake account identifier
echo   2. Generate RSA key pair
echo   3. Register public key with Snowflake
echo   4. Generate config.json
echo   5. Setup Python environment
echo   6. Send test events
echo   7. Display verification queries
echo.
echo Examples:
echo   %0                  # Run all steps
echo   %0 --all            # Run all steps (explicit)
echo   %0 --step 5         # Run only step 5 (Python setup)
echo.
exit /b 0

REM ##############################################################################
REM STEP 1: Get Snowflake Account Identifier
REM ##############################################################################

:step_1_get_account
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

echo Account: %SNOWFLAKE_ACCOUNT%
echo.
goto :eof

REM ##############################################################################
REM STEP 2: Generate RSA Key Pair
REM ##############################################################################

:step_2_generate_keys
echo Step 2: Generate RSA Key Pair

if not exist "%SECRETS_DIR%" mkdir "%SECRETS_DIR%"
if not exist "%KEYS_DIR%" mkdir "%KEYS_DIR%"

if exist "%KEYS_DIR%\rsa_key.p8" (
    echo WARNING: RSA key already exists
    set /p REGENERATE="Regenerate? (y/N): "
    if /i not "!REGENERATE!"=="y" (
        echo Using existing key
        echo.
        goto :eof
    )
    del "%KEYS_DIR%\rsa_key.p8"
    del "%KEYS_DIR%\rsa_key.pub"
)

echo Generating 2048-bit RSA key pair...

REM Generate private key
openssl genrsa 2048 | openssl pkcs8 -topk8 -inform PEM -out "%KEYS_DIR%\rsa_key.p8" -nocrypt

REM Generate public key
openssl rsa -in "%KEYS_DIR%\rsa_key.p8" -pubout -out "%KEYS_DIR%\rsa_key.pub"

echo Generated keys in %KEYS_DIR%
echo.
goto :eof

REM ##############################################################################
REM STEP 3: Register Public Key with Snowflake
REM ##############################################################################

:step_3_register_auth
echo Step 3: Register Public Key with Snowflake

REM Extract public key (remove header/footer)
set PUBLIC_KEY=
for /f "delims=" %%i in ('type "%KEYS_DIR%\rsa_key.pub" ^| findstr /v "BEGIN PUBLIC KEY" ^| findstr /v "END PUBLIC KEY"') do (
    set PUBLIC_KEY=!PUBLIC_KEY!%%i
)

REM Generate SQL script
(
echo /*******************************************************************************
echo  * GENERATED: Key-Pair Authentication Setup
echo  * 
echo  * WARNING: AUTO-GENERATED - DO NOT COMMIT THIS FILE
echo  * 
echo  * PURPOSE: Register public key for SFE_INGEST_USER
echo  * GENERATED: %date% %time%
echo  ******************************************************************************/
echo.
echo USE ROLE SECURITYADMIN;
echo.
echo -- Create or update user with public key
echo CREATE USER IF NOT EXISTS SFE_INGEST_USER
echo   COMMENT = 'DEMO: Snowpipe Streaming SDK user ^| Expires: 2025-12-25';
echo.
echo ALTER USER SFE_INGEST_USER
echo   SET RSA_PUBLIC_KEY = '!PUBLIC_KEY!';
echo.
echo -- Grant role
echo GRANT ROLE sfe_ingest_role TO USER SFE_INGEST_USER;
echo.
echo -- Grant privileges (CRITICAL: Required for Snowpipe Streaming SDK^)
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

echo Generated SQL: %SECRETS_DIR%\configure_auth_READY.sql
echo.
echo Please run this generated SQL in Snowsight to register the public key:
echo   Open Snowsight -^> New Worksheet -^> Paste contents of:
echo   %SECRETS_DIR%\configure_auth_READY.sql
echo.
pause
echo.
goto :eof

REM ##############################################################################
REM STEP 4: Generate config.json
REM ##############################################################################

:step_4_create_config
echo Step 4: Generate config.json

if "%SNOWFLAKE_ACCOUNT%"=="" (
    echo ERROR: Account identifier not set. Run step 1 first.
    exit /b 1
)

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

echo Created: %SECRETS_DIR%\config.json
echo    Account: %SNOWFLAKE_ACCOUNT%
echo    User: SFE_INGEST_USER
echo    Target: SNOWFLAKE_EXAMPLE.RAW_INGESTION.RAW_BADGE_EVENTS
echo.
goto :eof

REM ##############################################################################
REM STEP 5: Setup Python Environment
REM ##############################################################################

:step_5_setup_python
echo Step 5: Setup Python Environment

if not exist "%SECRETS_DIR%\.venv" (
    echo Creating virtual environment...
    python -m venv "%SECRETS_DIR%\.venv"
    echo Created .venv
) else (
    echo .venv exists
)

echo Activating virtual environment...
call "%SECRETS_DIR%\.venv\Scripts\activate.bat"

echo Installing dependencies from simulator\requirements.txt...
python -m pip install -q --upgrade pip
python -m pip install -q -r "%SIMULATOR_DIR%\requirements.txt"

echo Python environment ready
echo.
goto :eof

REM ##############################################################################
REM STEP 6: Send Test Events
REM ##############################################################################

:step_6_send_events
echo Step 6: Send Test Events

echo Sending 10 sample RFID badge events...

call "%SIMULATOR_DIR%\send_events.bat"

echo.
echo Events sent!
echo.
goto :eof

REM ##############################################################################
REM STEP 7: Validation Queries
REM ##############################################################################

:step_7_verify
echo Step 7: Validate Pipeline
echo.
echo Run this query in Snowsight to verify:
echo.
echo -- Check ingested events
echo SELECT 
echo   COUNT(^*^) AS total_events,
echo   MIN(RECORD_CONTENT:timestamp^)::TIMESTAMP_NTZ AS first_event,
echo   MAX(RECORD_CONTENT:timestamp^)::TIMESTAMP_NTZ AS last_event
echo FROM SNOWFLAKE_EXAMPLE.RAW_INGESTION.RAW_BADGE_EVENTS;
echo.
echo -- Check stream processing
echo SELECT COUNT(^*^) AS processed_events
echo FROM SNOWFLAKE_EXAMPLE.STAGING_LAYER.STG_BADGE_EVENTS;
echo.
echo -- View analytics
echo SELECT * FROM SNOWFLAKE_EXAMPLE.RAW_INGESTION.V_INGESTION_HEALTH;
echo.
goto :eof

REM ##############################################################################
REM Security Warning
REM ##############################################################################

:show_security_warning
echo.
echo ====================================================================
echo   WARNING: SECURITY
echo ====================================================================
echo.
echo Generated files in .secrets\ contain YOUR credentials:
echo.
echo   * Snowflake account identifier
echo   * RSA private key
echo   * User configuration
echo.
echo   Auto-protected via .git\info\exclude
echo   Verification check will run before script exits
echo.
echo   NEVER commit .secrets\ directory!
echo.
echo ====================================================================
echo.
goto :eof

REM ##############################################################################
REM Security Check
REM ##############################################################################

:security_check
where git >nul 2>nul
if %ERRORLEVEL% == 0 (
    for /f "delims=" %%i in ('git diff --cached --name-only 2^>nul ^| findstr "^\.secrets\\"') do (
        echo.
        echo ====================================================================
        echo   SECURITY VIOLATION DETECTED
        echo ====================================================================
        echo.
        echo .secrets\ directory is STAGED for commit!
        echo.
        echo Files staged: %%i
        echo.
        echo TO FIX:
        echo   git reset HEAD .secrets\
        echo.
        echo ====================================================================
        exit /b 1
    )
)
goto :eof
