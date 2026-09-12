# claude-things

A catalogue of Claude Code primitives — skills, commands, agents, prompts, and MCP patterns — grouped by category and asset name so it's easy to browse and reuse.

## Structure

Each top-level folder is a **category**. Inside, each subfolder is a self-contained **asset** that owns all of its Claude Code primitives.

```
claude-things/
├── image-generation/          # Category
│   └── comfyui-prompt/      # Asset
│       ├── README.md          # Human-readable docs
│       ├── SKILL.md           # Claude Code skill
│       ├── command.md         # Slash command
│       ├── workflows/         # Supporting files
│       └── examples/          # Generated outputs (ignored by git)
├── agents/                    # Cross-cutting primitives (placeholder)
├── prompts/
├── mcp/
├── scripts/                   # Helper scripts for installation / sync
│   └── install.sh             # Copy/symlink Claude Code primitives into .claude/
├── tools/                     # Standalone helper tools
│   └── ol/                    # Ollama agent launcher
│       ├── ol                 # The launcher script (keeps itself up to date)
│       ├── install.sh         # Install ol into ~/bin and add it to PATH
│       └── README.md          # Human-readable docs
└── .claude/                   # Active Claude Code files (symlinks into assets)
```

The root `.claude/` directory contains symlinks to the active `SKILL.md`, `command.md`, etc. inside each asset folder. On systems without symlink support, run:

```bash
./scripts/install.sh
```

Then restart Claude Code.

## What's here

| Category | Asset | Description |
|----------|-------|-------------|
| image-generation | [`comfyui-prompt`](image-generation/comfyui-prompt/) | Build and run ComfyUI image-generation prompts from natural language |
| tools | [`ol`](tools/ol/) | Ollama agent launcher that syncs itself from the remote repo |

## Adding a new item

1. Pick or create a category folder, e.g. `image-generation/` or `dev-tools/`.
2. Create an asset subfolder, e.g. `image-generation/my-thing/`.
3. Add the required Claude Code file(s) (`SKILL.md`, `command.md`, `AGENT.md`, etc.) and a human-readable `README.md`.
4. If needed, add a symlink in `.claude/` or run `./scripts/install.sh`.
5. Update the table in this README.

## License

MIT — use, fork, and improve freely.
