# OSINT tools on Zorin OS (wilcox101-maker forks)

> **Educational / authorized use only.** These installers wrap third-party OSINT tools. Do not target accounts or networks without permission. Upstream tools keep their own licenses.

Install and run these seven forks on Zorin OS (17 or 18, or another Ubuntu-based release). Wrappers land on your PATH under `~/osint/bin`.

| Tool | Kind | Wrapper | Notes |
|------|------|---------|-------|
| [blackbird](https://github.com/wilcox101-maker/blackbird) | Python CLI | `blackbird` | Username / email search |
| [holehe](https://github.com/wilcox101-maker/holehe) | Python CLI | `holehe`, `holehe-used` | Email → registered accounts |
| [CrossLinked](https://github.com/wilcox101-maker/CrossLinked) | Python CLI | `crosslinked` | LinkedIn name enum via search engines |
| [metagoofil](https://github.com/wilcox101-maker/metagoofil) | Python CLI | `metagoofil` | Legacy metadata from public docs |
| [spiderfoot](https://github.com/wilcox101-maker/spiderfoot) | Python UI/CLI | `spiderfoot` | Open `http://127.0.0.1:5001` in your browser |
| [social-analyzer](https://github.com/wilcox101-maker/social-analyzer) | Node (preferred) | `social-analyzer` | CLI or `social-analyzer web` → `http://127.0.0.1:9005` |
| [pryingdeep](https://github.com/wilcox101-maker/pryingdeep) | Go + Postgres/Tor | `pryingdeep` | Optional; upstream inactive; heavy |

## Prerequisites

- Zorin OS 17 or 18, or another Ubuntu-based system with `apt`
- `sudo`
- Network access to GitHub and the Ubuntu package archives (and NodeSource / deadsnakes unless you skip those pieces)

The installer reads `/etc/os-release`. Zorin, Ubuntu, and Debian-family systems are the expected targets. On any other apt-based distro it warns and continues. It stops if `apt-get` is missing.

## Install

```bash
bash install-osint-zorin.sh
source ~/.bashrc
```

System packages only (no clones, venvs, or wrappers):

```bash
bash install-deps.sh
```

`install-deps.sh` is safe to source. It defines `install_osint_deps` and runs that function only when you execute the file directly.

When system Python is 3.13 or newer, the deps script installs Python 3.12 from the deadsnakes PPA so packages such as `lxml` can build. Override the pin with `PYTHON_PREFERRED` (default `3.12`).

Default layout:

```
~/osint/
  tools/          # git clones
  venvs/          # one Python venv per tool
  bin/            # wrappers on PATH
  output/         # default place for exports
  logs/
```

### Options

```bash
# Lighter install (skip the Go crawler; social-analyzer uses the Python package)
SKIP_PRYINGDEEP=1 SKIP_SOCIAL_NODE=1 bash install-osint-zorin.sh

# Custom location
INSTALL_ROOT=~/recon bash install-osint-zorin.sh

# Different Python minor, or clones from another GitHub owner
PYTHON_PREFERRED=3.11 GITHUB_OWNER=wilcox101-maker bash install-osint-zorin.sh
```

| Variable | Default | Effect |
|----------|---------|--------|
| `INSTALL_ROOT` | `$HOME/osint` | Tools, venvs, wrappers, output, and logs |
| `SKIP_PRYINGDEEP` | `0` | Set to `1` to skip Go and pryingdeep |
| `SKIP_SOCIAL_NODE` | `0` | Set to `1` to skip Node 20, Firefox, and tesseract; social-analyzer installs as a Python package |
| `PYTHON_PREFERRED` | `3.12` | Interpreter for venvs. Installed from deadsnakes when system Python is 3.13+ and this binary is missing |
| `GITHUB_OWNER` | `wilcox101-maker` | GitHub user or org that owns the seven forks |

Re-running the script fast-forwards clones (`git pull --ff-only`) and refreshes wrappers.

## Run examples

Placeholders only. Query accounts and domains you are allowed to look at.

```bash
# Username / email OSINT
blackbird --username example
blackbird --email example@example.com --pdf
holehe example@example.com
holehe-used example@example.com

# Company employee naming
crosslinked -f '{first}.{last}@example.com' "Example Company"

# Public document metadata (legacy CLI; flags vary by tree)
metagoofil -d example.com -t pdf,doc -l 40 -o ~/osint/output -f results.html

# SpiderFoot web UI — leave this running, then open it in your browser
spiderfoot
# → http://127.0.0.1:5001
# CLI mode: spiderfoot cli -h
#          spiderfoot-cli -h

# Social Analyzer
social-analyzer --username example
social-analyzer web
# → http://127.0.0.1:9005/app.html
```

## pryingdeep (optional)

Upstream is unmaintained. Full use needs:

- Go (the installer installs `golang-go` when this piece is not skipped)
- PostgreSQL (or Docker Compose from the tool repo)
- Tor for `.onion` targets

After install:

```bash
pryingdeep-setup    # runs `pryingdeep install` when the binary built
# then edit pryingdeep.yaml / config under ~/osint/tools/pryingdeep
```

Prefer Docker if you want Tor and Postgres without hand-wiring:

```bash
cd ~/osint/tools/pryingdeep
docker compose up    # or docker-compose up, per repo docs
```

Skip it with `SKIP_PRYINGDEEP=1`.

## Updating

```bash
bash install-osint-zorin.sh
```

Or per tool:

```bash
git -C ~/osint/tools/blackbird pull
source ~/osint/venvs/blackbird/bin/activate
pip install -r ~/osint/tools/blackbird/requirements.txt
```

## Uninstall

```bash
rm -rf ~/osint
# remove the "# osint-zorin-setup" block from ~/.bashrc (and ~/.zshrc if present)
```

## Troubleshooting

| Symptom | Fix |
|---------|-----|
| `command not found` after install | `source ~/.bashrc` or open a new terminal |
| SpiderFoot or social-analyzer URL does not load | Confirm something is listening: `ss -ltnp \| grep -E '5001\|9005'`. Open `http://127.0.0.1` in your browser |
| `pip` / SSL errors | `sudo apt-get install -y ca-certificates` and re-run |
| social-analyzer screenshots empty | Firefox and tesseract are installed unless `SKIP_SOCIAL_NODE=1` |
| metagoofil crashes on Python 3 | Legacy script; dependencies are vendored in-tree |
| GitHub rate limits on clone | `gh auth login`, or wait and re-run |
| Venv builds fail on Python 3.13+ | Re-run so deadsnakes can install `PYTHON_PREFERRED` (default 3.12) |

## Design

- [Design spec](docs/superpowers/specs/2026-10-28-osint-zorin-setup-design.md)
- [Implementation plan](docs/superpowers/plans/2026-10-28-osint-zorin-setup.md)
