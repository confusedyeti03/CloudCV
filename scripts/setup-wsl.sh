#!/bin/bash
# =============================================================================
# WSL Setup Script for CloudCV Testing
# =============================================================================
# PURPOSE: Install dependencies and run cv-service locally in WSL
#
# USAGE: 
#   1. Open WSL terminal (wsl -d Debian)
#   2. cd /mnt/c/Users/confused/Documents/Project/CloudCV
#   3. bash scripts/setup-wsl.sh
# =============================================================================

set -e

echo "=== Installing system dependencies ==="
sudo apt-get update
sudo apt-get install -y \
    python3-pip \
    python3-venv \
    libpango-1.0-0 \
    libpangocairo-1.0-0 \
    libgdk-pixbuf2.0-0 \
    libcairo2 \
    libffi-dev \
    shared-mime-info

echo "=== Creating Python virtual environment ==="
cd /mnt/c/Users/confused/Documents/Project/CloudCV/cv-service
python3 -m venv venv
source venv/bin/activate

echo "=== Installing Python dependencies ==="
pip install --upgrade pip
pip install -r requirements.txt

echo "=== Starting cv-service ==="
echo ""
echo "Server starting at http://localhost:8000"
echo "Press Ctrl+C to stop"
echo ""
uvicorn app:app --host 0.0.0.0 --port 8000 --reload
