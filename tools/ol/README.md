# ol

A tiny shortcut for launching Ollama agents.

## Usage

```bash
ol [agent] [model]
```

- `agent` defaults to `claude`
- `model` defaults to the contents of `~/.model`

For the `claude` agent, permissions are skipped automatically via `--dangerously-skip-permissions`.

## Keeping itself up to date

The installed `ol` syncs itself on every run against the file published on
`main`, so a machine stays current from what has been pushed — including one with
no checkout at all. If `~/bin/ol` is missing, `ol` creates `~/bin` and installs
itself there:

```
ol: installed ~/bin/ol from https://raw.githubusercontent.com/... (07f6c62)
ol: synced ~/bin/ol from https://raw.githubusercontent.com/... (07f6c62 -> 9c1f32a)
```

- `~/.ol-version` records `<md5>  <source>` for the last sync, so you can see
  which version and which source is installed.
- The comparison is against the **installed file's** hash as well as the record's,
  so a hand-edited `~/bin/ol` gets repaired instead of trusted.
- A fetched candidate must be a non-empty script containing `ollama launch` and
  pass `bash -n` before it may replace the launcher. A bad push is rejected with
  a warning and the installed copy is kept.
- If the fetch fails (offline, moved URL), `ol` falls back to the local checkout
  if there is one, and otherwise keeps the installed copy silently.
- The update is installed with a rename, never an in-place write: bash reads a
  script incrementally, so overwriting a running `ol` can make it execute a
  spliced region.
- There is no re-exec. Updated code takes effect on the **next** run.
- **Changes ship only once they are committed and pushed to `main`.** Uncommitted
  local edits are not the reference and will be replaced in `~/bin` by whatever
  `main` holds — use `OL_SOURCE` while developing.

| Variable | Effect |
| --- | --- |
| `OL_SOURCE` | Use this local file as the reference and never touch the network |
| `OL_REMOTE_URL` | Fetch the reference from here instead (default: the raw `main` URL). Point it at a commit SHA path (`.../<sha>/tools/ol/ol`) to pin a version, or at a fork |
| `OL_TARGET` | Install to this path instead of `~/bin/ol` |
| `OL_NO_UPDATE=1` | Skip the sync entirely |

Be aware that this installs and runs whatever is on `main` on every run, and
that `ol` then launches `claude` with `--dangerously-skip-permissions`. The
`bash -n` and sanity checks blunt accidents such as a truncated or
syntax-broken push, not malice.

## Context window

Claude Code has no catalogue entry for Ollama model names, so it assumes a 200k
context window and prints an "isn't described by this version's model catalog"
warning on every launch. Before starting `claude`, `ol` looks the model up via
`POST /api/show` on the Ollama API and exports `CLAUDE_CODE_MAX_CONTEXT_TOKENS`
with the real window (e.g. 1048576 for `deepseek-v4.1-flash:cloud`):

```
ol: deepseek-v4.1-flash:cloud context window set to 1048576 tokens
```

- The API base URL comes from `OLLAMA_HOST` (a bare `host:port` is accepted too),
  defaulting to `http://localhost:11434`.
- An existing `CLAUDE_CODE_MAX_CONTEXT_TOKENS` is left untouched, so you can set
  it yourself to override.
- If the model reports no window, `ol` says so and Claude Code keeps its 200k
  default; `CLAUDE_CODE_DISABLE_UNKNOWN_MODEL_WINDOW_ENFORCEMENT=1` is the other
  escape hatch.
- `jq` is used when available, with a `grep`-based fallback otherwise.

Note that Claude Code still logs a `[claude-code:unrecognized_model]` line for
models missing from its catalogue; that debug line is unrelated to the context
window.

## Install

```bash
./tools/ol/install.sh
```

This installs `ol` into `~/bin` (via a rename, so it is safe to run while `ol`
is in use), records `~/.ol-version`, and adds `~/bin` to your shell PATH if it
isn't already there. Set `OL_TARGET` to install somewhere else — the PATH setup
is then skipped, since a deliberately chosen directory is not ours to edit rc
files for.

Installing is only needed once: after that `ol` keeps itself current.
