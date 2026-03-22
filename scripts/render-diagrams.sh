#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIAGRAM_DIR="${ROOT_DIR}/docs/diagrams"
D2_BIN="${D2_BIN:-d2}"
LAYOUT="${D2_LAYOUT:-elk}"
CHECK_ONLY=false

if [[ "${1:-}" == "--check" ]]; then
  CHECK_ONLY=true
fi

if ! command -v "${D2_BIN}" >/dev/null 2>&1; then
  echo "error: d2 is required but was not found in PATH" >&2
  exit 1
fi

shopt -s nullglob
sources=("${DIAGRAM_DIR}"/*.d2)
shopt -u nullglob

if [[ "${#sources[@]}" -eq 0 ]]; then
  echo "error: no D2 sources found in ${DIAGRAM_DIR}" >&2
  exit 1
fi

for source in "${sources[@]}"; do
  svg="${source%.d2}.svg"
  if [[ "${CHECK_ONLY}" == true ]]; then
    tmp_svg="$(mktemp)"
    "${D2_BIN}" --layout "${LAYOUT}" --pad 32 --scale 1 --omit-version "${source}" "${tmp_svg}" >/dev/null
    if ! cmp -s "${tmp_svg}" "${svg}"; then
      echo "out of date: ${svg}" >&2
      rm -f "${tmp_svg}"
      exit 1
    fi
    rm -f "${tmp_svg}"
  else
    "${D2_BIN}" --layout "${LAYOUT}" --pad 32 --scale 1 --omit-version "${source}" "${svg}" >/dev/null
    echo "rendered ${svg#${ROOT_DIR}/}"
  fi
done
