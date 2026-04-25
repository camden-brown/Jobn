#!/usr/bin/env bash
# Guard hook: prevent commits/pushes to protected branches (main, develop, master)
# Receives PreToolUse JSON on stdin, outputs permission decision on stdout.

set -euo pipefail

INPUT=$(cat)

# Extract the tool name and command being run
TOOL_NAME=$(echo "$INPUT" | python3 -c "import sys,json; print(json.load(sys.stdin).get('toolName',''))" 2>/dev/null || echo "")

# Only inspect terminal/execute tools
if [[ "$TOOL_NAME" != "run_in_terminal" && "$TOOL_NAME" != "execute" && "$TOOL_NAME" != "send_to_terminal" ]]; then
  echo '{"decision":"continue"}'
  exit 0
fi

# Extract the command string
COMMAND=$(echo "$INPUT" | python3 -c "
import sys, json
data = json.load(sys.stdin)
params = data.get('toolInput', data.get('input', {}))
print(params.get('command', ''))
" 2>/dev/null || echo "")

# Check for dangerous git operations on protected branches
PROTECTED_BRANCHES="main|master|develop"

# Block: git push to protected branches
if echo "$COMMAND" | grep -qE "git\s+push\s+.*\b($PROTECTED_BRANCHES)\b"; then
  cat <<EOF
{
  "hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "permissionDecision": "deny",
    "permissionDecisionReason": "Blocked: pushing directly to a protected branch (main/master/develop) is not allowed. Push to a feature/bugfix branch instead."
  }
}
EOF
  exit 0
fi

# Block: git commit while on a protected branch (check for checkout to protected branch first)
if echo "$COMMAND" | grep -qE "git\s+checkout\s+($PROTECTED_BRANCHES)\b"; then
  cat <<EOF
{
  "hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "permissionDecision": "ask",
    "permissionDecisionReason": "Warning: switching to a protected branch (main/master/develop). Are you sure?"
  }
}
EOF
  exit 0
fi

# Block: git push --force
if echo "$COMMAND" | grep -qE "git\s+push\s+.*--force"; then
  cat <<EOF
{
  "hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "permissionDecision": "deny",
    "permissionDecisionReason": "Blocked: force pushing is not allowed."
  }
}
EOF
  exit 0
fi

# Block: git reset --hard
if echo "$COMMAND" | grep -qE "git\s+reset\s+--hard"; then
  cat <<EOF
{
  "hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "permissionDecision": "ask",
    "permissionDecisionReason": "Warning: git reset --hard will discard changes. Are you sure?"
  }
}
EOF
  exit 0
fi

# Allow everything else
echo '{"decision":"continue"}'
exit 0
