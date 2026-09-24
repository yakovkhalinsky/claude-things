#!/usr/bin/env bash
# Drive the bash completion without an interactive shell: set COMP_LINE and
# COMP_POINT, call _ol, and inspect COMPREPLY exactly as readline would. _ol reads
# only those two plus COMP_WORDBREAKS, so nothing else has to be faked.
#
# The candidate sources are replaced with fixed lists, so the assertions are about
# the word splitting and the merge -- the parts that can actually break -- and not
# about what happens to be installed or running on this machine.
#
# Usage: ./tools/ol/test-completion.sh [path-to-ol-completion.bash]

set -o pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
# shellcheck source=/dev/null
. "${1:-${HERE}/ol-completion.bash}"

_ol_agent_candidates() { printf '%s\n' claude chatgpt codex-app omp openclaw; }
_ol_model_candidates() {
  printf '%s\n' deepseek-v4.1-flash:cloud deepseek-v4.1-flash:local claude-3:cloud
}

fails=0

# tab "<full line>" [expected COMPREPLY entries...]
tab() {
  local line="$1" want="" got=""
  shift
  want="$*"
  COMP_LINE="$line"
  COMP_POINT=${#line}
  COMPREPLY=()
  _ol
  (( ${#COMPREPLY[@]} )) && got="${COMPREPLY[*]}"
  if [[ "$got" == "$want" ]]; then
    printf 'ok   %-46s -> [%s]\n' "$line" "$got"
  else
    printf 'FAIL %-46s -> [%s] want [%s]\n' "$line" "$got" "$want"
    fails=$(( fails + 1 ))
  fi
}

check() { # check <label> <got> <want>
  if [[ "$2" == "$3" ]]; then
    printf 'ok   %-46s -> [%s]\n' "$1" "$2"
  else
    printf 'FAIL %-46s -> [%s] want [%s]\n' "$1" "$2" "$3"
    fails=$(( fails + 1 ))
  fi
}

echo "== default COMP_WORDBREAKS (contains ':') =="
tab "ol "                                claude chatgpt codex-app omp openclaw
tab "ol cl"                              claude
tab "ol c"                               claude chatgpt codex-app
tab "ol claude "                         deepseek-v4.1-flash:cloud deepseek-v4.1-flash:local claude-3:cloud
tab "ol claude deep"                     deepseek-v4.1-flash:cloud deepseek-v4.1-flash:local
tab "ol claude deepseek-v4.1-flash:cl"   cloud
tab "ol claude deepseek-v4.1-flash:"     cloud local
tab "ol claude claude-3:"                cloud
tab "ol claude deepseek-v4.1-flash:cloud "   # arg 3: nothing
tab "ol"                                     # command position: nothing
tab "ol chatgpt codex"                       # an alias completes at arg 1, not as a model
tab "ol claude gpt"                          # no such model
check "agents are not offered as models" "$(COMP_LINE='ol claude '; COMP_POINT=10; COMPREPLY=(); _ol; printf '%s' "${COMPREPLY[*]}")" \
      "deepseek-v4.1-flash:cloud deepseek-v4.1-flash:local claude-3:cloud"

echo
echo "== COMP_WORDBREAKS without ':' =="
saved="${COMP_WORDBREAKS:-}"
COMP_WORDBREAKS="${COMP_WORDBREAKS//:}"
tab "ol claude deepseek-v4.1-flash:cl"   deepseek-v4.1-flash:cloud
tab "ol claude deep"                     deepseek-v4.1-flash:cloud deepseek-v4.1-flash:local
COMP_WORDBREAKS="$saved"

echo
if complete -p ol 2>/dev/null | grep -q -- '-F _ol ol'; then
  echo "ok   registered for ol"
else
  echo "FAIL not registered for ol"
  fails=$(( fails + 1 ))
fi

echo
if (( fails == 0 )); then
  echo "all completion tests passed"
else
  echo "${fails} test(s) FAILED"
fi
exit "$(( fails > 0 ))"
