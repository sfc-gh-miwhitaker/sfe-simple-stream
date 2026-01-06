@echo off
REM ##############################################################################
REM Event Simulator - Windows Wrapper
REM
REM PURPOSE: Activate virtual environment and run Python event simulator
REM USAGE: send_events.bat [--count N]
REM ##############################################################################

setlocal

REM Get script directory
set SCRIPT_DIR=%~dp0
set PROJECT_ROOT=%SCRIPT_DIR%..
set VENV_PATH=%PROJECT_ROOT%\.secrets\.venv

REM Check virtual environment exists
if not exist "%VENV_PATH%\Scripts\activate.bat" (
    echo ERROR: Virtual environment not found at %VENV_PATH%
    echo Run .\tools\02_setup_and_test.bat first to create environment
    exit /b 1
)

REM Activate virtual environment
call "%VENV_PATH%\Scripts\activate.bat"

REM Run Python simulator
cd /d "%SCRIPT_DIR%"
python send_events.py %*

endlocal
