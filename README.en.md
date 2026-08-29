# supreme-palm-tree

A Tailscale exit node that runs on GitHub Actions and keeps itself online.

> **What is this?** This project turns a GitHub Actions runner into a temporary Tailscale exit node. Your phone, PC, or another Tailscale device can then send its internet traffic through that runner.
>
> **Important:** GitHub-hosted runners are temporary cloud machines. This project is designed for personal experimentation and lightweight use, not as a guaranteed 24/7 VPN service. GitHub can cancel jobs, change runner availability, or enforce usage limits.

## Beginner setup — run your own Exit Node

You do **not** need Linux, a VPS, or a server. Everything is configured from GitHub's website.

### 1. Create your own copy

The easiest method is to click **Fork** on this repository and create the fork under your own GitHub account.

After forking, work only in **your own fork**. Your fork should contain the `.github/workflows/` and `.github/scripts/` directories from this repository.

### 2. Create a Tailscale account

Create or sign in to your Tailscale account, then open the Tailscale admin console.

You need permission to create an OAuth client. Tailscale documents this as requiring Owner, Admin, Network admin, or IT admin permissions depending on the operation.

### 3. Create the `tag:exit` tag

This project expects the GitHub runner to be registered with the tag **`tag:exit`**.

In Tailscale, create the tag:

```text
exit
```

Tailscale displays tags with the `tag:` prefix, so the resulting tag is:

```text
tag:exit
```

Make sure your OAuth client is allowed to use/own this tag.

### 4. Create a Tailscale OAuth client

In the Tailscale admin console, create an **OAuth client**.

Give the client the permissions required by this project and allow it to use `tag:exit`.

Copy these two values immediately:

```text
Client ID
Client secret
```

**Never paste the client secret into the README, an issue, a chat, or a commit.** Store it only as a GitHub secret.

### 5. Add the Tailscale secrets to GitHub

Open your fork on GitHub and go to:

**Settings → Secrets and variables → Actions → New repository secret**

Create:

| Name | Value |
| ---- | ----- |
| `TS_OAUTH_CLIENT_ID` | Your Tailscale OAuth Client ID |
| `TS_OAUTH_SECRET` | Your Tailscale OAuth Client secret |

### 6. Create the GitHub watchdog token

Create a **fine-grained Personal Access Token** and restrict it to **your fork**.

Recommended repository permissions:

- **Actions:** Read and write
- **Metadata:** Read-only

Add the token to your fork as the repository secret:

```text
ACTIONS_WATCHDOG_TOKEN
```

Treat this token like a password and never commit it.

### 7. Enable Actions

Open:

**Settings → Actions → General**

Make sure GitHub Actions are enabled.

### 8. Start the Exit Node

Open:

**Actions → Tailscale Exit Node Watchdog → Run workflow**

Set:

```text
action = ensure
```

Then run the workflow.

The watchdog checks whether an Exit Node run already exists and starts one when necessary.

### 9. Wait for the runner

Open **Actions → Tailscale Exit Node** and inspect the running job.

When setup succeeds, the temporary GitHub runner should appear in your Tailscale admin console as a device using `tag:exit`.

### 10. Approve the node if required

Depending on your tailnet configuration, Tailscale may require device or exit-node approval. Approve it in the Tailscale admin console if prompted.

### 11. Use it as an Exit Node

On the device that should use the Exit Node:

**Tailscale → Exit node → select your GitHub runner**

### 12. Test it

Check your public IP before and after enabling the Exit Node. It should change to the public IP of the GitHub runner.

## How automatic recovery works

A GitHub Actions job cannot run forever, so the project chains multiple runs together. Each run stays online for `ONLINE_MINUTES` (330 by default) and hands over to its successor.

Recovery has multiple layers:

1. **Handover:** the current run dispatches the next run before ending. Concurrency prevents two exit-node runs from operating simultaneously.
2. **Relaunch job:** handles cancellation, startup failure, and rejected dispatches.
3. **Watchdog:** reacts to completed runs and periodically checks for missing or stale runs.
4. **Schedule:** provides another restart path if the other recovery mechanisms fail.

All paths use `.github/scripts/ensure-exit-node.sh`, which avoids starting another node when one is already active or queued.

## Starting and stopping

| Action | How |
| ------ | --- |
| Start | Run **Tailscale Exit Node Watchdog** with `action=ensure` |
| Stop | Run **Tailscale Exit Node Watchdog** with `action=stop` |

To start again after stopping, set `EXIT_NODE_DISABLED` to `false` or delete the variable, then run the watchdog with `action=ensure`.

## Crash-loop guard

If the last three runs all fail in under 15 minutes, the recovery script stops dispatching new runs instead of consuming Actions minutes indefinitely.

Common causes include expired Tailscale credentials, an OAuth client that can no longer use `tag:exit`, or a GitHub Actions configuration problem.

## Configuration

### Secrets

| Name | Purpose |
| ---- | ------- |
| `TS_OAUTH_CLIENT_ID` | Tailscale OAuth client ID |
| `TS_OAUTH_SECRET` | Tailscale OAuth client secret |
| `ACTIONS_WATCHDOG_TOKEN` | Fine-grained GitHub PAT used by the watchdog |

### Variables

| Name | Purpose |
| ---- | ------- |
| `EXIT_NODE_DISABLED` | Kill switch. `true` stops the relaunch chain. |

## Troubleshooting

### Workflow does not start

Check that Actions are enabled, the PAT exists and has **Actions: Read and write**, the workflow files exist, and `EXIT_NODE_DISABLED` is not `true`.

### Tailscale authentication fails

Verify the OAuth client ID/secret, OAuth client status, and permission to use `tag:exit`.

### Node appears but cannot be selected as an Exit Node

Check the Actions logs for the advertisement and health-check steps, then check Tailscale for approval requirements.

### Exit Node stops later

GitHub-hosted runners are temporary. The project attempts automatic recovery, but it cannot guarantee 24/7 uptime.

### `action=stop` does not work

The stop operation needs permission to update the `EXIT_NODE_DISABLED` repository variable. Verify the workflow permissions in your fork.

## Security notes

- Never commit `TS_OAUTH_SECRET` or `ACTIONS_WATCHDOG_TOKEN`.
- Restrict the PAT to only this repository.
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
- GitHub Actions workflow dispatch API: https://docs.github.com/en/rest/actions/workflows
- GitHub Actions secrets: https://docs.github.com/en/actions/reference/security/secrets
