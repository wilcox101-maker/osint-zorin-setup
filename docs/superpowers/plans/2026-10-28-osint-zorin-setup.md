# OSINT Zorin Setup Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship a new public GitHub repo `wilcox101-maker/osint-zorin-setup` with an AIO Zorin installer, a thin deps helper, wrappers, and docs for the same seven OSINT forks as `osint-wsl-setup`, without modifying the WSL repo.

**Architecture:** Bash installers adapted from `wilcox101-maker/osint-wsl-setup` (`install-osint-wsl.sh`). `install-deps.sh` owns apt/deadsnakes/Node/Go packages; `install-osint-zorin.sh` sources or invokes it, then clones forks, builds venvs/wrappers, and updates PATH. Detect Zorin/Ubuntu from `/etc/os-release`; warn but continue on other apt-based systems.

**Tech Stack:** Bash, apt, Python 3.12 (deadsnakes when needed), Node 20 (NodeSource), Go (optional), git, GitHub (`wilcox101-maker` forks).

## Global Constraints

- Forge: GitHub `wilcox101-maker/osint-zorin-setup` (public); do not change `osint-wsl-setup`.
- Tools: blackbird, holehe, CrossLinked, metagoofil, spiderfoot, social-analyzer, pryingdeep (optional via `SKIP_PRYINGDEEP`).
- Default install root: `$HOME/osint` with `tools/`, `venvs/`, `bin/`, `output/`, `logs/`.
- Env: `INSTALL_ROOT`, `SKIP_PRYINGDEEP`, `SKIP_SOCIAL_NODE`, `PYTHON_PREFERRED` (default `3.12`), `GITHUB_OWNER` (default `wilcox101-maker`).
- Educational / authorized-use disclaimer at top of README; MIT Copyright 2026 Dale Wilcox.
- Shell scripts must be mode `100755` in git; no PowerShell / WSL-only files.
- Prefer patterns from `/workspace/osint-wsl-setup/install-osint-wsl.sh` (or fetch from GitHub) when adapting logic.

## File map

| Path | Responsibility |
|------|----------------|
| `install-deps.sh` | OS detect + apt packages + Python 3.12 + optional Node/Go |
| `install-osint-zorin.sh` | AIO: deps + clones + venvs + wrappers + PATH + smoke |
| `holehe-used` | Standalone holehe `--only-used` helper (also written into `bin/` by AIO) |
| `README.md` | Zorin install/run docs |
| `LICENSE` | MIT Dale Wilcox 2026 |
| `CONTRIBUTING.md` | PR notes |
| `.gitignore` / `.gitattributes` | Exclude clones/venvs/secrets; LF for scripts |
| `docs/superpowers/specs/2026-10-28-osint-zorin-setup-design.md` | Approved design (already drafted under `/workspace/osint-zorin-setup/`) |
| `docs/superpowers/plans/2026-10-28-osint-zorin-setup.md` | This plan |

Reference content lives on the box at `/workspace/osint-zorin-setup/` (spec/plan) and `/workspace/osint-wsl-setup/` (WSL scripts to adapt). Cloud agent should copy those into the new repo or re-implement from this plan + the public WSL repo.

---

### Task 1: Scaffold repo metadata and docs

**Files:**
- Create: `LICENSE`, `CONTRIBUTING.md`, `.gitignore`, `.gitattributes`, `README.md`
- Create: `docs/superpowers/specs/2026-10-28-osint-zorin-setup-design.md` (from approved workspace copy)
- Create: `docs/superpowers/plans/2026-10-28-osint-zorin-setup.md` (this plan)

**Interfaces:**
- Consumes: none
- Produces: documented public repo skeleton; README lists seven tools and env knobs

- [ ] **Step 1: Create empty GitHub repo**

If `wilcox101-maker/osint-zorin-setup` does not exist, create it public via `gh repo create wilcox101-maker/osint-zorin-setup --public --description "OSINT tools installer for Zorin OS (wilcox101-maker forks)"` (or Cursor forge equivalent), then clone/work on `main`. Do not touch `osint-wsl-setup`.

- [ ] **Step 2: Write LICENSE**

Use MIT, Copyright (c) 2026 Dale Wilcox (same text as `osint-wsl-setup/LICENSE`).

- [ ] **Step 3: Write `.gitignore`**

```
# Local install trees if someone runs the script inside the clone
osint/
tools/
venvs/
bin/
output/
logs/
*.log
.env
.env.*
*.pem
*.key
__pycache__/
*.pyc
.venv/
node_modules/
```

- [ ] **Step 4: Write `.gitattributes`**

```
*.sh text eol=lf
holehe-used text eol=lf
```

- [ ] **Step 5: Write CONTRIBUTING.md**

Short: PRs against `main`, keep educational disclaimer, do not commit cloned tool trees or venvs, test on Zorin/Ubuntu apt-based systems.

- [ ] **Step 6: Write README.md**

Must include:
1. Educational / authorized-use disclaimer (first content after title).
2. Table of seven tools with wrappers (same as WSL README, Zorin wording; spiderfoot/social-analyzer URLs are localhost in the Zorin browser — not “Windows browser”).
3. Prerequisites: Zorin OS (17/18 or Ubuntu-based), `sudo`, network.
4. Install: `bash install-osint-zorin.sh` then `source ~/.bashrc`; mention `bash install-deps.sh` alone.
5. Options: `SKIP_PRYINGDEEP=1 SKIP_SOCIAL_NODE=1`, `INSTALL_ROOT`, `PYTHON_PREFERRED`.
6. Run examples (authorized placeholders only).
7. Link to design/plan under `docs/superpowers/`.

- [ ] **Step 7: Copy design + plan into `docs/superpowers/`**

From workspace uploads if available; keep filenames exact.

- [ ] **Step 8: Commit**

```bash
git add LICENSE CONTRIBUTING.md .gitignore .gitattributes README.md docs/
git commit -m "docs: scaffold osint-zorin-setup metadata and design"
```

---

### Task 2: `install-deps.sh`

**Files:**
- Create: `install-deps.sh`
- Test: run with `bash -n` and `shellcheck` if available; dry logic via sourcing helpers

**Interfaces:**
- Consumes: env `SKIP_PRYINGDEEP`, `SKIP_SOCIAL_NODE`, `PYTHON_PREFERRED`
- Produces: functions or side effects: `detect_os`, `apt_install`, `ensure_python`; exits 0 on success; sets `PYTHON_BIN` when sourced with a documented hook, OR exports nothing and only installs packages (AIO re-resolves Python). Prefer: script is runnable alone and also sourcable: if `$0` is the script name, run `main`; define `install_osint_deps` function the AIO can call after `source`.

- [ ] **Step 1: Implement header and helpers**

```bash
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
```

(Adjust Firefox package names for Zorin 18 if `firefox-esr` is missing — keep the fallback chain.)

- [ ] **Step 2: Syntax-check**

```bash
bash -n install-deps.sh
command -v shellcheck >/dev/null && shellcheck -x install-deps.sh || true
chmod +x install-deps.sh
```

Expected: no syntax errors.

- [ ] **Step 3: Commit**

```bash
git add install-deps.sh
git commit -m "feat: add install-deps.sh for Zorin/Ubuntu apt packages"
```

---

### Task 3: `install-osint-zorin.sh` AIO

**Files:**
- Create: `install-osint-zorin.sh`
- Create: `holehe-used` (repo-root helper matching WSL)

**Interfaces:**
- Consumes: `install_osint_deps` / `apt_install` / `ensure_python` / `PYTHON_BIN` from sourcing `install-deps.sh` in the same directory
- Produces: `~/osint` tree, wrappers in `$BIN_DIR`, PATH marker `# osint-zorin-setup`

- [ ] **Step 1: Implement AIO by adapting WSL installer**

Port logic from `osint-wsl-setup/install-osint-wsl.sh` with these changes:
1. Remove `require_wsl` hard path; call `install_osint_deps` after resolving `SCRIPT_DIR`.
2. Source `"$SCRIPT_DIR/install-deps.sh"` then `install_osint_deps` (avoid double `set -e` issues; or duplicate only the call once).
3. Marker `# osint-zorin-setup` instead of `# osint-wsl-setup`.
4. Spiderfoot / social-analyzer messages say “open in your browser” (not Windows).
5. Done banner references `install-osint-zorin.sh`.
6. Keep: `clone_or_update`, `make_venv`, `write_wrapper`, all seven tools, holehe `requests`, smoke checks, `SKIP_*` knobs.

Skeleton start:

```bash
#!/usr/bin/env bash
# install-osint-zorin.sh — idempotent OSINT installer for Zorin OS / Ubuntu
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
mkdir -p "$BIN_DIR" "$TOOLS_DIR" "$VENV_DIR" "$LOG_DIR" "$INSTALL_ROOT/output"
install_osint_deps
# ... clone_or_update / make_venv / write_wrapper / tools (same as WSL) ...
```

Copy tool blocks from WSL installer verbatim except UI messaging. Also `cp` or write `holehe-used` at repo root (same as WSL file) and ensure AIO `write_wrapper holehe-used` still creates `$BIN_DIR/holehe-used`.

- [ ] **Step 2: Syntax-check both scripts**

```bash
bash -n install-osint-zorin.sh
bash -n holehe-used
chmod +x install-osint-zorin.sh holehe-used
command -v shellcheck >/dev/null && shellcheck -x install-osint-zorin.sh || true
```

- [ ] **Step 3: Commit**

```bash
git add install-osint-zorin.sh holehe-used
git commit -m "feat: add Zorin AIO installer and holehe-used wrapper"
```

---

### Task 4: Verify and publish

**Files:**
- Modify: none required if scripts already executable; confirm git modes `100755`

**Interfaces:**
- Consumes: Tasks 1–3
- Produces: public `main` on GitHub with green syntax checks; shareable URL

- [ ] **Step 1: Confirm file modes**

```bash
git ls-files -s install-osint-zorin.sh install-deps.sh holehe-used
```

Expected: mode `100755` for all three. If `100644`, `git update-index --chmod=+x` and commit.

- [ ] **Step 2: Smoke without full install (optional on CI VM)**

If the cloud VM is Ubuntu/Debian apt-based and network allows, a light check:

```bash
SKIP_PRYINGDEEP=1 SKIP_SOCIAL_NODE=1 bash -n install-osint-zorin.sh
# Full install only if agent environment has sudo and policy allows — otherwise skip and note in PR/report
```

Do not hit live OSINT targets.

- [ ] **Step 3: Push `main`**

Push all commits to `https://github.com/wilcox101-maker/osint-zorin-setup`. Open a PR only if branch protection requires it; otherwise direct `main` is fine (same as WSL seed).

- [ ] **Step 4: Report back**

Return: repo URL, commit SHA, file list, confirmation WSL repo untouched, any packages that failed on the agent OS vs expected Zorin.

---

## Spec coverage checklist

| Spec requirement | Task |
|------------------|------|
| New public `osint-zorin-setup` | 1, 4 |
| Leave WSL repo alone | 1, 4 |
| AIO + `install-deps.sh` | 2, 3 |
| Seven tools + skips | 3 |
| Detect Zorin / apt warn | 2 |
| Python 3.12 / deadsnakes | 2 |
| `~/osint` layout + env knobs | 3 |
| MIT + disclaimer README | 1 |
| No Windows/WSL scripts | 1–3 |
| Executable scripts | 4 |

## Self-review notes

- No TBD/placeholder steps; code blocks included for deps and AIO skeleton; tool install bodies intentionally referenced from WSL (agent must copy those blocks, not invent new tool wiring).
- `PYTHON_BIN` must be set by `ensure_python` before `make_venv` in Task 3.
- Marker string consistently `# osint-zorin-setup`.
