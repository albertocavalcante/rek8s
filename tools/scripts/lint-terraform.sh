#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/../.." && pwd)"
config_file="$repo_root/tools/lint/tflint.hcl"

tflint --init --config="$config_file" >/dev/null

while IFS= read -r dir; do
  echo "==> tflint: $dir"
  tflint --chdir="$dir" --config="$config_file"
done < <("$repo_root/tools/scripts/terraform-roots.sh")
