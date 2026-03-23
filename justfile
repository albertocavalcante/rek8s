set shell := ["bash", "-euo", "pipefail", "-c"]

default:
    @just --list

setup:
    @command -v lefthook >/dev/null 2>&1 || { echo "lefthook not installed; install with: brew install lefthook"; exit 1; }
    lefthook install

install-dev-tools:
    ./scripts/install-dev-tools.sh

check-dev-tools:
    ./scripts/install-dev-tools.sh --check

install-hooks:
    @command -v lefthook >/dev/null 2>&1 || { echo "lefthook not installed; install with: brew install lefthook"; exit 1; }
    lefthook install

pre-commit:
    lefthook run pre-commit

dev-tools:
    ./scripts/install-dev-tools.sh --print

tf-fmt:
    terraform fmt -recursive examples/terraform

tf-fmt-check:
    terraform fmt -check -recursive -diff examples/terraform

tf-validate:
    ./scripts/validate-terraform.sh

tf-lint:
    @command -v tflint >/dev/null 2>&1 || { echo "tflint not installed; install with: brew install tflint"; exit 1; }
    ./scripts/lint-terraform.sh

lint-yaml:
    @command -v yamllint >/dev/null 2>&1 || { echo "yamllint not installed; install with: brew install yamllint"; exit 1; }
    yamllint -c tools/lint/yamllint.yml .

lint-actions:
    @command -v actionlint >/dev/null 2>&1 || { echo "actionlint not installed; install with: brew install actionlint shellcheck"; exit 1; }
    actionlint -config-file tools/lint/actionlint.yml

lint:
    terraform fmt -check -recursive -diff examples/terraform
    ./scripts/validate-terraform.sh
    @if command -v tflint >/dev/null 2>&1; then \
      ./scripts/lint-terraform.sh; \
    else \
      echo "Skipping tflint (install with: brew install tflint)"; \
    fi
    @if command -v yamllint >/dev/null 2>&1; then \
      yamllint -c tools/lint/yamllint.yml .; \
    else \
      echo "Skipping yamllint (install with: brew install yamllint)"; \
    fi
    @if command -v actionlint >/dev/null 2>&1; then \
      actionlint -config-file tools/lint/actionlint.yml; \
    else \
      echo "Skipping actionlint (install with: brew install actionlint shellcheck)"; \
    fi

diagrams:
    ./scripts/render-diagrams.sh

check-diagrams:
    ./scripts/render-diagrams.sh --check
