# ol

A tiny shortcut for launching Ollama agents.

## Usage

```bash
ol [agent] [model] [--] [agent args...]
```

- `agent` defaults to `claude`
- `model` defaults to the contents of `~/.model` (an empty `""` also means "use `~/.model`")
- everything after `--`, or from the first argument starting with `-` once the
  agent is known, is passed to the agent unchanged

```bash
ol                                   # claude, model from ~/.model, interactive
ol codex                             # another integration
ol claude gpt-oss:20b                # pick the model
ol claude -- -p "brief" --output-format json --allowedTools Read "Bash(ls:*)"
ol claude gpt-oss:20b -p "$(cat brief.md)" --output-format json
```

`ol` runs `exec ollama launch <agent> [--model <model>] -y [-- <args>]`: no
`eval`, so arguments with spaces, quotes or `$(...)` arrive as single, literal
arguments, and the agent's exit status is `ol`'s exit status.

### Permissions

`--dangerously-skip-permissions` is only ever added for `claude`:

| Situation | Skip permissions? |
| --- | --- |
| Interactive launch: stdin is a terminal and no arguments are passed through | **yes** (the old default) |
| Any pass-through arguments (`ol claude -- -p ...`) | no |
| stdin is not a terminal (pipe, `< /dev/null`, cron, tmux with redirected stdin) | no |
| `OL_SKIP_PERMISSIONS=1` | yes, always (claude only) |
| `OL_SKIP_PERMISSIONS=0` | no, never |

Headless runs therefore get Claude Code's normal permission handling, so
`--allowedTools`, `--disallowedTools` and `--permission-mode` mean what they say,
and a tool that needs approval shows up in the JSON result's
`permission_denials` instead of running. Any other value of
`OL_SKIP_PERMISSIONS` is reported and treated as "don't skip".

## Tab completion

`ol` ships tab completion for bash and zsh: `ol <TAB>` completes the integration,
`ol <agent> <TAB>` completes model names.

```
ol <TAB>          # claude, chatgpt, codex-app, opencode, ...
ol claude <TAB>   # deepseek-v4.1-flash:cloud, gpt-oss:20b, ...
```

Integrations are read from `ollama launch --help`, so the list follows whatever
Ollama ships, aliases included, with a built-in list as the fallback when `ollama`
is not installed. Models merge four sources, in the order they are offered:

1. `~/.model` — the current default, i.e. what a bare `ol` launches
2. models Ollama is **running** right now (`/api/ps`)
3. `~/.ol-models` — models `ol` has launched before, most recent first
4. models **pulled** locally (`/api/tags`)

Sources 1 and 3 are local, which is what makes a cloud model completable at all:
`/api/tags` lists nothing unless a model was pulled, and `/api/ps` only ever shows
what is running. `ol` records each model it launches in `~/.ol-models`
(deduplicated, capped at 50, written via a rename) *before* launching, so a session
started in one terminal can be completed in another while it runs. A mistyped model
is remembered too; delete the file to forget.

`/api/ps` and `/api/tags` answers are cached in `~/.ol-completion-cache` for
`OL_COMP_TTL` seconds (default 60). With `OLLAMA_HOST` pointing at a remote Ollama,
a round trip on every Tab would be felt, so the cache is deliberate; a *failed*
lookup is cached too, which means a dead host costs at most one short timeout per
TTL. Delete the file to force a refresh. Completion never prints: every request has
a short timeout, every failure is swallowed, and a Tab with no answer still offers
the local candidates.

| Variable | Effect |
| --- | --- |
| `OL_COMP_TTL` | Seconds a cached `/api/ps` + `/api/tags` answer stays fresh (default 60) |
| `OL_COMPLETION_SYNC=1` | Re-fetch the completion file even when it is unchanged |

The completion is wired up only for the default `~/bin` install: a custom
`OL_TARGET` skips the rc edits, and so does this. `ol` never edits a shell rc file
— the sourcing line, guarded so a missing file is not an error, is `install.sh`'s:

```bash
[ -r "${HOME}/.ol-completion.bash" ] && . "${HOME}/.ol-completion.bash"
```

The bash completion carries one piece of readline folklore worth knowing: with the
default `COMP_WORDBREAKS`, `:` is a word-break character, so readline sees
`deepseek-v4.1-flash:cl` as the complete prefix `deepseek-v4.1-flash:` plus the word
`cl`. The completion replies with the remainder only (`cloud`), because readline
replaces only the part after its last break character. zsh needs the same treatment
by a different route, since `:` is not in `WORDCHARS`.

**The zsh completion has had less exercise than the bash one**: it was developed on
a machine with no zsh installed, so it is written to the standard pattern but not
keystroke-tested.

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
- The shell completion is synced on the same schedule: when `ol` is installed or
  updated, or when the completion file is missing. Never on every run — the steady
  state is one file test and no network. A push that changes *only* the completion
  file is therefore not picked up until `ol` itself next changes; set
  `OL_COMPLETION_SYNC=1` for that run, or re-run `install.sh`. The *lists* never go
  stale either way: they are computed at Tab time, not stored in the synced file.

| Variable | Effect |
| --- | --- |
| `OL_SOURCE` | Use this local file as the reference and never touch the network |
| `OL_REMOTE_URL` | Fetch the reference from here instead (default: the raw `main` URL). Point it at a commit SHA path (`.../<sha>/tools/ol/ol`) to pin a version, or at a fork. The completion is fetched from beside it, so this pins both |
| `OL_TARGET` | Install to this path instead of `~/bin/ol` |
| `OL_NO_UPDATE=1` | Skip the sync entirely, the completion included |
| `OL_COMPLETION_SYNC=1` | Sync the completion even when `ol` itself is unchanged |
| `OL_SKIP_PERMISSIONS=0\|1` | Force `--dangerously-skip-permissions` off or on for `claude` (see [Permissions](#permissions)) |

Be aware that this installs and runs whatever is on `main` on every run, and
that an interactive `ol` then launches `claude` with `--dangerously-skip-permissions`. The
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
is in use), records `~/.ol-version`, installs the completion file for your shell
and adds a guarded line sourcing it, and adds `~/bin` to your shell PATH if it
isn't already there. Set `OL_TARGET` to install somewhere else — the PATH setup
and the completion are then skipped, since a deliberately chosen directory is not
ours to edit rc files for.

Re-run it once on a machine that installed `ol` before completion existed: `ol`
keeps a completion file current, but it will not add the rc line that sources it.

Installing is only needed once: after that `ol` keeps itself current.
