#!/usr/bin/env bash
# Install the ol helper into ~/bin and ensure ~/bin is on PATH.
# Usage: ./tools/ol/install.sh

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET="${HOME}/bin"
SCRIPT="ol"

mkdir -p "${TARGET}"
cp "${ROOT}/${SCRIPT}" "${TARGET}/${SCRIPT}"
chmod +x "${TARGET}/${SCRIPT}"

echo "Installed ${TARGET}/${SCRIPT}"

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
