#!/usr/bin/env bash
# scripts/build-agents.sh
#
# Assembles agent files for both Copilot and Claude Code from shared parts.
#
# Structure:
#   agents/frontmatter/copilot-{role}.yml    — Copilot YAML frontmatter
#   agents/frontmatter/claude-{role}.yml     — Claude Code YAML frontmatter
#   agents/enforcement/{role}-enforcement.md — Path restriction preamble
#   agents/body/{role}-body.md               — Main agent instructions (shared)
#
# Output:
#   .github/agents/{role}.agent.md           — Copilot agent files
#   .claude/agents/{role}.md                 — Claude Code agent files
#
# Usage:
#   ./scripts/build-agents.sh
#   ./scripts/build-agents.sh tester   # Build only tester
#   ./scripts/build-agents.sh coder    # Build only coder

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

AGENTS_DIR="$REPO_ROOT/agents"
COPILOT_OUT="$REPO_ROOT/.github/agents"
CLAUDE_OUT="$REPO_ROOT/.claude/agents"

ROLES="${1:-tester coder}"

mkdir -p "$COPILOT_OUT" "$CLAUDE_OUT"

for role in $ROLES; do
    echo "Building agent: $role"

    # Validate all parts exist
    for part in \
        "$AGENTS_DIR/frontmatter/copilot-${role}.yml" \
        "$AGENTS_DIR/frontmatter/claude-${role}.yml" \
        "$AGENTS_DIR/enforcement/${role}-enforcement.md" \
        "$AGENTS_DIR/body/${role}-body.md"; do
        if [ ! -f "$part" ]; then
            echo "  ERROR: Missing $part"
            exit 1
        fi
    done

    # Build Copilot agent file
    COPILOT_FILE="$COPILOT_OUT/${role}.agent.md"
    cat "$AGENTS_DIR/frontmatter/copilot-${role}.yml" > "$COPILOT_FILE"
    echo "" >> "$COPILOT_FILE"
    cat "$AGENTS_DIR/enforcement/${role}-enforcement.md" >> "$COPILOT_FILE"
    echo "" >> "$COPILOT_FILE"
    cat "$AGENTS_DIR/body/${role}-body.md" >> "$COPILOT_FILE"
    echo "  → $COPILOT_FILE"

    # Build Claude Code agent file
    CLAUDE_FILE="$CLAUDE_OUT/${role}.md"
    cat "$AGENTS_DIR/frontmatter/claude-${role}.yml" > "$CLAUDE_FILE"
    echo "" >> "$COPILOT_FILE"
    cat "$AGENTS_DIR/enforcement/${role}-enforcement.md" >> "$CLAUDE_FILE"
    echo "" >> "$CLAUDE_FILE"
    cat "$AGENTS_DIR/body/${role}-body.md" >> "$CLAUDE_FILE"
    echo "  → $CLAUDE_FILE"
done

echo ""
echo "Done. Agent files built for: $ROLES"
echo ""
echo "Next steps:"
echo "  1. Set git hooks path:  git config core.hooksPath .githooks"
echo "  2. Make hooks executable: chmod +x .githooks/pre-commit scripts/agentgate-check-path.sh"
echo "  3. Set mode before starting agent session: export AGENTGATE_MODE=tester"
