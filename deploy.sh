#!/bin/sh

# ------------------------------------------------------------
# Auto-install & Setup script for TaskBoard App
# ------------------------------------------------------------

# Exit immediately if a command exits with a non-zero status.
set -e

# ------------------------------------------------------------
# Environment Variables & Settings
# ------------------------------------------------------------

APP_NAME="taskboard"
APP_DIR="$(pwd)"
REPOSITORY_URL="https://github.com/sharton/taskboard"

DB_NAME="taskboard"
DB_USER="taskboard"
DB_PASSWORD="taskboard"

APP_HOST="0.0.0.0"
APP_PORT="8080"

VENV_DIR=".venv"
PID_FILE="$APP_DIR/uvicorn.pid"
LOG_FILE="$APP_DIR/uvicorn.log"

echo "=================================================="
echo ">>> Starting TaskBoard Deployment Workflow <<<"
echo "=================================================="

# ------------------------------------------------------------
# STEP 1: Verify & Install Required System Packages
# ------------------------------------------------------------

echo ""
echo "=== Step 1/8: Checking Linux Dependencies ==="

PACKAGES=""

if ! command -v git >/dev/null 2>&1; then
    PACKAGES="$PACKAGES git"
fi

if ! command -v python3 >/dev/null 2>&1; then
    PACKAGES="$PACKAGES python3"
fi

if ! command -v psql >/dev/null 2>&1; then
    PACKAGES="$PACKAGES postgresql"
fi

if ! command -v curl >/dev/null 2>&1; then
    PACKAGES="$PACKAGES curl"
fi

# Ensure venv support is present for python3
if ! python3 -m venv --help >/dev/null 2>&1; then
    PACKAGES="$PACKAGES python3-venv"
fi

if [ -n "$PACKAGES" ]; then
    echo ">> Missing packages found:$PACKAGES"
    echo ">> Updating apt index and installing dependencies..."

    sudo apt-get update
    sudo apt-get install -y $PACKAGES
else
    echo ">> All required system packages are already installed."
fi

# ------------------------------------------------------------
# STEP 2: Verify Source Code Directory
# ------------------------------------------------------------

echo ""
echo "=== Step 2/8: Preparing Project Files ==="

if [ ! -f "requirements.txt" ]; then
    echo ">> requirements.txt missing in current directory."

    if [ -d "$APP_NAME" ]; then
        echo ">> Local folder '$APP_NAME' detected, entering directory..."
        cd "$APP_NAME"
        APP_DIR="$(pwd)"
    else
        echo ">> Repository missing. Fetching code from GitHub..."
        git clone "$REPOSITORY_URL" "$APP_NAME"
        cd "$APP_NAME"
        APP_DIR="$(pwd)"
    fi
else
    echo ">> TaskBoard source files detected."
fi

if [ ! -f "requirements.txt" ]; then
    echo "[CRITICAL ERROR] Unable to locate requirements.txt! Deployment aborted."
    exit 1
fi

echo ">> Working Directory: $APP_DIR"
