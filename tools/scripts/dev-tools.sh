#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/../.." && pwd)"
brewfile="$repo_root/tools/Brewfile.dev"

usage() {
  cat <<'EOF'
Install rek8s local development tools with Homebrew.

Usage:
  ./tools/scripts/dev-tools.sh
  ./tools/scripts/dev-tools.sh --check
  ./tools/scripts/dev-tools.sh --print

Options:
  --check   Exit non-zero if any required tool is missing.
  --print   Print the tools declared in the Brewfile and exit.
  --help    Show this help text.
EOF
}

log() {
  printf '%s\n' "$*"
}

error() {
  printf 'Error: %s\n' "$*" >&2
}

require_brew() {
  if ! command -v brew >/dev/null 2>&1; then
    error "Homebrew is not installed."
    error "Install it first from https://brew.sh and then rerun this script."
    exit 1
  fi
}

require_macos() {
  if [[ "$(uname -s)" != "Darwin" ]]; then
    error "This installer is currently intended for macOS with Homebrew."
    error "Use $brewfile as the source of truth if you want to install the same tools elsewhere."
    exit 1
  fi
}

read_brewfile_formulas() {
  awk -F'"' '/^brew "/ { print $2 }' "$brewfile"
}

print_tools() {
  log "rek8s development tools:"
  while IFS= read -r formula; do
    printf '  - %s\n' "$formula"
  done < <(read_brewfile_formulas)
}

check_tools() {
  local missing=0
  while IFS= read -r formula; do
    if brew list --formula "$formula" >/dev/null 2>&1; then
      printf 'OK   %s\n' "$formula"
    else
      printf 'MISS %s\n' "$formula"
      missing=1
    fi
  done < <(read_brewfile_formulas)
  return "$missing"
}

install_with_bundle() {
  log "Installing rek8s development tools with brew bundle..."
  brew bundle --file="$brewfile" --no-lock
}

install_individually() {
  log "Installing rek8s development tools with brew install..."
  while IFS= read -r formula; do
    if brew list --formula "$formula" >/dev/null 2>&1; then
      printf 'SKIP %s (already installed)\n' "$formula"
    else
      printf 'INST %s\n' "$formula"
      brew install "$formula"
    fi
  done < <(read_brewfile_formulas)
}

main() {
  local mode="install"

  if [[ $# -gt 1 ]]; then
    usage
    exit 1
  fi

  if [[ $# -eq 1 ]]; then
    case "$1" in
      --check)
        mode="check"
        ;;
      --print)
        mode="print"
        ;;
      --help|-h)
        usage
        exit 0
        ;;
      *)
        usage
        exit 1
        ;;
    esac
  fi

  if [[ ! -f "$brewfile" ]]; then
    error "Expected Brewfile not found: $brewfile"
    exit 1
  fi

  if [[ "$mode" == "print" ]]; then
    print_tools
    exit 0
  fi

  require_macos
  require_brew

  if [[ "$mode" == "check" ]]; then
    check_tools
    exit $?
  fi

  if brew bundle --help >/dev/null 2>&1; then
    install_with_bundle
  else
    install_individually
  fi

  log
  log "Installed tool status:"
  check_tools
}

main "$@"
