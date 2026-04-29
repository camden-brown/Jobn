#!/usr/bin/env bash
# setup.sh — Initialize a new job directory with config template
# Usage: ./scripts/setup.sh <job-name>
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
JOB_NAME="${1:?Usage: setup.sh <job-name>}"
JOB_DIR="${REPO_ROOT}/jobs/${JOB_NAME}"

# rtk is required for token-optimized command output
if ! command -v rtk &>/dev/null; then
  echo "Error: rtk is required but not installed."
  echo "  brew install rtk"
  echo "  # or: curl -fsSL https://raw.githubusercontent.com/rtk-ai/rtk/refs/heads/master/install.sh | sh"
  echo ""
  echo "After installing, run: rtk init -g --copilot"
  exit 1
fi

if [[ -d "$JOB_DIR" ]]; then
  echo "Job '${JOB_NAME}' already exists at ${JOB_DIR}"
  exit 1
fi

mkdir -p "${JOB_DIR}/tickets"

cp "${REPO_ROOT}/templates/config.example.yaml" "${JOB_DIR}/config.yaml"

echo "Initialized job '${JOB_NAME}' at ${JOB_DIR}/"
echo ""
echo "Next steps:"
echo "  1. Edit ${JOB_DIR}/config.yaml with your credentials and settings"
echo "  2. Run: ./scripts/pull-tickets.sh ${JOB_NAME}"
echo "  3. Copy ${REPO_ROOT}/templates/instructions.md to ${JOB_DIR}/.instructions.md"
echo "     and customize for your workflow"
