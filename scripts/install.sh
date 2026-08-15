#!/usr/bin/env bash
# Install Claude Code primitives from this repo into .claude/
# Usage: ./scripts/install.sh
# This is only needed on systems where the symlinks in .claude/ don't work
# (e.g. Windows without symlink support).

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "Installing Claude Code primitives from ${ROOT}..."

mkdir -p "${ROOT}/.claude/skills/comfyui-prompt"
mkdir -p "${ROOT}/.claude/commands"

cp "${ROOT}/image-generation/comfyui-prompt/SKILL.md" \
   "${ROOT}/.claude/skills/comfyui-prompt/SKILL.md"

cp "${ROOT}/image-generation/comfyui-prompt/comfyui-prompt.md" \
   "${ROOT}/.claude/commands/comfyui-prompt.md"

cp "${ROOT}/image-generation/comfyui-prompt/command-serve-output.md" \
   "${ROOT}/.claude/commands/comfyui-serve-output.md"

echo "Done. Restart Claude Code if it is already running."
