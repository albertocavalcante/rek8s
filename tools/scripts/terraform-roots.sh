#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/../.." && pwd)"

find "$repo_root/examples/terraform" -mindepth 1 -maxdepth 1 -type d | sort
