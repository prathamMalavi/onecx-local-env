#!/usr/bin/env bash
# Install missing prerequisites for the repository sync workflow on Ubuntu/Debian.
# This script does not run sync-git-repositories.py.
set -Eeuo pipefail

MIN_PYTHON="3.8"

if ! command -v apt-get >/dev/null 2>&1; then
  echo "This setup script supports Ubuntu/Debian systems with apt-get." >&2
  exit 1
fi

SUDO=()
if [[ ${EUID} -ne 0 ]]; then
  if ! command -v sudo >/dev/null 2>&1; then
    echo "Run as root or install sudo to allow apt to install packages." >&2
    exit 1
  fi
  SUDO=(sudo)
fi

APT_UPDATED=0
apt_install() {
  if [[ ${APT_UPDATED} -eq 0 ]]; then
    "${SUDO[@]}" apt-get update
    APT_UPDATED=1
  fi
  "${SUDO[@]}" apt-get install -y "$@"
}

python_is_supported() {
  command -v python3 >/dev/null 2>&1 && python3 -c \
    'import sys; sys.exit(0 if sys.version_info >= (3, 8) else 1)' >/dev/null 2>&1
}

node_is_angular_compatible() {
  command -v node >/dev/null 2>&1 && node -e '
    const [major, minor] = process.versions.node.split(".").map(Number);
    const supported = (major === 20 && minor >= 19) ||
                      (major === 22 && minor >= 12) ||
                      major === 24;
    process.exit(supported ? 0 : 1);
  ' >/dev/null 2>&1
}

if python_is_supported; then
  echo "Python $(python3 --version) is already installed; skipping."
else
  echo "Installing Python 3 (minimum version ${MIN_PYTHON})..."
  apt_install python3
  if ! python_is_supported; then
    echo "The available Python 3 is older than ${MIN_PYTHON}; upgrade the OS package or install a newer Python 3." >&2
    exit 1
  fi
fi

if command -v git >/dev/null 2>&1; then
  echo "Git $(git --version) is already installed; skipping."
else
  echo "Installing Git..."
  apt_install git
fi

if node_is_angular_compatible; then
  echo "Node.js $(node --version) is compatible with Angular 20/21; skipping."
else
  echo "Installing Node.js 22.x (compatible with Angular 20/21)..."
  apt_install ca-certificates curl gnupg
  "${SUDO[@]}" install -d -m 0755 /etc/apt/keyrings
  curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key \
    | "${SUDO[@]}" gpg --dearmor --yes -o /etc/apt/keyrings/nodesource.gpg
  "${SUDO[@]}" chmod a+r /etc/apt/keyrings/nodesource.gpg
  printf 'deb [arch=%s signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_22.x nodistro main\n' \
    "$(dpkg --print-architecture)" \
    | "${SUDO[@]}" tee /etc/apt/sources.list.d/nodesource.list >/dev/null
  APT_UPDATED=0
  apt_install nodejs
  if ! node_is_angular_compatible; then
    echo "Node.js installation completed, but the installed version is not compatible with Angular 20/21." >&2
    exit 1
  fi
fi

if command -v npm >/dev/null 2>&1; then
  echo "npm $(npm --version) is available."
else
  echo "npm was not installed with Node.js; installing Node.js/npm..."
  apt_install nodejs npm
fi

if command -v ng >/dev/null 2>&1; then
  echo "Angular CLI is already installed; skipping."
else
  echo "Installing Angular CLI globally..."
  "${SUDO[@]}" npm install --global @angular/cli
fi

printf '\nDevelopment tools are ready:\n'
python3 --version
git --version
node --version
npm --version
ng version --skip-confirmation
printf '\nNext: run python3 sync-git-repositories.py when you want to commit and push the configured repositories.\n'
