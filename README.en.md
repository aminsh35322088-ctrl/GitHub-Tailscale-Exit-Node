# GitHub Tailscale Exit Node

[فارسی](./README.md)

A Tailscale exit node that runs on GitHub Actions and keeps itself online.

> **Important:** GitHub-hosted runners are temporary cloud machines. This project is designed for personal experimentation and lightweight use, not as a guaranteed 24/7 VPN service. GitHub can cancel jobs, change runner availability, or enforce usage limits.

## Beginner setup — run your own Exit Node

You do **not** need Linux, a VPS, or a server. Everything is configured from GitHub's website.

### 1. Create your own copy

Click **Fork** on this repository and create the fork under your own GitHub account. After forking, run the workflows from your own fork.

### 2. Create the Tailscale tag

Create or sign in to your Tailscale account and configure the tag used by this project:

```text
tag:exit
```

Your OAuth client must be allowed to use this tag.

### 3. Create a Tailscale OAuth client

In the Tailscale admin console, create an **OAuth client** and allow it to use `tag:exit`.

Keep these values safe:

```text
TS_OAUTH_CLIENT_ID
TS_OAUTH_SECRET
```

Never put the OAuth secret in source code, issues, commits, or public chat.

### 4. Create the GitHub fine-grained PAT

Create a **fine-grained Personal Access Token** in GitHub and restrict repository access to **your fork only**.

For the full watchdog functionality, grant:

```text
Actions: Read and write
Variables: Read and write
```

`Variables: Read and write` is required by **`action=stop`**, because the watchdog updates the `EXIT_NODE_DISABLED` repository variable.

Add the token to your fork as the repository secret:

```text
ACTIONS_WATCHDOG_TOKEN
```

### 5. Add GitHub secrets

Open:

**Settings → Secrets and variables → Actions → New repository secret**

Create:

| Name | Value |
| ---- | ----- |
| `TS_OAUTH_CLIENT_ID` | Your Tailscale OAuth Client ID |
| `TS_OAUTH_SECRET` | Your Tailscale OAuth Client secret |
| `ACTIONS_WATCHDOG_TOKEN` | Your fine-grained GitHub PAT |

### 6. Enable Actions

Open the **Actions** tab and enable workflows if GitHub asks you to do so.

### 7. Start the Exit Node

Open:

**Actions → Tailscale Exit Node Watchdog → Run workflow**

Set:

```text
action = ensure
```

Then click **Run workflow**.

### 8. Verify the runner

Open **Actions → Tailscale Exit Node** and inspect the new run. After successful setup, the temporary Linux runner should appear in your Tailscale admin console with `tag:exit`.

Approve the device/exit node in Tailscale if your tailnet requires approval.

### 9. Use the Exit Node

On the phone or computer that should use it:

1. Install Tailscale and sign in to the same tailnet.
2. Enable Tailscale.
3. Open **Exit Node**.
4. Select the GitHub Actions runner.

Compare your public IP before and after enabling the Exit Node to verify the connection.

## How automatic recovery works

A GitHub Actions job cannot run forever, so the project chains multiple runs together:

```text
Run #1 → Run #2 → Run #3 → ...
```

Recovery has several layers:

- **Self-relaunch:** the current run prepares its successor before ending.
- **Relaunch recovery:** retries after handover or startup failures.
- **Watchdog:** checks active, queued, and stale runs.
- **Scheduled backstop:** provides another restart path if the chain breaks.
- **Crash-loop protection:** prevents endless runs when repeated failures occur.

The recovery logic is centralized in `.github/scripts/ensure-exit-node.sh`.

## Starting and stopping

| Action | How |
| ------ | --- |
| Start | Run **Tailscale Exit Node Watchdog** with `action=ensure` |
| Stop | Run **Tailscale Exit Node Watchdog** with `action=stop` |

For `action=stop`, `ACTIONS_WATCHDOG_TOKEN` must be configured with **Variables: Read and write** permission.

To start again, set `EXIT_NODE_DISABLED` to `false` or remove it, then run the watchdog with `action=ensure`.

## Troubleshooting

### Workflow does not start

Check that Actions are enabled, the PAT exists and has **Actions: Read and write**, the workflow files exist, and `EXIT_NODE_DISABLED` is not `true`.

### `action=stop` does not work

Verify that `ACTIONS_WATCHDOG_TOKEN` exists and has both:

```text
Actions: Read and write
Variables: Read and write
```

If the PAT is missing, the watchdog should fail early with an actionable error instead of attempting the Variables API with the default `GITHUB_TOKEN`.

### Tailscale authentication fails

Verify the OAuth client ID/secret, OAuth client status, and permission to use `tag:exit`.

### Node appears but cannot be selected as an Exit Node

Check Tailscale approval requirements, the `tag:exit` configuration, and the workflow logs.

### Exit Node stops later

GitHub-hosted runners are temporary. The project attempts automatic recovery, but it cannot guarantee 24/7 uptime.

## Security notes

- Never commit `TS_OAUTH_SECRET` or `ACTIONS_WATCHDOG_TOKEN`.
- Restrict the PAT to only your repository.
- Give credentials only the permissions they need.
- Rotate exposed credentials immediately.
- Only allow trusted devices/users to use your exit node.

## Tests

The handover logic can be tested offline:

```bash
bash .github/scripts/tests/ensure-exit-node.test.sh
```

## Official documentation

- Tailscale GitHub Action: https://tailscale.com/docs/integrations/github/github-action
- Tailscale OAuth clients: https://tailscale.com/docs/features/oauth-clients
- Tailscale Exit Nodes: https://tailscale.com/docs/features/exit-nodes
- GitHub Actions: https://docs.github.com/actions

## Important limitation

This project is a creative way to run a Tailscale Exit Node on GitHub Actions. It is **not a replacement for a VPS or dedicated server**. GitHub may stop runners, limit workflows, or change Actions availability, so permanent 24/7 uptime is not guaranteed.
