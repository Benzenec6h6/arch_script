#!/usr/bin/env bash
set -euo pipefail

for script in {00..02}-*.sh; do
  echo "==> Running $script"
  bash "$script"
done
