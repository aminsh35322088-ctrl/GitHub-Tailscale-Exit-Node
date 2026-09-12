<div align="center">

# 🌐 GitHub Tailscale Exit Node

**From your first click to connecting your phone or computer**

A beginner-friendly guide to running a Tailscale internet gateway on GitHub Actions

[Get started](#start) · [Connect a device](#connect) · [Start / stop](#controls) · [Troubleshooting](#troubleshooting) · [فارسی](./README.md)

</div>

<!-- EXIT-NODE-STATUS:START -->

## 📡 Latest recorded status

| Item | Value |
| :--- | :--- |
| Execution state | 🟢 Keep-alive running · setup verified |
| Last checked | 2026-09-12 11:27:02 UTC |
| Configured name | `GitHub-Exit` |
| Keep-alive started | 2026-09-12 07:16:44 UTC |
| Elapsed at this check | 250 min |
| Nominal handover | 2026-09-12 12:46:44 UTC |
| Run details | [Open run](https://github.com/aminsh35322088-ctrl/GitHub-Tailscale-Exit-Node/actions/runs/34678275441) |

> This is a GitHub Actions step snapshot, not a phone connectivity test or a live tunnel probe. Refreshes on run events and approximately every 30 minutes; treat snapshots older than 60 minutes as stale. Handover is an estimate; elapsed time only advances when checked.

<!-- EXIT-NODE-STATUS:END -->

## What will you set up?

This project runs a temporary Linux machine on **GitHub Actions** and joins it to your private Tailscale network. Select that machine as an **Exit Node** in Tailscale to route your device's internet traffic through it.

Initial setup happens in your browser. You do not need to install Linux, buy a VPS, or enter terminal commands.

| Term | Plain-English meaning |
| :--- | :--- |
| **Fork** | A copy of this project in your GitHub account |
| **Workflow / Run** | An automated GitHub program / one execution of it |
| **Tailnet** | Your private network of Tailscale devices |
| **Exit Node** | The device your internet traffic exits through |
| **Secret** | GitHub's protected storage for credentials |
| **Watchdog** | A program that checks runs and attempts recovery |

> [!IMPORTANT]
> Runners are temporary. The current configuration keeps each node running for approximately **5½ hours**, then prepares a replacement. Handover can interrupt connectivity, and you may need to select the new exit node. A fixed IP, specific country, and continuous availability are not guaranteed.

<a id="start"></a>

## 🚀 Setup roadmap

**1. Copy the project · 2. Configure your network · 3. Tailscale credentials · 4. GitHub token · 5. Save secrets · 6. Start · 7. Connect**

Before you begin:

- Have a [GitHub account](https://github.com) with access to Actions.
- Have a [Tailscale account](https://login.tailscale.com/start) with permission to manage your network.
- Choose the phone or computer you want to connect.

On mobile, enable your browser's **Desktop site** option if GitHub hides a button or menu.

### 1 · Make your own copy

1. Click **Fork → Create a new fork** at the top of this repository.
2. Select your account as **Owner**. You can keep the project name.
3. Click **Create fork**.

**✅ Check:** The page address starts with your own GitHub username. Complete every following GitHub step in **your fork**. The original owner's secrets are not copied.

### 2 · Prepare your Tailscale network

Sign in to the [Tailscale admin console](https://login.tailscale.com/admin), open [Access controls](https://login.tailscale.com/admin/acls/file), and use the **JSON** editor.

You need a **`tag:exit`** device tag and **`autoApprovers`** to approve each replacement exit node automatically.

<details>
<summary><strong>🆕 New network? Open the complete, copyable example</strong></summary>

For a new network without important existing configuration, replace the initial policy with this example and save it. It allows member-owned devices to use internet access through exit nodes. It does not grant direct device-to-device access or SSH.

```json
{
  "tagOwners": {
    "tag:exit": ["autogroup:admin"]
  },
  "autoApprovers": {
    "exitNode": ["tag:exit"]
  },
  "grants": [
    {
      "src": ["autogroup:member"],
      "dst": ["autogroup:internet"],
      "ip": ["*"]
    }
  ]
}
```

</details>

<details>
<summary><strong>🔧 Already using Tailscale? Merge into your existing policy</strong></summary>

Save a backup first. Preserve your current rules and merge these entries:

1. Add `"tag:exit": ["autogroup:admin"]` inside `tagOwners`.
2. Add `"exitNode": ["tag:exit"]` inside `autoApprovers`. If `exitNode` already exists, append the tag to its list.
3. If the intended users do not already have internet access permission, add a grant targeting `autogroup:internet`. The example above allows all members; restrict `src` to the intended users or groups for a restricted network.

Do not create duplicate keys, such as two `tagOwners` objects. Separate JSON entries with commas and save only after the editor accepts the policy. Automatic route approval and user permission to use exit nodes are separate settings.

</details>

**✅ Check:** The policy saves successfully and `tag:exit` is defined. [Policy reference](https://tailscale.com/docs/reference/syntax/policy-file)

### 3 · Create Tailscale credentials

1. Open [OAuth clients](https://login.tailscale.com/admin/settings/oauth) in Tailscale.
2. Create an **OAuth client**, named something like `GitHub Exit Node`.
3. Enable **Write** for **Auth Keys** — the `auth_keys` scope.
4. Select **`tag:exit`** as its permitted tag and create the client.
5. Keep the **Client ID** and **Client secret** for step 5.

**✅ Check:** You have both values. Copy the secret when it is shown; it may not be displayed again. See the [official Action documentation](https://github.com/tailscale/github-action/tree/v4).

> The current workflow uses an **OAuth client**. Do not substitute a regular auth key for these two values.

### 4 · Create the GitHub control token

This token lets the watchdog start replacement runs and set the shutdown variable.

1. In your **GitHub account settings**, open [Fine-grained personal access tokens](https://github.com/settings/personal-access-tokens) and select **Generate new token**.
2. Name it `Exit Node Watchdog` and note its expiration date.
3. Set **Resource owner** to your account.
4. Choose **Only select repositories** and select **your fork only**.
5. Under **Repository permissions**, configure:

| Permission | Access | Purpose |
| :--- | :--- | :--- |
| **Actions** | **Read and write** | Read, start, and cancel runs |
| **Variables** | **Read and write** | Set the shutdown variable during `stop` |
| **Metadata** | **Read-only** | Basic access added by GitHub |

6. Generate the token and copy its value for the next step.

**✅ Check:** The token only covers your fork. Do not omit **Variables**: the stop action needs it. [Variables API permissions](https://docs.github.com/en/rest/actions/variables#update-a-repository-variable)

### 5 · Save all three secrets

In **your fork**, open:

**Settings → Secrets and variables → Actions → Secrets → New repository secret**

Create one secret per row. Copy the name exactly, paste its corresponding value in **Secret**, then select **Add secret**.

| Name — copy exactly | Value |
| :--- | :--- |
| `TS_OAUTH_CLIENT_ID` | Client ID from step 3 |
| `TS_OAUTH_SECRET` | Client secret from step 3 |
| `ACTIONS_WATCHDOG_TOKEN` | GitHub token from step 4 |

**✅ Check:** All three names appear under **Repository secrets**. GitHub hiding their values after saving is normal.

> [!TIP]
> Use **Secrets**, not **Variables**, for credentials. Never paste them into project files, issues, or public screenshots.

### 6 · Start your first run

1. Open **Actions** in your fork. Accept the workflow activation prompt if shown.
2. Select **Tailscale Exit Node Watchdog**.
3. Select **Run workflow**, branch **main**, and **action: ensure**.
4. Start the run. Then open the new **Tailscale Exit Node** run.
5. Open its **exit-node** job and inspect the steps.

| What you see | Meaning |
| :--- | :--- |
| **Connect Tailscale** succeeds | The runner joined your network |
| **Verify Exit Node** succeeds | The tag and exit-node advertisement passed the local checks |
| **Keep Exit Node Alive** keeps running | Expected: this step keeps the service running |
| **Queued / Pending** | Waiting for a runner or the previous execution to finish |

**✅ Check:** [Machines](https://login.tailscale.com/admin/machines) shows an online **GitHub-Exit** device with `tag:exit`.

**Do not wait for the entire workflow to turn green.** A working exit node stays **In progress**. A green Watchdog run alone does not prove internet connectivity.

If the node appears but exit-node use has not been approved, open its menu in Machines and enable **Edit route settings → Use as exit node**, then save. Step 2's `autoApprovers` setting automates this for replacements.

<a id="connect"></a>

## 📱 7 · Connect your phone or computer

Install [Tailscale from the official download page](https://tailscale.com/download) and sign in to the **same tailnet**.

| Device | Instructions |
| :--- | :--- |
| **Android / iPhone** | Open Tailscale, enable the connection, open **Exit Node**, and choose the online **GitHub-Exit**. Accept the system VPN permission prompt. |
| **Windows** | Open Tailscale from its icon near the clock, then choose the online **GitHub-Exit** under **Exit node**. |
| **macOS** | Open Tailscale in the menu bar and select the online device under **Exit Node**. |

**Allow LAN access** lets you also reach local devices such as your router or printer. It is optional for initial setup. [Official connection guide](https://tailscale.com/docs/features/exit-nodes)

### Confirm that it works

1. Before selecting an exit node, note your public IP on an IP-checking website.
2. Select **GitHub-Exit** and reload the same page.
3. Confirm that the public IP changes and websites load, while Tailscale displays the selected exit node.

**✅ Setup complete:** The node is online, selected, and internet access works through the new public IP.

<a id="controls"></a>

## ⏯️ Daily use, stopping, and restarting

| Goal | Action |
| :--- | :--- |
| Disconnect only my device | Set Exit Node to **None / Do not use exit node** in the app. GitHub keeps running. |
| Request a stop | **Actions → Tailscale Exit Node Watchdog → Run workflow → action: stop** |
| Start again | Delete `EXIT_NODE_DISABLED` or set it to `false`, then run Watchdog with **ensure**. |
| Check status | Inspect the main Actions run and the online device in Tailscale. |

The shutdown variable is under:

**Settings → Secrets and variables → Actions → Variables → Repository variables**

`stop` first sets `EXIT_NODE_DISABLED=true`, then cancels active and waiting runs. **Cancel workflow alone is not a permanent stop**: recovery can launch another run.

> [!IMPORTANT]
> In the current code, the shutdown variable is checked by recovery logic; it does not block every direct or scheduled start of the main workflow. To **stay fully stopped**, run `stop`, then use **Disable workflow** in the three-dot menu for both **Tailscale Exit Node** and **Tailscale Exit Node Watchdog**. Cancel any remaining **In progress / Queued** runs. To resume, enable both workflows, set the variable to `false`, and run Watchdog with `ensure`.

## 📡 How the README report works

**README Status** is a separate observer. It reads GitHub's run and step metadata and updates the marked blocks at the top of all three READMEs, on run events and approximately every 30 minutes. You can also run it manually from Actions.

Green means **Verify Exit Node passed and Keep Exit Node Alive is running** at the recorded check time. It does not prove that your phone is connected, that routing was approved, or that the tunnel is healthy at this instant. Treat a report older than **60 minutes** as stale; scheduling and page rendering can be delayed.

It displays the configured name, keep-alive start, elapsed minutes at the check, estimated handover, and a run link. It publishes no keys, IP addresses, or device inventory. It uses the built-in `GITHUB_TOKEN` with **Actions: read** and **Contents: write**; no extra PAT permission or secret is required. Branch rules may prevent direct documentation updates; inspect **README Status** if its timestamp stops changing. Disabling this reporter only stops README updates.

<a id="troubleshooting"></a>

## 🧩 Troubleshooting

Open the problematic run in **Actions**, enter its job, and read the **first failed step**.

| Symptom | What to check |
| :--- | :--- |
| No **Run workflow** button | Use your own fork, enable Actions, select a workflow, and try desktop mode on mobile. |
| **Connect Tailscale** fails | Check both OAuth secrets, **Auth Keys: Write**, and the `tag:exit` selection. |
| `tags ... invalid or not permitted` | Use exactly `tag:exit` in both the policy and OAuth permissions. |
| Watchdog returns `401` / `403` | Check the GitHub token's expiration, repository selection, and **Actions: Read and write**. |
| Cannot set `EXIT_NODE_DISABLED` | The token also needs **Variables: Read and write**. Follow the complete-stop instructions above. |
| Green Watchdog, no new node | Check `EXIT_NODE_DISABLED`, existing queued runs, and **Ensure an Exit Node Is Running** messages. |
| `Refusing to dispatch to avoid a crash loop` | Three short failures triggered the guard. Fix the cause, then manually start **Tailscale Exit Node** once. |
| Node exists but is not selectable | Check exit-node approval, `autoApprovers`, and the user's access to `autogroup:internet`. |
| Connected, but websites fail | Check the online node and policy. Temporarily disable another VPN that may conflict, and test another network. |
| Disconnects after several hours | Locate the replacement run and new online device. Reselect it if necessary: the same name does not preserve device identity. |
| Slow connection | The route between your ISP and the runner matters. Relayed paths may be slower; a direct path is not guaranteed. |
| README report is stale or unknown | Inspect **README Status** for API or push failures. A reporting failure alone does not mean the exit node failed. |

<details>
<summary><strong>🖥️ Optional: check direct vs. relayed connectivity</strong></summary>

If the Tailscale CLI is available, replace the example address with the **GitHub-Exit** Tailscale IP shown in Machines:

```bash
tailscale ping 100.x.y.z
```

`via DERP(...)` indicates a relay; `via IP:port` indicates a direct path. Initial replies may use a relay before switching to direct. This tests the Tailscale path, so also check public IP and web access.

</details>

## ⚙️ What happens behind the scenes?

| Component | Current behavior |
| :--- | :--- |
| **Exit Node** | Runs on `ubuntu-latest`, requests the name `GitHub-Exit`, and keeps the node running for 330 minutes. |
| **Handover** | Queues a successor. Sequential execution means runner startup can cause a connection gap. |
| **Watchdog** | Checks after the main workflow completes and on a 10-minute schedule; GitHub scheduling can be delayed. |
| **Backup schedule** | The main workflow also has a schedule at minute 17 every 6 hours. |
| **Crash guard** | When no run is active or waiting, three consecutive failures shorter than 15 minutes prevent another automatic dispatch. |
| **Repository Heartbeat** | Checks weekly and commits a heartbeat file if the last commit is at least 30 days old. |
| **README Status** | Independently reports run/step status without controlling connection or recovery. |

<details>
<summary><strong>📂 Project files and local checks</strong></summary>

| File | Purpose |
| :--- | :--- |
| [tailscale-exit-node.yml](./.github/workflows/tailscale-exit-node.yml) | Node setup, checks, and successor preparation |
| [tailscale-watchdog.yml](./.github/workflows/tailscale-watchdog.yml) | `ensure`, `stop`, and run summaries |
| [ensure-exit-node.sh](./.github/scripts/ensure-exit-node.sh) | Active/queued run checks and recovery |
| [repository-heartbeat.yml](./.github/workflows/repository-heartbeat.yml) | Periodic repository activity |
| [readme-status.yml](./.github/workflows/readme-status.yml) | Independent status reporter |
| [readme-status.py](./.github/scripts/readme-status.py) | Read run metadata and replace only status blocks |

From a local checkout with Bash, jq, and Python 3:

```bash
bash .github/scripts/tests/ensure-exit-node.test.sh
python3 -m unittest discover -s .github/scripts/tests -p 'test_readme_status.py'
```

The workflow also enables Tailscale SSH. Using it requires an appropriate SSH access policy and is not necessary for internet access in this guide.

</details>

## 📌 Limits and maintenance

- **Usage and billing:** Check your Actions allowance, billing, and [GitHub's terms](https://docs.github.com/en/site-policy/github-terms/github-terms-for-additional-products-and-features#actions). This guide does not promise a permanent free server.
- **Token expiration:** Replace `ACTIONS_WATCHDOG_TOKEN` before the PAT expires.
- **Temporary devices:** Each Action creates an ephemeral node. A reused name does not guarantee a fixed IP or uninterrupted connectivity.
- **IPv6:** The code enables forwarding for both IP versions. Public IPv6 egress depends on the runner's network.
- **Tailnet Lock:** Networks using Tailnet Lock require a [different Action authentication configuration](https://github.com/tailscale/github-action/tree/v4#tailnet-lock).
- **Exposed credentials:** Revoke and replace a leaked key at its issuing service; deleting it from a file is not enough.

---

**More resources:** [OAuth clients](https://tailscale.com/docs/features/oauth-clients) · [Exit Nodes](https://tailscale.com/docs/features/exit-nodes) · [GitHub tokens](https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/managing-your-personal-access-tokens) · [Actions limits](https://docs.github.com/en/actions/reference/limits)

[⬆ Back to setup](#start)
