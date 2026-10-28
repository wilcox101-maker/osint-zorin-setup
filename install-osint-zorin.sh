#!/usr/bin/env bash
# install-osint-zorin.sh — idempotent OSINT installer for Zorin OS / Ubuntu
# Run on Zorin (or Ubuntu):  bash install-osint-zorin.sh
# Optional: SKIP_PRYINGDEEP=1  SKIP_SOCIAL_NODE=1  INSTALL_ROOT=~/osint
#           PYTHON_PREFERRED=3.12  GITHUB_OWNER=wilcox101-maker
# Wrapper bodies stay single-quoted so $VENV_DIR and "$@" expand at runtime.
# shellcheck disable=SC2016
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OWNER="${GITHUB_OWNER:-wilcox101-maker}"
INSTALL_ROOT="${INSTALL_ROOT:-$HOME/osint}"
BIN_DIR="$INSTALL_ROOT/bin"
TOOLS_DIR="$INSTALL_ROOT/tools"
VENV_DIR="$INSTALL_ROOT/venvs"
LOG_DIR="$INSTALL_ROOT/logs"
SKIP_PRYINGDEEP="${SKIP_PRYINGDEEP:-0}"
SKIP_SOCIAL_NODE="${SKIP_SOCIAL_NODE:-0}"

# shellcheck source=install-deps.sh
source "$SCRIPT_DIR/install-deps.sh"

need_cmd() { command -v "$1" >/dev/null 2>&1 || fail "Missing required command: $1"; }

clone_or_update() {
  local repo="$1"
  local dest="$TOOLS_DIR/$repo"
  if [[ -d "$dest/.git" ]]; then
    info "Updating $repo"
    git -C "$dest" pull --ff-only || warn "Could not fast-forward $repo; leaving as-is."
  else
    info "Cloning $OWNER/$repo"
    git clone --depth 1 "https://github.com/${OWNER}/${repo}.git" "$dest"
  fi
}

make_venv() {
  local name="$1"
  local venv="$VENV_DIR/$name"
  local recreate=0
  if [[ -d "$venv" ]]; then
    local cur
    cur="$("$venv/bin/python" -c 'import sys; print("%d.%d"%sys.version_info[:2])' 2>/dev/null || echo missing)"
    local want
    want="$(py_ver "$PYTHON_BIN")"
    if [[ "$cur" != "$want" ]]; then
      warn "Recreating venv $name ($cur → $want)"
      recreate=1
    fi
  else
    recreate=1
  fi
  if (( recreate )); then
    rm -rf "$venv"
    info "Creating venv: $name with $PYTHON_BIN"
    "$PYTHON_BIN" -m venv "$venv"
  fi
  # shellcheck disable=SC1091
  source "$venv/bin/activate"
  python -m pip install --upgrade pip wheel setuptools >/dev/null
}

write_wrapper() {
  local name="$1"
  local body="$2"
  local path="$BIN_DIR/$name"
  cat > "$path" <<WRAP
#!/usr/bin/env bash
set -euo pipefail
INSTALL_ROOT="${INSTALL_ROOT}"
TOOLS_DIR="${TOOLS_DIR}"
VENV_DIR="${VENV_DIR}"
${body}
WRAP
  chmod +x "$path"
}

# --- layout ---
mkdir -p "$BIN_DIR" "$TOOLS_DIR" "$VENV_DIR" "$LOG_DIR" "$INSTALL_ROOT/output"
install_osint_deps
[[ -n "${PYTHON_BIN:-}" ]] || fail "PYTHON_BIN was not set by install-deps.sh"
need_cmd git

# ---------- blackbird ----------
clone_or_update blackbird
make_venv blackbird
pip install -r "$TOOLS_DIR/blackbird/requirements.txt"
deactivate
write_wrapper blackbird '
source "$VENV_DIR/blackbird/bin/activate"
cd "$TOOLS_DIR/blackbird"
exec python blackbird.py "$@"
'

# ---------- holehe ----------
clone_or_update holehe
make_venv holehe
pip install "$TOOLS_DIR/holehe"
# facebook (and others) import requests; not always declared in setup
pip install requests
deactivate
write_wrapper holehe '
source "$VENV_DIR/holehe/bin/activate"
exec holehe "$@"
'
write_wrapper holehe-used '
source "$VENV_DIR/holehe/bin/activate"
exec holehe --only-used --no-clear "$@"
'

# ---------- CrossLinked ----------
clone_or_update CrossLinked
make_venv crosslinked
pip install "$TOOLS_DIR/CrossLinked"
deactivate
write_wrapper crosslinked '
source "$VENV_DIR/crosslinked/bin/activate"
exec crosslinked "$@"
'
# Also expose the raw module name some docs use
write_wrapper CrossLinked '
source "$VENV_DIR/crosslinked/bin/activate"
if command -v crosslinked >/dev/null 2>&1; then
  exec crosslinked "$@"
fi
exec python "$TOOLS_DIR/CrossLinked/crosslinked.py" "$@"
'

# ---------- metagoofil (legacy; deps vendored) ----------
clone_or_update metagoofil
make_venv metagoofil
# Old tree ships its own libs; ensure requests/beautifulsoup for Google query bits if needed
pip install requests beautifulsoup4 lxml || true
deactivate
write_wrapper metagoofil '
source "$VENV_DIR/metagoofil/bin/activate"
cd "$TOOLS_DIR/metagoofil"
# Prefer python3; fall back if script is py2-only
if python -c "import ast; ast.parse(open(\"metagoofil.py\").read())" 2>/dev/null; then
  exec python metagoofil.py "$@"
fi
warn_py() { echo "metagoofil.py may need Python 2 syntax fixes on this tree." >&2; }
warn_py
exec python metagoofil.py "$@"
'

# ---------- spiderfoot ----------
clone_or_update spiderfoot
make_venv spiderfoot
pip install -r "$TOOLS_DIR/spiderfoot/requirements.txt"
deactivate
write_wrapper spiderfoot '
source "$VENV_DIR/spiderfoot/bin/activate"
cd "$TOOLS_DIR/spiderfoot"
# Bind localhost so a browser on this machine can open the UI
HOST="${SF_HOST:-127.0.0.1}"
PORT="${SF_PORT:-5001}"
if [[ "${1:-}" == "cli" ]]; then
  shift
  exec python ./sf.py "$@"
fi
echo "SpiderFoot UI → http://${HOST}:${PORT}  (open in your browser)"
exec python ./sf.py -l "${HOST}:${PORT}" "$@"
'
write_wrapper spiderfoot-cli '
source "$VENV_DIR/spiderfoot/bin/activate"
cd "$TOOLS_DIR/spiderfoot"
exec python ./sfcli.py "$@"
'

# ---------- social-analyzer ----------
clone_or_update social-analyzer
if [[ "$SKIP_SOCIAL_NODE" != "1" ]] && command -v npm >/dev/null 2>&1; then
  info "Installing social-analyzer (Node)"
  (
    cd "$TOOLS_DIR/social-analyzer"
    npm install --omit=dev
  )
  write_wrapper social-analyzer '
cd "$TOOLS_DIR/social-analyzer"
if [[ "${1:-}" == "web" ]]; then
  shift
  echo "Social Analyzer web → http://127.0.0.1:9005/app.html"
  exec npm start "$@"
fi
if [[ "${1:-}" == "--" ]]; then shift; fi
exec nodejs app.js "$@"
'
  write_wrapper social-analyzer-web '
cd "$TOOLS_DIR/social-analyzer"
echo "Social Analyzer web → http://127.0.0.1:9005/app.html"
exec npm start
'
else
  warn "Skipping Node social-analyzer; installing Python package instead."
  make_venv social-analyzer
  pip install social-analyzer
  deactivate
  write_wrapper social-analyzer '
source "$VENV_DIR/social-analyzer/bin/activate"
exec python -m social-analyzer "$@"
'
fi

# ---------- pryingdeep (optional / heavier) ----------
if [[ "$SKIP_PRYINGDEEP" != "1" ]]; then
  clone_or_update pryingdeep
  if command -v go >/dev/null 2>&1; then
    info "Building pryingdeep (Go). Needs Postgres + Tor for full dark-web use."
    (
      cd "$TOOLS_DIR/pryingdeep"
      if [[ -d cmd/pryingdeep ]]; then
        go build -o "$BIN_DIR/pryingdeep" ./cmd/pryingdeep
      else
        go build -o "$BIN_DIR/pryingdeep" ./cmd/pryingdeep/pryingdeep.go 2>/dev/null \
          || go install -v github.com/iudicium/pryingdeep/cmd/pryingdeep@latest \
          || warn "pryingdeep build failed — repo is unmaintained; use Docker if needed."
      fi
    )
    # Config bootstrap helper
    write_wrapper pryingdeep-setup '
set -euo pipefail
cd "$TOOLS_DIR/pryingdeep"
if [[ -x "$BIN_DIR/pryingdeep" ]]; then
  "$BIN_DIR/pryingdeep" install || true
elif command -v pryingdeep >/dev/null 2>&1; then
  pryingdeep install || true
fi
echo "Edit config under $TOOLS_DIR/pryingdeep (pryingdeep.yaml / config)."
echo "Full dark-web crawl needs Tor + Postgres — see the repo Docker docs."
echo "Upstream note: author marked the project inactive."
'
  else
    warn "Go not available; skipping pryingdeep build."
  fi
else
  warn "SKIP_PRYINGDEEP=1 — not installing pryingdeep."
fi

# ---------- PATH + shellrc ----------
MARKER="# osint-zorin-setup"
append_path() {
  local rc="$1"
  [[ -f "$rc" ]] || return 0
  if ! grep -qF "$MARKER" "$rc" 2>/dev/null; then
    info "Adding $BIN_DIR to PATH in $rc"
    cat >> "$rc" <<PATHBLOCK

$MARKER
export OSINT_ROOT="$INSTALL_ROOT"
export PATH="$BIN_DIR:\$PATH"
PATHBLOCK
  fi
}
append_path "$HOME/.bashrc"
[[ -f "$HOME/.zshrc" ]] && append_path "$HOME/.zshrc"

# ---------- smoke checks (import / help only; no live targets) ----------
info "Smoke-checking wrappers (help / -h only)"
set +e
if "$BIN_DIR/blackbird" --help >/dev/null 2>&1; then info "blackbird OK"; else warn "blackbird help failed"; fi
if "$BIN_DIR/holehe" --help >/dev/null 2>&1; then info "holehe OK"; else warn "holehe help failed"; fi
if "$BIN_DIR/crosslinked" -h >/dev/null 2>&1; then info "crosslinked OK"; else warn "crosslinked help failed"; fi
if "$BIN_DIR/metagoofil" -h >/dev/null 2>&1; then info "metagoofil OK"; else warn "metagoofil help failed (legacy tool)"; fi
if test -f "$TOOLS_DIR/spiderfoot/sf.py"; then info "spiderfoot files OK"; else warn "spiderfoot missing"; fi
if command -v node >/dev/null 2>&1 && test -d "$TOOLS_DIR/social-analyzer/node_modules"; then
  info "social-analyzer (node) OK"
elif test -x "$BIN_DIR/social-analyzer"; then
  info "social-analyzer wrapper OK"
else
  warn "social-analyzer check inconclusive"
fi
set -e

cat <<DONE

${GREEN}Done.${NC}
Install root:  $INSTALL_ROOT
Wrappers:      $BIN_DIR  (on PATH after: source ~/.bashrc)

Quick start (educational / authorized use only):
  blackbird --username example
  holehe example@example.com
  crosslinked -f '{first}.{last}@example.com' "Example Company"
  metagoofil -d example.com -t pdf -l 20 -o $INSTALL_ROOT/output -f results.html
  spiderfoot          # UI at http://127.0.0.1:5001 — open in your browser
  social-analyzer --username example
  social-analyzer web # UI at http://127.0.0.1:9005/app.html

Docs: $SCRIPT_DIR/README.md

Re-run is safe. Skip heavy pieces with:
  SKIP_PRYINGDEEP=1 SKIP_SOCIAL_NODE=1 bash install-osint-zorin.sh
DONE
