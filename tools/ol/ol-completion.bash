# ol-completion: bash -- sourced from ~/.bashrc; kept in sync by ol
#
# Tab completion for ol: `ol <TAB>` lists integrations, `ol <agent> <TAB>` lists
# models. This file is sourced, never executed: it must not change the shell's
# options, must not print, and must not make Tab wait. Every command below is
# best-effort, every request has a short timeout, every failure is swallowed.
#
# Model candidates are merged from four sources, in the order they are offered:
#   1. ~/.model        the current default, i.e. what a bare `ol` launches
#   2. running models  /api/ps -- the only API path that can surface a cloud model
#                      that was never pulled locally
#   3. ~/.ol-models    models ol has launched before, most recent first
#   4. pulled models   /api/tags
# 2 and 4 go through a short-TTL cache (OL_COMP_TTL seconds, default 60) so a
# remote OLLAMA_HOST cannot make every Tab cost a round trip.
#
# The synced file holds logic only, never lists: the candidates are computed here
# at Tab time, so an out-of-date copy of this file still offers fresh names.
#
# File ownership: ol writes ~/.ol-models; this file writes ~/.ol-completion-cache.
# No file has two writers, so the cache format can never be read by a version of
# this file that did not write it.
#
# Bash 3.2 is still /bin/bash on macOS, so: no associative arrays, no mapfile.

# Integrations to fall back on when ollama cannot be asked, or is not installed.
# Kept in step with `ollama launch`'s list, which is preferred when available and
# also carries the aliases ollama prints in parentheses (chatgpt also answers to
# codex-app, and so on).
_OL_AGENTS_FALLBACK=(
  claude chatgpt codex-app codex-desktop codex-gui hermes openclaw clawdbot
  moltbot opencode codex hermes-desktop copilot copilot-cli omp droid dsh
  deepseek-harness kimi muse muse-code pi pool cline qwen vscode code
)

# Base URL for the Ollama API, accepting OLLAMA_HOST with or without a scheme --
# the same rule ol itself applies, read from the same variable.
_ol_ollama_url() {
  local u="${OLLAMA_HOST:-http://localhost:11434}"
  [[ "$u" == http* ]] || u="http://${u}"
  printf '%s\n' "$u"
}

# Is the cache younger than the TTL? A cache with no readable timestamp counts as
# stale, so a truncated or hand-edited file costs exactly one refresh. The TTL is
# validated before use: a non-numeric OL_COMP_TTL must not reach arithmetic, which
# would print an error at the prompt.
_ol_cache_fresh() {
  local cache="${HOME:-}/.ol-completion-cache" ts="" now="" ttl="${OL_COMP_TTL:-60}"
  [[ "$ttl" =~ ^[0-9]+$ ]] || ttl=60
  [[ -r "$cache" ]] || return 1
  read -r ts <"$cache" 2>/dev/null || return 1
  [[ "$ts" =~ ^[0-9]+$ ]] || return 1
  now="$(date +%s 2>/dev/null)" || return 1
  [[ -n "$now" ]] || return 1
  (( now - ts < ttl ))
}

# Print the cached names for one section: r = models Ollama is running,
# m = models pulled locally.
_ol_section() {
  awk -v k="$1" '$1 == k { print $2 }' "${HOME:-}/.ol-completion-cache" 2>/dev/null || true
  return 0
}

# Refresh the cached sections and stamp them with the current time. The write is
# atomic (rename) and best effort, and it happens even when the API answered
# nothing: an unreachable Ollama must cost one short timeout per TTL, not one per
# Tab. The trade-off is that a recovered Ollama can go unnoticed for up to a TTL,
# which is why the local sources are merged in live instead of being cached.
#
# Two sequential curls rather than --parallel: per-URL -o output mapping did not
# behave predictably with --parallel here, and the worst case without it is short.
_ol_cache_refresh() {
  local home="${HOME:-}" cache="" tmp="" now="" url="" ps_json="" tags_json=""
  local running="" pulled=""
  [[ -n "$home" ]] || return 0
  now="$(date +%s 2>/dev/null || true)"
  # No clock: skip the cache rather than stamp it with something wrong.
  [[ -n "$now" ]] || return 0
  cache="${home}/.ol-completion-cache"
  tmp="${cache}.new.$$"
  url="$(_ol_ollama_url)"

  # -f so a non-2xx (an Ollama without /api/ps) yields nothing, instead of a body
  # we would go on to mis-parse.
  ps_json="$(curl -fsS --connect-timeout 1 --max-time 1 "${url}/api/ps" 2>/dev/null || true)"
  tags_json="$(curl -fsS --connect-timeout 1 --max-time 2 "${url}/api/tags" 2>/dev/null || true)"

  if command -v jq >/dev/null 2>&1; then
    running="$(jq -r '.models[]? | (.name // .model // empty)' <<<"$ps_json" 2>/dev/null || true)"
    pulled="$(jq -r '.models[]? | (.name // .model // empty)' <<<"$tags_json" 2>/dev/null || true)"
  else
    # No jq: the same two fields, pulled out of the raw payload.
    running="$(printf '%s\n' "$ps_json" | grep -oE '"(name|model)" *: *"[^"]*"' 2>/dev/null | sed -e 's/^[^:]*: *"//' -e 's/"$//' || true)"
    pulled="$(printf '%s\n' "$tags_json" | grep -oE '"(name|model)" *: *"[^"]*"' 2>/dev/null | sed -e 's/^[^:]*: *"//' -e 's/"$//' || true)"
  fi

  {
    printf '%s\n' "$now"
    printf '%s\n' "$running" | awk 'NF && !seen[$0]++ { print "r " $0 }'
    printf '%s\n' "$pulled"  | awk 'NF && !seen[$0]++ { print "m " $0 }'
  } >"$tmp" 2>/dev/null || { rm -f -- "$tmp" 2>/dev/null || true; return 0; }
  mv -f -- "$tmp" "$cache" 2>/dev/null || rm -f -- "$tmp" 2>/dev/null || true
  return 0
}

# Integration names, read from Ollama itself so the list follows whatever it
# ships. No cache: this is a local process (~30ms) with no network in it.
_ol_agent_candidates() {
  local agents=""
  if command -v ollama >/dev/null 2>&1; then
    agents="$(ollama launch --help 2>/dev/null | awk '
      /^Supported integrations:/ { f = 1; next }
      f && /^$/ { exit }
      f {
        print $1
        # "(alias: x)" and "(aliases: x, y)". In awk this is ERE, where (?:...) is
        # not a group -- "aliases?: " would mean "aliase" plus an optional "s" and
        # silently drop the singular form.
        if (match($0, /\(alias(es)?: [^)]*\)/)) {
          s = substr($0, RSTART, RLENGTH)
          sub(/^\(alias(es)?: /, "", s)
          sub(/\)$/, "", s)
          gsub(/,/, " ", s)
          n = split(s, a, /[ \t]+/)
          for (i = 1; i <= n; i++) if (a[i] != "") print a[i]
        }
      }' 2>/dev/null || true)"
  fi
  [[ -n "$agents" ]] || agents="$(printf '%s\n' "${_OL_AGENTS_FALLBACK[@]}")"
  printf '%s\n' "$agents"
  return 0
}

# Model names: default, running, learned, pulled -- deduplicated, first seen wins.
_ol_model_candidates() {
  local home="${HOME:-}" m="" seen=""
  {
    if [[ -r "${home}/.model" ]]; then
      read -r m <"${home}/.model" 2>/dev/null || m=""
      [[ -n "$m" ]] && printf '%s\n' "$m"
    fi
    if ! _ol_cache_fresh; then _ol_cache_refresh || true; fi
    _ol_section r
    if [[ -r "${home}/.ol-models" ]]; then
      while IFS= read -r m; do
        [[ -n "$m" ]] && printf '%s\n' "$m"
      done <"${home}/.ol-models"
    fi
    _ol_section m
  } | while IFS= read -r m; do
    [[ -n "$m" ]] || continue
    [[ "$seen" == *"|$m|"* ]] && continue
    seen="$seen|$m|"
    printf '%s\n' "$m"
  done
  return 0
}

# The completion itself.
_ol() {
  local pre="${COMP_LINE:-}" token="" brk="" tail="" pfx="" c=""
  local ends=0 n=0 wordno=0
  local -a toks=() cands=()

  pre="${pre:0:${COMP_POINT:-0}}"

  # Which of ol's arguments is being typed: the number of whitespace-separated
  # words before the cursor, plus one when the cursor sits after whitespace (an
  # argument has just started). COMP_CWORD cannot be used for this: readline splits
  # on every character in COMP_WORDBREAKS and ':' is one of them, so a tagged model
  # name becomes two words and the count runs ahead of the arguments.
  if [[ -n "$pre" ]]; then
    read -r -a toks <<<"$pre" 2>/dev/null || true
  fi
  n=${#toks[@]}
  case "$pre" in ""|*[[:space:]]) ends=1 ;; esac
  wordno=$(( n + ends ))

  # The token under the cursor, split on whitespace only, and the prefix readline
  # already considers complete: everything up to its last word-break character.
  # With the default COMP_WORDBREAKS that turns "deepseek-v4.1-flash:cl" into the
  # complete "deepseek-v4.1-flash:" plus the word readline is completing, "cl".
  # ] - ^ and \ would corrupt the bracket expression below, so they come out first.
  token="${pre##*[[:space:]]}"
  brk="${COMP_WORDBREAKS:-}"
  brk="${brk//]/}"
  brk="${brk//-/}"
  brk="${brk//^/}"
  brk="${brk//\\/}"
  tail="$token"
  if [[ -n "$brk" ]]; then
    tail="${token##*[$brk]}"
    pfx="${token%"$tail"}"
  fi

  case "$wordno" in
    2) while IFS= read -r c; do cands+=("$c"); done < <(_ol_agent_candidates) ;;
    3) while IFS= read -r c; do cands+=("$c"); done < <(_ol_model_candidates) ;;
    # ol takes [agent] [model] and ignores anything else; the command name itself
    # (wordno 1) is bash's business, not ours.
    *) COMPREPLY=(); return 0 ;;
  esac

  # Match on the whole token, but hand readline back only the part after its break
  # prefix: readline replaces just the text after the last break character, so
  # returning a full "deepseek-v4.1-flash:cloud" for a typed "...:cl" would both
  # fail to match ("cl" is not a prefix of it) and, if it did match, insert the
  # prefix twice. When ':' is not a break character, pfx stays empty and full names
  # are exactly right.
  COMPREPLY=()
  for c in "${cands[@]}"; do
    [[ -n "$c" && "$c" == "$token"* ]] || continue
    COMPREPLY+=("${c#"$pfx"}")
  done
  return 0
}

# Register for the command name only -- `ol` is what PATH resolves. nosort keeps
# the order above (the default model first) instead of sorting alphabetically; bash
# before 4.4 rejects it, hence the second form.
complete -o nosort -F _ol ol 2>/dev/null || complete -F _ol ol 2>/dev/null || true
