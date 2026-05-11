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
#   Agents and prompts are linked as whole directories (single symlink).
#   Skills and hooks are linked per-item, so you can have project-local
#   skills (e.g., debug-aws) alongside Jobn-managed ones. Local items
#   are never overwritten.
#
#   Idempotent — safe to run multiple times. Existing symlinks are replaced.
#   Non-symlink directories and files are never overwritten.
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

  # Remove whole-directory symlinks (agents, prompts)
  for dst in "$AGENTS_DST" "$PROMPTS_DST"; do
    if [[ -L "$dst" ]]; then
      rm "$dst"
      echo "  Removed symlink: $dst"
      ((removed++))
    elif [[ -e "$dst" ]]; then
      echo "  Skipped (not a symlink): $dst"
    fi
  done

  # Remove per-item symlinks from skills and hooks
  for dst_dir in "$SKILLS_DST" "$HOOKS_DST"; do
    if [[ -L "$dst_dir" ]]; then
      # Old-style whole-directory symlink
      rm "$dst_dir"
      echo "  Removed symlink: $dst_dir"
      ((removed++))
    elif [[ -d "$dst_dir" ]]; then
      for item in "$dst_dir"/*; do
        if [[ -L "$item" ]]; then
          local_target="$(readlink "$item")"
          if [[ "$local_target" == *"${JOBN_DIR}"* ]]; then
            rm "$item"
            echo "  Removed symlink: $(basename "$item") from $(basename "$dst_dir")/"
            ((removed++))
          fi
        fi
      done
      # Remove the directory if it's now empty
      if [[ -d "$dst_dir" ]] && [[ -z "$(ls -A "$dst_dir")" ]]; then
        rmdir "$dst_dir"
        echo "  Removed empty directory: $dst_dir"
      fi
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

# ── Whole-directory symlink (agents, prompts) ──
# Replaces existing symlinks. Refuses to overwrite real directories.
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

# ── Per-item symlinks (skills, hooks) ──
# Creates the directory if needed. Symlinks each item from source.
# Preserves project-local items (real directories/files).
# If the destination is currently a whole-directory symlink, converts
# it to per-item symlinks automatically.
link_items() {
  local src_dir="$1" dst_dir="$2" label="$3"

  if [[ -L "$dst_dir" ]]; then
    # Convert old whole-directory symlink to per-item
    rm "$dst_dir"
    echo "  Converted ${label} from directory symlink to per-item symlinks"
  fi

  mkdir -p "$dst_dir"

  local linked=0
  local skipped=0
  for item in "$src_dir"/*/; do
    [[ -d "$item" ]] || continue
    local name
    name="$(basename "$item")"
    local dst_item="${dst_dir}/${name}"

    if [[ -L "$dst_item" ]]; then
      rm "$dst_item"
      ln -s "$item" "$dst_item"
      ((linked++))
    elif [[ -d "$dst_item" ]]; then
      # Project-local item — don't touch it
      ((skipped++))
    else
      ln -s "$item" "$dst_item"
      ((linked++))
    fi
  done

  # Also handle files (e.g., hooks are .json files, not directories)
  for item in "$src_dir"/*; do
    [[ -f "$item" ]] || continue
    local name
    name="$(basename "$item")"
    local dst_item="${dst_dir}/${name}"

    if [[ -L "$dst_item" ]]; then
      rm "$dst_item"
      ln -s "$item" "$dst_item"
      ((linked++))
    elif [[ -f "$dst_item" ]]; then
      # Project-local file — don't touch it
      ((skipped++))
    else
      ln -s "$item" "$dst_item"
      ((linked++))
    fi
  done

  echo "  Linked ${linked} ${label} (${skipped} project-local items preserved)"
}

link_dir "$AGENTS_SRC" "$AGENTS_DST" "agents"
link_items "$SKILLS_SRC" "$SKILLS_DST" "skills"

# Hooks — per-item so they merge with rtk or other tools
if [[ -d "$HOOKS_SRC" ]]; then
  link_items "$HOOKS_SRC" "$HOOKS_DST" "hooks"
fi

# Prompts — whole-directory symlink
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
