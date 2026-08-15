# ol

A tiny shortcut for launching Ollama agents.

## Usage

```bash
ol [agent] [model]
```

- `agent` defaults to `claude`
- `model` defaults to the contents of `~/.model`

For the `claude` agent, permissions are skipped automatically via `--dangerously-skip-permissions`.

## Install

```bash
./tools/ol/install.sh
```

This copies `ol` into `~/bin` and adds `~/bin` to your shell PATH if it isn't already there.
