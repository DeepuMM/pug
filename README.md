<p align="center">
  <img src="frontend/src/assets/logo.svg" alt="PUG" width="160">
</p>

<h1 align="center">PUG — Playbook Under Guidance</h1>

<p align="center"><em>Your playbooks, run by AI agents — with you in the loop.</em></p>

---

PUG is an agentic assistant that works through repeatable tasks ("playbooks") across the web browser,
code and files. A person co-plans the work, approves sensitive actions, and can take over the browser at
any time.

- **Co-planning** — PUG drafts a step-by-step plan; you edit and approve it before anything runs.
- **Playbooks** — save a plan once and re-run it (e.g. a weekly time sheet) from **Saved Plans**.
- **Co-tasking** — watch the live browser, interrupt, take control and hand back.
- **Action guards** — sensitive actions (form submits, code execution) wait for your approval.
- **Sandboxed** — the browser and the code executor run in containers, not on your machine.

All agents run on an Azure OpenAI model (default: `gpt-5.4`) using keyless Microsoft Entra ID auth.

PUG is built on the open-source [Magentic-UI](https://github.com/microsoft/magentic-ui) 0.1 line (MIT).

## How it works

| Agent | Role |
|---|---|
| Orchestrator | Plans the task, assigns steps, decides when it's done |
| Web surfer | Drives a Chromium browser in a container (live view in the UI) |
| Coder | Writes and runs Python/shell in a sandbox container |
| File surfer | Reads and converts files in the session workspace |
| Action guard | Decides which actions need your approval |

The web app is a FastAPI backend + Gatsby/React UI served on one port.

---

## Prerequisites

| Need | Notes |
|---|---|
| Windows 11 + **WSL2** (Ubuntu) or Linux | Run everything from the WSL/Linux shell |
| A container engine | **Docker** in WSL/Linux, **or Podman for Windows** (Podman Desktop with a running machine). `scripts/start-pug.sh` uses Docker if present, otherwise starts the Podman API automatically |
| [`uv`](https://docs.astral.sh/uv/getting-started/installation/) | Python 3.12 is fetched by `uv` |
| Node.js 18+ and `npx` | Only to build the UI |
| Azure CLI (`az`) | For keyless sign-in to Azure OpenAI |
| An Azure OpenAI / Foundry model deployment | Vision-capable chat model, e.g. `gpt-5.4`. Your account needs the **Cognitive Services OpenAI User** role on the resource |

## Setup

```bash
git clone https://github.com/DeepuMM/pug.git
cd pug

# 1. Model config (git-ignored — never commit it)
cp config.example.yaml config.yaml
#    edit config.yaml: set azure_endpoint, azure_deployment and model

# 2. Sign in to Azure (the account that can use the deployment)
az login
az account set --subscription "<subscription name or id>"

# 3. Build the web UI (one-off, and after any frontend change)
scripts/build-frontend.sh
```

## Run

```bash
scripts/start-pug.sh            # default port 8081
```

Open <http://127.0.0.1:8081>. The first task in a session takes ~30 s longer while the browser and
code containers start (the first run also pulls the two container images).

What the start script does:

1. Checks `config.yaml` exists and that you're signed in with `az`.
2. Uses Docker if available; otherwise starts the Podman-for-Windows API on `tcp://127.0.0.1:2375`
   (bound to localhost only) and points `DOCKER_HOST` at it.
3. Creates the Python environment in `~/.venvs/pug` on first run (`uv sync --extra azure`).
4. Starts PUG with app data in `./pug-data` (git-ignored).

Overrides: `PUG_VENV`, `PUG_DATA`, `PUG_CONFIG`, `DOCKER_HOST`, `PODMAN_EXE` — see the header of
`scripts/start-pug.sh`.

> **WSL tips:** keep the Python venv on the Linux filesystem (the default `~/.venvs/pug`) — a venv under
> `/mnt/c` makes startup take minutes. With Podman for Windows, keep `PUG_DATA` under `/mnt/c` so the
> Podman machine can mount it into the containers.

### Command-line run (no UI)

```bash
DOCKER_HOST=tcp://127.0.0.1:2375 AZURE_TOKEN_CREDENTIALS=AzureCliCredential \
  ~/.venvs/pug/bin/magentic-cli --work-dir ./pug-data/cli --config config.yaml --autonomous \
  --task "Go to https://www.python.org/downloads/, find the latest Python 3 version, write latest_python.py that prints it and run it."
```

## Playbooks

Playbooks are saved plans: a task plus ordered steps, each assigned to an agent. They live in
[`playbooks/`](playbooks/) as JSON and appear in the UI under **Saved Plans**.

Load them into a running PUG:

```bash
scripts/load-playbooks.sh       # http://127.0.0.1:8081, user guestuser@gmail.com
```

Run one: **Saved Plans → Run Plan**, review the steps, accept.

Included:

| Playbook | What it does |
|---|---|
| [`ibm-timesheet.json`](playbooks/ibm-timesheet.json) | Opens time.ibm.com, waits for you to sign in, copies the previous week, unchecks zero-hour rows, clicks OK and reports — **never submits** |

### Writing a playbook

```json
{
  "task": "One line describing the outcome",
  "steps": [
    {
      "title": "Short step name",
      "details": "Short step name. \n Exactly what to do, what to check, and when to stop and ask the user.",
      "agent_name": "web_surfer"
    }
  ]
}
```

Guidelines:

- `agent_name` is one of `web_surfer`, `coder_agent`, `file_surfer`.
- Never put credentials in a playbook. For sign-in pages, add a step telling the agent to **stop and
  ask the user to take control** of the browser.
- State the stop conditions ("if the button is missing, report instead of guessing").
- Keep irreversible actions (submit, pay, delete) for the user, or say explicitly that approval is required.

## Security

- No API keys: model access uses your Entra ID session (`az login`). `config.yaml`, `.env` and
  `pug-data/` are git-ignored.
- Browser and code run in containers; only `pug-data/` is mounted into them.
- PUG sends page screenshots and content to your model deployment — don't use it on data your model
  endpoint isn't approved for.
- It can make mistakes: keep a human in the loop and review before anything is submitted.

## Troubleshooting

| Symptom | Fix |
|---|---|
| `Not signed in to Azure` / 401 from the model | `az login`, then check the role assignment on the resource |
| `Podman API did not come up` | Start Podman Desktop / `podman.exe machine start`, then re-run the script |
| Very slow startup on WSL | The venv is under `/mnt/c` — use the default `~/.venvs/pug` |
| Containers can't see files | `PUG_DATA` must be under `/mnt/c` when using Podman for Windows |
| UI shows 404 | Run `scripts/build-frontend.sh` |

More: [TROUBLESHOOTING.md](TROUBLESHOOTING.md) (upstream notes).

## License and attribution

PUG is a modified version of [Magentic-UI](https://github.com/microsoft/magentic-ui), © Microsoft
Corporation, licensed under the [MIT License](LICENSE). The licence does not grant rights to use
Microsoft names, logos or trademarks; PUG is not a Microsoft product. See also the upstream
[Transparency Note](TRANSPARENCY_NOTE.md).
