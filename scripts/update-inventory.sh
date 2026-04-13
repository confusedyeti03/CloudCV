#!/usr/bin/env bash

set -euo pipefail

info() {
  echo "[update-inventory] $*"
}

error() {
  echo "[update-inventory] ERROR: $*" >&2
}

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TERRAFORM_DIR="$ROOT_DIR/terraform"
INVENTORY_FILE="$ROOT_DIR/ansible/inventory/hosts.yml"

info "Starting inventory update"

if [[ ! -d "$TERRAFORM_DIR" ]]; then
  error "Terraform directory not found: $TERRAFORM_DIR"
  exit 1
fi

if [[ ! -f "$INVENTORY_FILE" ]]; then
  error "Inventory file not found: $INVENTORY_FILE"
  exit 1
fi

if ! command -v terraform >/dev/null 2>&1; then
  error "terraform command not found in PATH"
  exit 1
fi

info "Running: terraform output -json (in $TERRAFORM_DIR)"
TF_JSON="$(cd "$TERRAFORM_DIR" && terraform output -json)" || {
  error "Failed to run terraform output -json"
  exit 1
}

if command -v jq >/dev/null 2>&1; then
  info "Parsing public_ip using jq"
  PUBLIC_IP="$(printf '%s' "$TF_JSON" | jq -r '.public_ip.value // empty')"
else
  info "jq not found; parsing public_ip using python"
  PUBLIC_IP="$(printf '%s' "$TF_JSON" | python - <<'PY'
import json, sys
data = json.load(sys.stdin)
value = data.get("public_ip", {}).get("value", "")
print(value)
PY
)"
fi

if [[ -z "$PUBLIC_IP" ]]; then
  error "public_ip not found in terraform output"
  exit 1
fi

info "Updating inventory with public IP: $PUBLIC_IP"

python - <<PY
from pathlib import Path
path = Path(r"$INVENTORY_FILE")
text = path.read_text()
updated = text.replace("<EIP>", "$PUBLIC_IP")
path.write_text(updated)
PY

info "Inventory update complete: $INVENTORY_FILE"
