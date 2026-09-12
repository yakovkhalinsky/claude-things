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

# Determine the right shell rc file.
RC=""
case "$(basename "${SHELL:-}")" in
  zsh)
    RC="${HOME}/.zshrc"
    ;;
  bash)
    RC="${HOME}/.bashrc"
    ;;
  *)
    # Fallback: prefer .bashrc if it exists, otherwise .zshrc, otherwise .profile.
    if [[ -f "${HOME}/.bashrc" ]]; then
      RC="${HOME}/.bashrc"
    elif [[ -f "${HOME}/.zshrc" ]]; then
      RC="${HOME}/.zshrc"
    elif [[ -f "${HOME}/.profile" ]]; then
      RC="${HOME}/.profile"
    fi
    ;;
esac

if [[ -z "${RC}" ]]; then
  echo "Could not detect a shell rc file. Add this to your PATH manually:"
  echo "  export PATH=\"\${HOME}/bin:\${PATH}\""
  exit 0
fi

if grep -qF '${HOME}/bin' "${RC}" 2>/dev/null || grep -qF "${HOME}/bin" "${RC}" 2>/dev/null; then
  echo "~/bin already appears in ${RC}"
else
  echo "" >> "${RC}"
  echo "# Added by claude-things/tools/ol/install.sh" >> "${RC}"
  echo 'export PATH="${HOME}/bin:${PATH}"' >> "${RC}"
  echo "Added ~/bin to ${RC}"
  echo "Reload your shell or run: source ${RC}"
fi

echo "Done."
