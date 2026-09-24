#!/usr/bin/env bash
# Install the ol helper into ~/bin and ensure ~/bin is on PATH.
# Usage: ./tools/ol/install.sh

set -euo pipefail

# Canonical, symlink-free paths, so the version record below names the real file.
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
SCRIPT="ol"
TARGET="${OL_TARGET:-${HOME}/bin/${SCRIPT}}"
TARGET_DIR="${TARGET%/*}"
[[ "${TARGET_DIR}" == "${TARGET}" ]] && TARGET_DIR="."

mkdir -p "${TARGET_DIR}"

# Install via a rename rather than an in-place copy: bash reads a script
# incrementally, so writing over a running ol can make it execute a spliced
# region. Swapping a new inode in cannot.
TMP="${TARGET}.new.$$"
cp -- "${ROOT}/${SCRIPT}" "${TMP}"
chmod +x "${TMP}"
mv -f -- "${TMP}" "${TARGET}"

echo "Installed ${TARGET}"

# Seed the version record that ol maintains, so the first run does not report a
# spurious sync. ol re-derives this hash itself; see ol_self_update in the script.
VERSION="${HOME}/.ol-version"

hash_file() {
  local f="$1" out=""
  if command -v md5sum >/dev/null 2>&1; then
    out="$(md5sum <"${f}" 2>/dev/null | awk '{print $1}')" || out=""
  elif command -v md5 >/dev/null 2>&1; then
    out="$(md5 -q "${f}" 2>/dev/null)" || out=""
  elif command -v shasum >/dev/null 2>&1; then
    out="$(shasum -a 256 <"${f}" 2>/dev/null | awk '{print $1}')" || out=""
  elif command -v openssl >/dev/null 2>&1; then
    out="$(openssl dgst -md5 <"${f}" 2>/dev/null)" || out=""
    out="${out##* }"
  fi
  [[ -n "${out}" ]] || return 1
  printf '%s\n' "${out}"
}

# Install the tab-completion file for one shell. It goes into ~ rather than ~/bin:
# it is sourced by an rc file, and a sourced file must not depend on PATH order.
# Installed with the same rename discipline as ol itself, so a shell reading it
# while another install replaces it can never see a spliced copy. There is no
# version record for it: ol keeps it current by hashing the installed file against
# what it fetches, which already detects a hand-edited copy.
COMPLETION_INSTALLED=""

install_completion() {
  local name="$1" src="${ROOT}/${1}" dst="${HOME}/.${1}"
  local tmp="${HOME}/.${1}.new.$$"

  if [[ ! -f "${src}" ]]; then
    echo "No ${name} in ${ROOT}; skipping completion"
    return 0
  fi
  if ! cp -- "${src}" "${tmp}" 2>/dev/null || ! mv -f -- "${tmp}" "${dst}" 2>/dev/null; then
    rm -f -- "${tmp}" 2>/dev/null || true
    echo "Could not install ${dst}; ol will retry on a later run"
    return 0
  fi
  echo "Installed ${dst}"
  COMPLETION_INSTALLED="${dst}"
  return 0
}

H="$(hash_file "${TARGET}")" || H=""
if [[ -n "${H}" ]] && printf '%s  %s\n' "${H}" "${ROOT}/${SCRIPT}" >"${VERSION}.new.$$" 2>/dev/null; then
  mv -f -- "${VERSION}.new.$$" "${VERSION}"
  echo "Recorded ${VERSION}"
else
  rm -f -- "${VERSION}.new.$$" 2>/dev/null || true
  echo "Could not record ${VERSION}; ol will write it on its first run."
fi

# A custom target is not necessarily on PATH, and we should not edit rc files
# for a directory the user chose deliberately.
if [[ "${TARGET_DIR}" != "${HOME}/bin" ]]; then
  echo "Skipping PATH setup: ${TARGET_DIR} is not ~/bin. Make sure it is on PATH."
  echo "Done."
  exit 0
fi

# Determine the right shell rc file, and which shell it belongs to. The completion
# installed below is keyed on the same answer: RC is where lines go, SHELLNAME is
# which completion to install.
RC=""
SHELLNAME=""
case "$(basename "${SHELL:-}")" in
  zsh)
    RC="${HOME}/.zshrc"
    SHELLNAME="zsh"
    ;;
  bash)
    RC="${HOME}/.bashrc"
    SHELLNAME="bash"
    ;;
  *)
    # Fallback: prefer .bashrc if it exists, otherwise .zshrc, otherwise .profile.
    if [[ -f "${HOME}/.bashrc" ]]; then
      RC="${HOME}/.bashrc"
      SHELLNAME="bash"
    elif [[ -f "${HOME}/.zshrc" ]]; then
      RC="${HOME}/.zshrc"
      SHELLNAME="zsh"
    elif [[ -f "${HOME}/.profile" ]]; then
      # .profile is read by POSIX shells, which have no completion system.
      RC="${HOME}/.profile"
      SHELLNAME=""
    fi
    ;;
esac

# Installed before the rc line that sources it, so the file is there by the time a
# shell reads the line. A custom OL_TARGET exited above: those rc edits are skipped
# for a deliberately chosen directory, and a sourced file nobody sources would be
# clutter.
if [[ -n "${SHELLNAME}" ]]; then
  install_completion "ol-completion.${SHELLNAME}"
fi

if [[ -z "${RC}" ]]; then
  echo "Could not detect a shell rc file. Add this to your PATH manually:"
  echo "  export PATH=\"\${HOME}/bin:\${PATH}\""
  if [[ -n "${COMPLETION_INSTALLED}" ]]; then
    echo "Tab completion is installed; add this line to your shell's rc file:"
    echo "  [ -r \"\${HOME}/.ol-completion.${SHELLNAME}\" ] && . \"\${HOME}/.ol-completion.${SHELLNAME}\""
  fi
  exit 0
fi

# The PATH line and the completion line share a comment header but are checked
# separately: an rc file that already exports ~/bin still needs the completion
# line, and re-running this script must not duplicate either.
ADDED_HEADER=0
if grep -qF '${HOME}/bin' "${RC}" 2>/dev/null || grep -qF "${HOME}/bin" "${RC}" 2>/dev/null; then
  echo "~/bin already appears in ${RC}"
else
  echo "" >> "${RC}"
  echo "# Added by claude-things/tools/ol/install.sh" >> "${RC}"
  echo 'export PATH="${HOME}/bin:${PATH}"' >> "${RC}"
  ADDED_HEADER=1
  echo "Added ~/bin to ${RC}"
fi

if [[ -z "${SHELLNAME}" ]]; then
  echo "Could not tell which shell ${RC} belongs to; skipping the tab-completion line."
elif grep -qF "ol-completion.${SHELLNAME}" "${RC}" 2>/dev/null; then
  echo "Tab completion already appears in ${RC}"
elif [[ -z "${COMPLETION_INSTALLED}" ]]; then
  echo "Skipping the tab-completion line: no ${SHELLNAME} completion was installed."
else
  if [[ "${ADDED_HEADER}" == "0" ]]; then
    echo "" >> "${RC}"
    echo "# Added by claude-things/tools/ol/install.sh" >> "${RC}"
  fi
  # Guarded: a missing file must not be an error at shell startup.
  printf '[ -r "${HOME}/.ol-completion.%s" ] && . "${HOME}/.ol-completion.%s"\n' \
    "${SHELLNAME}" "${SHELLNAME}" >> "${RC}"
  echo "Added tab completion to ${RC}"
fi

echo "Reload your shell or run: source ${RC}"
echo "Done."
