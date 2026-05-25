#!/usr/bin/env bash
# scripts/agentgate-check-path.sh
#
# Called by Claude Code PreToolUse hooks to enforce path restrictions.
# Reads .agentgate.toml to determine which paths are writable for the
# current agent mode.
#
# Usage: AGENTGATE_MODE=tester ./scripts/agentgate-check-path.sh <file_path>
#
# Exit codes:
#   0 = path is allowed (tool call proceeds)
#   1 = path is denied (tool call blocked)
#
# Environment:
#   AGENTGATE_MODE — required. Must match a mode name in .agentgate.toml
#                    Set this before starting the Claude Code session.

set -euo pipefail

FILE_PATH="${1:-}"
MODE="${AGENTGATE_MODE:-}"

if [ -z "$MODE" ]; then
    # No mode set — allow everything (enforcement not active)
    exit 0
fi

if [ -z "$FILE_PATH" ]; then
    echo "DENY: No file path provided" >&2
    exit 1
fi

# Find .agentgate.toml by walking up from cwd
find_config() {
    local dir="$PWD"
    while [ "$dir" != "/" ]; do
        if [ -f "$dir/.agentgate.toml" ]; then
            echo "$dir/.agentgate.toml"
            return 0
        fi
        dir="$(dirname "$dir")"
    done
    return 1
}

CONFIG_FILE=$(find_config) || {
    # No config file found — allow everything
    exit 0
}

CONFIG_DIR=$(dirname "$CONFIG_FILE")

# Make path relative to config directory
REL_PATH="${FILE_PATH#$CONFIG_DIR/}"
# Also handle absolute paths
if [[ "$REL_PATH" == /* ]]; then
    REL_PATH="${FILE_PATH#/}"
fi

# Parse writable paths for the current mode from .agentgate.toml
# This is a simple parser — handles the format:
#   [modes.tester]
#   writable = ["tests"]
#
# For production, use a proper TOML parser. This handles the experiment.
parse_writable_paths() {
    local mode="$1"
    local config="$2"
    local in_mode=false

    while IFS= read -r line; do
        # Check for mode section header
        if [[ "$line" =~ ^\[modes\."?${mode}"?\] ]] || [[ "$line" =~ ^\[modes\.${mode}\] ]]; then
            in_mode=true
            continue
        fi

        # Check for next section (exit mode)
        if $in_mode && [[ "$line" =~ ^\[.+\] ]]; then
            in_mode=false
            continue
        fi

        # Extract writable paths
        if $in_mode && [[ "$line" =~ ^writable ]]; then
            # Extract array values: writable = ["src", "lib"]
            echo "$line" | grep -oP '"[^"]*"' | tr -d '"'
        fi
    done < "$config"
}

# Get writable paths for current mode
WRITABLE_PATHS=$(parse_writable_paths "$MODE" "$CONFIG_FILE")

if [ -z "$WRITABLE_PATHS" ]; then
    echo "DENY: No writable paths defined for mode '$MODE' in .agentgate.toml" >&2
    exit 1
fi

# Check if the file path starts with any writable path
while IFS= read -r allowed_path; do
    [ -z "$allowed_path" ] && continue

    if [[ "$REL_PATH" == "$allowed_path"/* ]] || [[ "$REL_PATH" == "$allowed_path" ]]; then
        # Path is within an allowed directory
        exit 0
    fi
done <<< "$WRITABLE_PATHS"

# Also allow writing to docs/ (shared by all modes for documentation updates)
if [[ "$REL_PATH" == docs/* ]]; then
    exit 0
fi

# Also allow writing to .llm/ (task tracking)
if [[ "$REL_PATH" == .llm/* ]]; then
    exit 0
fi

# Path not in any writable directory
echo "DENY: Mode '$MODE' cannot write to '$REL_PATH'. Writable paths: $(echo $WRITABLE_PATHS | tr '\n' ', ')" >&2
exit 1
