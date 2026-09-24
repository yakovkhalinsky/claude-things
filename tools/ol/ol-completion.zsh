# ol-completion: zsh -- sourced from ~/.zshrc; kept in sync by ol
#
# Tab completion for ol: `ol <TAB>` lists integrations, `ol <agent> <TAB>` lists
# models. Sourced, never executed; every command here is best-effort and silent.
# The candidate sources and the cache are described at length in
# ol-completion.bash, and the helpers between here and `_ol` are the same code,
# copied rather than shared so that either file can be sourced on its own.
#
# NOTE: written against zsh's completion system but NOT exercised -- the machine
# this was developed on has no zsh. See the README.

# Integrations to fall back on when ollama cannot be asked, or is not installed.
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
_ol_cache_refresh() {
  local home="${HOME:-}" cache="" tmp="" now="" url="" ps_json="" tags_json=""
  local running="" pulled=""
  [[ -n "$home" ]] || return 0
  now="$(date +%s 2>/dev/null || true)"
  [[ -n "$now" ]] || return 0
  cache="${home}/.ol-completion-cache"
  tmp="${cache}.new.$$"
  url="$(_ol_ollama_url)"

  ps_json="$(curl -fsS --connect-timeout 1 --max-time 1 "${url}/api/ps" 2>/dev/null || true)"
  tags_json="$(curl -fsS --connect-timeout 1 --max-time 2 "${url}/api/tags" 2>/dev/null || true)"

  if command -v jq >/dev/null 2>&1; then
    running="$(jq -r '.models[]? | (.name // .model // empty)' <<<"$ps_json" 2>/dev/null || true)"
    pulled="$(jq -r '.models[]? | (.name // .model // empty)' <<<"$tags_json" 2>/dev/null || true)"
  else
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

# Integration names, read from Ollama itself. No cache: a local process (~30ms)
# with no network in it. "alias:" and "aliases:" both appear in the help output.
_ol_agent_candidates() {
  local agents=""
  if command -v ollama >/dev/null 2>&1; then
    agents="$(ollama launch --help 2>/dev/null | awk '
      /^Supported integrations:/ { f = 1; next }
      f && /^$/ { exit }
      f {
        print $1
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

# Offer candidates, accounting for the text zsh has already taken as fixed.
#
# zsh splits completion words on characters outside WORDCHARS, and ':' is not one
# of them, so a tagged model name is expected to arrive here with the "name:" part
# in IPREFIX and only "cl" in PREFIX -- the same split bash makes, by a different
# route. compadd inserts a match in place of PREFIX and keeps IPREFIX, so handing
# back a whole "deepseek-v4.1-flash:cloud" would insert the prefix twice. A
# candidate is therefore accepted only if it continues IPREFIX+PREFIX, and is
# offered with IPREFIX stripped. If zsh did not split, IPREFIX is empty and this is
# exactly "offer the full name".
#
# compadd rather than _describe: _describe reads "name:description" and would cut
# a tagged model name at its colon.
_ol_offer() {
  local -a out
  local c p typed
  p="${IPREFIX}"
  typed="${IPREFIX}${PREFIX}"
  for c in "$@"; do
    [[ -n "$c" && "$c" == "$typed"* ]] || continue
    out+=( "${c#"$p"}" )
  done
  (( ${#out} )) && compadd -a out
  return 0
}

_ol() {
  emulate -L zsh
  local -a cands

  # CURRENT counts the command as word 1, so 2 is ol's first argument (the
  # integration) and 3 its second (the model).
  case "$CURRENT" in
    2)
      cands=( ${(f)"$(_ol_agent_candidates)"} )
      _ol_offer "${cands[@]}"
      ;;
    3)
      cands=( ${(f)"$(_ol_model_candidates)"} )
      _ol_offer "${cands[@]}"
      ;;
    *)
      # ol takes [agent] [model]; say so rather than falling back to whatever
      # default completion applies to a third argument.
      (( $+functions[_message] )) && _message 'ol takes [agent] [model]'
      ;;
  esac
  return 0
}

# Register with the completion system. compdef before compinit is silently lost,
# so test for _comps -- it exists only once compinit has run. install.sh appends
# its source line to the end of .zshrc, by which point compinit has normally run;
# the precmd hook is for the rc files that source this earlier.
if (( ${+_comps} )); then
  compdef _ol ol
else
  autoload -Uz add-zsh-hook 2>/dev/null
  _ol_autoregister() {
    (( ${+_comps} )) || return 0
    compdef _ol ol
    add-zsh-hook -d precmd _ol_autoregister 2>/dev/null
    unfunction _ol_autoregister 2>/dev/null
  }
  # add-zsh-hook refuses to add the same function twice, so re-sourcing is safe.
  add-zsh-hook precmd _ol_autoregister 2>/dev/null || true
fi
