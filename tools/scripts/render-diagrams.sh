#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
REPO_ROOT=$(cd "${SCRIPT_DIR}/../.." && pwd)

if [[ "${1-}" == "--check" ]]; then
  tmpdir=$(mktemp -d)
  trap 'rm -rf "${tmpdir}"' EXIT

  d2 "${REPO_ROOT}/docs/diagrams/overview.d2" "${tmpdir}/overview.svg"
  d2 "${REPO_ROOT}/docs/diagrams/data-flow.d2" "${tmpdir}/data-flow.svg"

  diff -u "${REPO_ROOT}/docs/diagrams/overview.svg" "${tmpdir}/overview.svg"
  diff -u "${REPO_ROOT}/docs/diagrams/data-flow.svg" "${tmpdir}/data-flow.svg"
  exit 0
fi

d2 "${REPO_ROOT}/docs/diagrams/overview.d2" "${REPO_ROOT}/docs/diagrams/overview.svg"
d2 "${REPO_ROOT}/docs/diagrams/data-flow.d2" "${REPO_ROOT}/docs/diagrams/data-flow.svg"
