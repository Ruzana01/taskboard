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

# ------------------------------------------------------------
# STEP 3: Setup Virtual Environment
# ------------------------------------------------------------

echo ""
echo "=== Step 3/8: Setting up Python Virtual Environment ==="

if [ ! -d "$VENV_DIR" ]; then
    echo ">> Building virtual environment in '$VENV_DIR'..."
    python3 -m venv "$VENV_DIR"
else
    echo ">> Virtual environment already exists."
fi

# ------------------------------------------------------------
# STEP 4: Install Python Libraries
# ------------------------------------------------------------

echo ""
echo "=== Step 4/8: Installing Python Requirements ==="

"$APP_DIR/$VENV_DIR/bin/python" -m pip install --upgrade pip
"$APP_DIR/$VENV_DIR/bin/python" -m pip install uv
"$APP_DIR/$VENV_DIR/bin/python" -m uv pip install -r requirements.txt

echo ">> Python packages installed successfully."


# ------------------------------------------------------------
# STEP 5: Verify PostgreSQL Service Status
# ------------------------------------------------------------

echo ""
echo "=== Step 5/8: Validating Database Service ==="

if ! sudo systemctl is-active --quiet postgresql; then
    echo ">> PostgreSQL daemon is offline. Launching service..."
    sudo systemctl start postgresql
else
    echo ">> PostgreSQL service is active."
fi

# Ensure PostgreSQL accepts incoming requests
if ! sudo -u postgres pg_isready >/dev/null 2>&1; then
    echo "[CRITICAL ERROR] PostgreSQL service is not accepting connections!"
    exit 1
fi

echo ">> PostgreSQL service is responsive."

# ------------------------------------------------------------
# STEP 6: Configure DB User & Target Schema
# ------------------------------------------------------------

echo ""
echo "=== Step 6/8: Setting up PostgreSQL Credentials & DB ==="

# Check if database user exists
if sudo -u postgres psql -tAc \
    "SELECT 1 FROM pg_roles WHERE rolname='$DB_USER'" | grep -q 1; then

    echo ">> Role '$DB_USER' already configured."
else
    echo ">> Creating new DB user '$DB_USER'..."

    sudo -u postgres psql -v ON_ERROR_STOP=1 -c \
        "CREATE USER $DB_USER WITH PASSWORD '$DB_PASSWORD';"
fi

# Check if target database exists
if sudo -u postgres psql -tAc \
    "SELECT 1 FROM pg_database WHERE datname='$DB_NAME'" | grep -q 1; then

    echo ">> Database '$DB_NAME' already present."
else
    echo ">> Initializing new database '$DB_NAME'..."

    sudo -u postgres createdb -O "$DB_USER" "$DB_NAME"
fi

echo ">> Database setup finalized."
