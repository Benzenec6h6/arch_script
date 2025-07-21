#!/usr/bin/env bash
set -euo pipefail

for script in ./scripts/{00..02}_*.sh; do
  echo "==> Running $script"
  bash "$script"
done
