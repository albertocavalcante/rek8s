set shell := ["bash", "-euo", "pipefail", "-c"]

diagrams:
    ./scripts/render-diagrams.sh

check-diagrams:
    ./scripts/render-diagrams.sh --check
