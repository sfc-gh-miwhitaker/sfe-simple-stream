#!/bin/bash
################################################################################
# Event Simulator - Unix/macOS Wrapper
#
# PURPOSE: Activate virtual environment and run Python event simulator
# USAGE: ./send_events.sh [--count N]
################################################################################

set -e

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
VENV_PATH="$PROJECT_ROOT/.secrets/.venv"

# Check virtual environment exists
if [ ! -d "$VENV_PATH" ]; then
    echo "ERROR: Virtual environment not found at $VENV_PATH"
    echo "Run ./tools/02_setup_and_test.sh first to create environment"
    exit 1
fi

# Activate virtual environment
source "$VENV_PATH/bin/activate"

# Run Python simulator
cd "$SCRIPT_DIR"
python send_events.py "$@"
