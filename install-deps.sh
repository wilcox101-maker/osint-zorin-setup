#!/usr/bin/env bash
# install-deps.sh — system packages for osint-zorin-setup (Zorin / Ubuntu apt)
# Safe to re-run. Env: SKIP_PRYINGDEEP, SKIP_SOCIAL_NODE, PYTHON_PREFERRED
set -euo pipefail

PYTHON_PREFERRED="${PYTHON_PREFERRED:-3.12}"
SKIP_PRYINGDEEP="${SKIP_PRYINGDEEP:-0}"
SKIP_SOCIAL_NODE="${SKIP_SOCIAL_NODE:-0}"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
info()  { printf "${GREEN}[+]${NC} %s\n" "$*"; }
warn()  { printf "${YELLOW}[!]${NC} %s\n" "$*"; }
fail()  { printf "${RED}[x]${NC} %s\n" "$*" >&2; exit 1; }

detect_os() {
  if [[ ! -f /etc/os-release ]]; then
    fail "No /etc/os-release — cannot detect OS."
  fi
  # shellcheck disable=SC1091
  . /etc/os-release
  info "Detected: ${NAME:-unknown} (${ID:-unknown} ${VERSION_ID:-})"
  case "${ID_LIKE:-}${ID:-}" in
    *debian*|*ubuntu*|*zorin*)
      ;;
    *)
      warn "Not Zorin/Ubuntu/Debian-family; continuing only if apt works."
      ;;
  esac
  command -v apt-get >/dev/null 2>&1 || fail "apt-get required (Debian/Ubuntu/Zorin)."
}

apt_install() {
  local pkgs=("$@") missing=()
  for p in "${pkgs[@]}"; do
    dpkg -s "$p" >/dev/null 2>&1 || missing+=("$p")
  done
  if ((${#missing[@]})); then
    info "Installing packages: ${missing[*]}"
    sudo DEBIAN_FRONTEND=noninteractive apt-get update -y
    sudo DEBIAN_FRONTEND=noninteractive apt-get install -y "${missing[@]}"
  else
    info "System packages already present: ${pkgs[*]}"
  fi
}

py_ver() {
  "$1" -c 'import sys; print("%d.%d" % sys.version_info[:2])' 2>/dev/null || true
}

ensure_python() {
  local sys_ver pref="python${PYTHON_PREFERRED}" need_pref=0
  sys_ver="$(py_ver python3)"
  info "System python3 is ${sys_ver:-unknown}"
  if [[ -n "$sys_ver" ]]; then
    local major="${sys_ver%%.*}" minor="${sys_ver#*.}"
    if (( major > 3 || (major == 3 && minor >= 13) )); then
      need_pref=1
    fi
  fi
  if command -v "$pref" >/dev/null 2>&1; then
    PYTHON_BIN="$pref"
  elif (( need_pref )); then
    info "Installing Python ${PYTHON_PREFERRED} via deadsnakes"
    apt_install software-properties-common
    if ! grep -qr deadsnakes /etc/apt/sources.list /etc/apt/sources.list.d 2>/dev/null; then
      sudo add-apt-repository -y ppa:deadsnakes/ppa
      sudo DEBIAN_FRONTEND=noninteractive apt-get update -y
    fi
    apt_install "python${PYTHON_PREFERRED}" "python${PYTHON_PREFERRED}-venv" "python${PYTHON_PREFERRED}-dev" \
      || fail "Could not install python${PYTHON_PREFERRED}"
    PYTHON_BIN="$pref"
  else
    PYTHON_BIN="python3"
  fi
  info "Using $PYTHON_BIN ($(py_ver "$PYTHON_BIN")) for tool venvs"
}

install_osint_deps() {
  detect_os
  command -v sudo >/dev/null 2>&1 || fail "sudo required"
  apt_install \
    git curl ca-certificates build-essential pkg-config \
    python3 python3-venv python3-pip python3-dev \
    libxml2-dev libxslt1-dev libffi-dev libssl-dev \
    zlib1g-dev libjpeg-dev
  ensure_python
  if [[ "$SKIP_SOCIAL_NODE" != "1" ]]; then
    if ! command -v node >/dev/null 2>&1 || [[ "$(node -v | sed 's/v//;s/\..*//')" -lt 18 ]]; then
      curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
      apt_install nodejs
    fi
    apt_install firefox-esr tesseract-ocr tesseract-ocr-eng 2>/dev/null \
      || apt_install firefox tesseract-ocr tesseract-ocr-eng \
      || warn "Firefox/tesseract skipped"
  fi
  if [[ "$SKIP_PRYINGDEEP" != "1" ]]; then
    command -v go >/dev/null 2>&1 || apt_install golang-go
  fi
}

# Run when executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  install_osint_deps
  info "Deps done. PYTHON_BIN=${PYTHON_BIN:-unset}"
fi
