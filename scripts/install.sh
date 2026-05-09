#!/usr/bin/env bash
#
# install.sh — Symlink Jobn agents and skills into a target project
#
# USAGE
#   ./scripts/install.sh <target-project-path>
#   ./scripts/install.sh --uninstall <target-project-path>
#
# DESCRIPTION
#   Creates symlinks in the target project's .github/ directory pointing
#   back to this Jobn repo's agents and skills. This makes all @agent-name
#   and SKILL.md files available when working in the target project.
#
#   Idempotent — safe to run multiple times. Existing symlinks are replaced.
#   Non-symlink directories are never overwritten.
#
#   For worktrees: git worktrees have independent working trees, so symlinks
#   from the main repo do NOT carry over. Run install.sh on each worktree
#   directory, or let @orchestrator handle it automatically.
#
# PREREQUISITES
#   - Jobn must be cloned to ~/Workspace/Jobn (or wherever this script lives)
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
JOBN_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

UNINSTALL=false
if [[ "${1:-}" == "--uninstall" ]]; then
  UNINSTALL=true
  shift
fi

TARGET="${1:?Usage: install.sh [--uninstall] <target-project-path>}"

# Resolve to absolute path
TARGET="$(cd "$TARGET" && pwd)"

AGENTS_SRC="${JOBN_DIR}/.github/agents"
SKILLS_SRC="${JOBN_DIR}/.github/skills"
HOOKS_SRC="${JOBN_DIR}/.github/hooks"
PROMPTS_SRC="${JOBN_DIR}/.github/prompts"

AGENTS_DST="${TARGET}/.github/agents"
SKILLS_DST="${TARGET}/.github/skills"
HOOKS_DST="${TARGET}/.github/hooks"
PROMPTS_DST="${TARGET}/.github/prompts"

# ──────────────────────────────────────
# Uninstall
# ──────────────────────────────────────
if $UNINSTALL; then
  echo "Uninstalling Jobn from ${TARGET}..."
  removed=0

  for dst in "$AGENTS_DST" "$SKILLS_DST" "$HOOKS_DST" "$PROMPTS_DST"; do
    if [[ -L "$dst" ]]; then
      rm "$dst"
      echo "  Removed symlink: $dst"
      ((removed++))
    elif [[ -e "$dst" ]]; then
      echo "  Skipped (not a symlink): $dst"
    fi
  done

  if [[ $removed -eq 0 ]]; then
    echo "  Nothing to remove."
  else
    echo "Done. Removed ${removed} symlink(s)."
  fi
  exit 0
fi

# ──────────────────────────────────────
# Install
# ──────────────────────────────────────
echo "Installing Jobn into ${TARGET}..."

# Verify source directories exist
for src in "$AGENTS_SRC" "$SKILLS_SRC"; do
  if [[ ! -d "$src" ]]; then
    echo "Error: Source not found: ${src}"
    echo "Is this script being run from the Jobn repo?"
    exit 1
  fi
done

# Create .github/ if needed
mkdir -p "${TARGET}/.github"

# Symlink function — replaces existing symlinks, refuses to overwrite real dirs
link_dir() {
  local src="$1" dst="$2" label="$3"

  if [[ -L "$dst" ]]; then
    rm "$dst"
    echo "  Replaced existing symlink: ${label}"
  elif [[ -d "$dst" ]]; then
    echo "  Error: ${dst} exists and is a real directory (not a symlink)."
    echo "  Remove it manually if you want Jobn to manage ${label}."
    return 1
  fi

  ln -s "$src" "$dst"
  echo "  Linked: ${label} → ${src}"
}

link_dir "$AGENTS_SRC" "$AGENTS_DST" "agents"
link_dir "$SKILLS_SRC" "$SKILLS_DST" "skills"

# Hooks are optional — only link if they exist
if [[ -d "$HOOKS_SRC" ]]; then
  link_dir "$HOOKS_SRC" "$HOOKS_DST" "hooks"
fi

# Prompts — only link if they exist
if [[ -d "$PROMPTS_SRC" ]]; then
  link_dir "$PROMPTS_SRC" "$PROMPTS_DST" "prompts"
fi

# ──────────────────────────────────────
# Scaffold project files (not symlinks — user edits these)
# ──────────────────────────────────────
COPILOT_INSTRUCTIONS="${TARGET}/.github/copilot-instructions.md"
PROJECT_CONTEXT="${TARGET}/.github/PROJECT.md"

scaffold_file() {
  local src="$1" dst="$2" label="$3"

  if [[ -f "$dst" ]]; then
    echo "  Skipped (already exists): ${label}"
  else
    cp "$src" "$dst"
    echo "  Scaffolded: ${label} — edit this file with your project details"
  fi
}

if [[ -f "${JOBN_DIR}/templates/copilot-instructions.md.tmpl" ]]; then
  scaffold_file "${JOBN_DIR}/templates/copilot-instructions.md.tmpl" "$COPILOT_INSTRUCTIONS" "copilot-instructions.md"
fi

if [[ -f "${JOBN_DIR}/templates/PROJECT.md.tmpl" ]]; then
  scaffold_file "${JOBN_DIR}/templates/PROJECT.md.tmpl" "$PROJECT_CONTEXT" "PROJECT.md"
fi

echo ""
echo "Done. Jobn agents and skills are now available in ${TARGET}."
echo "Open the project in VS Code and use @agent-name in Copilot chat."
echo ""
echo "Next steps:"
echo "  1. Edit .github/copilot-instructions.md with your project details"
echo "  2. Edit .github/PROJECT.md with your tech stack and architecture"
echo "  3. Use /review, /ship, /pr slash commands in Copilot chat"
