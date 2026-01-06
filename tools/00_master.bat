@echo off
setlocal

set SCRIPT_DIR=%~dp0
set PROJECT_ROOT=%SCRIPT_DIR%..

if "%1"=="" goto :help
if /i "%1"=="help" goto :help
if /i "%1"=="--help" goto :help
if /i "%1"=="-h" goto :help

if /i "%1"=="deploy" goto :deploy
if /i "%1"=="test" goto :test
if /i "%1"=="cleanup" goto :cleanup

echo ERROR: Unknown command: %1
echo.
goto :help

:help
echo Simple Stream - Master Automation Entry Point
echo.
echo This repo is a timeboxed demo. Deployment is blocked after the expiration date enforced by deploy_all.sql.
echo.
echo Usage:
echo   .\\tools\\00_master.bat deploy
echo   .\\tools\\00_master.bat test [--all^|--step N]
echo   .\\tools\\00_master.bat cleanup
echo   .\\tools\\00_master.bat help
echo.
echo Commands:
echo   deploy   Print Snowsight "Run All" deployment instructions (deploy_all.sql)
echo   test     Run the local setup + simulator helper (tools\\02_setup_and_test.bat)
echo   cleanup  Print cleanup instructions (sql\\99_cleanup\\cleanup.sql)
echo   help     Show this message
exit /b 0

:deploy
echo Deployment (Snowsight):
echo 1. Open Snowsight and create a new SQL worksheet.
echo 2. Copy the full contents of:
echo    %PROJECT_ROOT%\\deploy_all.sql
echo 3. Paste into the worksheet and click "Run All".
echo.
echo Note: deploy_all.sql enforces demo expiration and will block deployment if expired.
exit /b 0

:test
shift
call "%SCRIPT_DIR%02_setup_and_test.bat" %*
exit /b %ERRORLEVEL%

:cleanup
echo Cleanup (Snowsight):
echo Run this script in a Snowsight worksheet:
echo   @sql\\99_cleanup\\cleanup.sql
exit /b 0
