#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"

while IFS= read -r dir; do
  echo "==> terraform validate: $dir"
  terraform -chdir="$dir" init -backend=false -input=false >/dev/null
  terraform -chdir="$dir" validate
done < <("$repo_root/scripts/terraform-roots.sh")
