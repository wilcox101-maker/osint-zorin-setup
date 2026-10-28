# OSINT Zorin setup — design

**Date:** 2026-10-28  
**Repo:** `wilcox101-maker/osint-zorin-setup` (new, public, GitHub)  
**Status:** Approved in chat; awaiting user review of this written spec before implementation plan

## Goal

Deliver an all-in-one installer for Dale’s seven OSINT forks on Zorin OS (detect and support the running release, including Zorin 18), plus a thin dependency-only helper. Leave `osint-wsl-setup` unchanged.

Educational / authorized use only. Upstream tools keep their own licenses.

## Non-goals

- Custom live ISO / appliance image
- Flatpak or `.deb` meta-packages
- Ansible / fleet automation
- Changing the WSL installer repo
- Windows/WSL helpers (`Copy-ToWsl.ps1`, WSL detection as a hard requirement)

## Approaches considered

| Option | Summary | Decision |
|--------|---------|----------|
| A — AIO bash + thin `install-deps.sh` | Same proven shape as WSL; apt + venvs + wrappers | **Chosen** |
| B — Flatpak / `.deb` | Better for store-style install; heavy to maintain across seven forks | Rejected |
| C — Ansible playbook | Good for fleets; overkill for one desktop | Rejected |

## Repository layout

```
osint-zorin-setup/
  install-osint-zorin.sh   # AIO installer
  install-deps.sh          # system packages (+ deadsnakes when needed)
  holehe-used              # wrapper (mode 0755)
  README.md
  LICENSE                  # MIT, Copyright 2026 Dale Wilcox
  CONTRIBUTING.md
  .gitignore               # clones, venvs, scan output, secrets
  .gitattributes
  docs/superpowers/specs/  # this design (and later plans)
```

No PowerShell or WSL-only files.

## Install layout on disk

Default `INSTALL_ROOT=$HOME/osint`:

```
~/osint/
  tools/     # git clones of the seven forks
  venvs/     # one Python venv per Python tool
  bin/       # wrappers on PATH
  output/    # default exports
  logs/
```

Environment overrides: `INSTALL_ROOT`, `SKIP_PRYINGDEEP`, `SKIP_SOCIAL_NODE`, `PYTHON_PREFERRED` (default `3.12`), `GITHUB_OWNER` (default `wilcox101-maker`).

## Tools (same seven as WSL)

| Tool | Kind | Wrapper | Notes |
|------|------|---------|-------|
| blackbird | Python CLI | `blackbird` | Username / email search |
| holehe | Python CLI | `holehe`, `holehe-used` | Email → registered accounts |
| CrossLinked | Python CLI | `crosslinked` | LinkedIn name enum |
| metagoofil | Python CLI | `metagoofil` | Public doc metadata |
| spiderfoot | Python UI/CLI | `spiderfoot` | `http://127.0.0.1:5001` |
| social-analyzer | Node preferred | `social-analyzer` | CLI or web `:9005` |
| pryingdeep | Go + Postgres/Tor | `pryingdeep` | Optional; skippable |

All clones from `https://github.com/${GITHUB_OWNER}/<repo>`.

## Behavior

### OS detection

- Read `/etc/os-release`.
- Prefer Zorin; also accept Ubuntu/Debian-family.
- Warn (do not abort) if ID is unexpected but `apt-get` works.
- Fail if the system is not apt-based.

### `install-deps.sh`

Idempotent apt install of packages required to build and run the tools, for example:

- Base: `git`, `curl`, `ca-certificates`, `build-essential`, `pkg-config`
- Python build: `libxml2-dev`, `libxslt1-dev`, `libffi-dev`, `libssl-dev`, `zlib1g-dev`
- Python runtime: system `python3` / `python3-venv` / `python3-dev`; if system Python is 3.13+, install `python3.12` (+ venv/dev) via deadsnakes PPA when available on that Ubuntu base
- Node.js (for social-analyzer) unless `SKIP_SOCIAL_NODE=1`
- Go, Postgres client/server pieces, Tor only when pryingdeep is not skipped

Safe to run alone to refresh system packages without re-cloning.

### `install-osint-zorin.sh`

1. Call or inline the same dep logic as `install-deps.sh`.
2. Resolve `PYTHON_BIN` (prefer 3.12 when system is 3.13+ or when preferred binary exists).
3. Create `INSTALL_ROOT` tree.
4. Clone or `git pull --ff-only` each tool under `tools/`.
5. Create/refresh per-tool venvs; install requirements (ensure holehe gets `requests` as on WSL).
6. Write wrappers into `bin/`; append `bin` to shell rc if missing.
7. Install `holehe-used` alongside.
8. Print a short “what next” summary (PATH, spiderfoot/social-analyzer URLs).

Idempotent: re-runs update clones and refresh wrappers.

### Error handling

- Fail loud: no sudo/apt, Python pin install failed, required clone failed.
- Warn and continue: optional skips, ff-only pull failure (leave tree as-is), unexpected but apt-capable distro.

## Docs

README covers: disclaimer, Zorin install steps, env knobs, run examples (parity with WSL where applicable), no Windows copy instructions. CONTRIBUTING points at PRs on this repo.

## Delivery

- New public GitHub repository `wilcox101-maker/osint-zorin-setup` (user creates empty repo or agent seeds per forge rules; forge default remains GitHub / `wilcox101-maker`).
- Initial content on `main` (or PR if the empty repo already has branch protection).
- `osint-wsl-setup` is not modified.

## Success criteria

- Fresh Zorin (detected release) can run `bash install-osint-zorin.sh` and end with working wrappers for the core six; pryingdeep installable unless skipped.
- `bash install-deps.sh` alone installs/refreshes system packages without requiring a prior tools install.
- Scripts are executable (`100755` for shell helpers).
- README and MIT LICENSE present; educational disclaimer at top of README.
- No WSL-only or PowerShell files in the repo.

## Out of scope for v1

Desktop `.desktop` launchers, GUI installer, ISO, packaging as Flatpak/deb, Watchdog wiring for the seven forks.
