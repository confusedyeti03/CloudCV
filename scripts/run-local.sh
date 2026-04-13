#!/bin/bash
# =============================================================================
# Quick Run Script for CloudCV (assumes setup-wsl.sh already run once)
# =============================================================================
# PURPOSE: Start cv-service quickly after initial setup
#
# USAGE: 
#   1. Open WSL terminal
#   2. cd /mnt/c/Users/confused/Documents/Project/CloudCV
#   3. bash scripts/run-local.sh
# =============================================================================

set -e

cd /mnt/c/Users/confused/Documents/Project/CloudCV/cv-service

if [ ! -d "venv" ]; then
    echo "Virtual environment not found. Run setup-wsl.sh first."
    exit 1
fi

source venv/bin/activate

echo ""
echo "╔════════════════════════════════════════════════════════════╗"
echo "║  CloudCV cv-service starting...                            ║"
echo "║                                                            ║"
echo "║  Endpoints:                                                ║"
echo "║    • CV Page:    http://localhost:8000/                    ║"
echo "║    • Health:     http://localhost:8000/health              ║"
echo "║    • PDF (CA):   http://localhost:8000/preview/ca          ║"
echo "║    • API Docs:   http://localhost:8000/docs                ║"
echo "║                                                            ║"
echo "║  Press Ctrl+C to stop                                      ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""

uvicorn app:app --host 0.0.0.0 --port 8000 --reload
