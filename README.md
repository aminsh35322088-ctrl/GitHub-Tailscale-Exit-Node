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

Make sure your OAuth client is allowed to use/own this tag. Tailscale's GitHub Actions documentation requires a configured tag for tagged ephemeral nodes, and OAuth clients can be restricted to specific tags.

### 4. Create a Tailscale OAuth client

In the Tailscale admin console, create an **OAuth client**.

Give the client the permissions required by this project and allow it to use `tag:exit`.

Copy these two values immediately:

```text
Client ID
Client secret
```

**Never paste the client secret into the README, an issue, a chat, or a commit.** Store it only as a GitHub secret.

Tailscale's official documentation explains OAuth clients and the available scopes/tags in detail:

- https://tailscale.com/docs/features/oauth-clients
- https://tailscale.com/docs/integrations/github/github-action

### 5. Add the Tailscale secrets to GitHub

Open your fork on GitHub and go to:

**Settings → Secrets and variables → Actions → New repository secret**

Create these two repository secrets:

| Name | Value |
| ---- | ----- |
| `TS_OAUTH_CLIENT_ID` | Your Tailscale OAuth Client ID |
| `TS_OAUTH_SECRET` | Your Tailscale OAuth Client secret |

Do **not** create normal repository variables for these credentials. They are secrets because they are authentication credentials.

GitHub automatically masks secrets in workflow logs, but you should still never print them deliberately.

### 6. Create the GitHub watchdog token

This repository can use a dedicated GitHub token for the watchdog. This is recommended because it gives the watchdog an independent identity from the temporary `GITHUB_TOKEN` used by a workflow run.

Create a **fine-grained Personal Access Token** from your GitHub account.

Recommended settings:

- **Resource owner:** your GitHub account
- **Repository access:** Only select repositories
- Select **your fork** of this repository
- **Repository permissions → Actions:** `Read and write`
- **Repository permissions → Metadata:** `Read-only` (normally mandatory/default)

The token needs to be able to dispatch the Exit Node workflow. GitHub's API documentation lists **Actions: write** as the required fine-grained permission for creating a workflow dispatch event.

Copy the token once it is created.

Then add it to your fork as:

```text
Settings → Secrets and variables → Actions → New repository secret
```

Name it exactly:

```text
ACTIONS_WATCHDOG_TOKEN
```

and paste the token as its value.

**Treat this token like a password.** Never commit it to the repository.

### 7. Check Actions permissions

In your fork, open:

**Settings → Actions → General → Workflow permissions**

Make sure Actions are enabled and workflows are allowed to run.

For this project, the workflow files already declare the permissions they need. Do not randomly increase permissions unless you understand why they are required.

### 8. Start the Exit Node

Now open:

**Actions → Tailscale Exit Node Watchdog**

Click:

**Run workflow**

Set:

```text
action = ensure
```

Then click **Run workflow**.

The watchdog checks whether an Exit Node run already exists. If not, it starts one.

You can also start **Tailscale Exit Node** directly, but using the watchdog is the recommended first start because it is the recovery/supervisor entry point.

### 9. Wait for the runner to connect

Open:

**Actions → Tailscale Exit Node**

and open the running job.

Wait until the Tailscale setup and health checks complete successfully.

Then open the Tailscale admin console and look at your devices. The GitHub runner should appear as a temporary/ephemeral device using the `tag:exit` identity.

The exact device name can change because GitHub-hosted runners are disposable.

### 10. Approve the Exit Node if Tailscale asks you to

Tailscale may require the new device to be approved, depending on your tailnet's device-approval configuration and how the OAuth credentials were created.

If approval is required, approve the new device in the Tailscale admin console.

### 11. Enable it as an Exit Node

The workflow advertises the runner as an exit node. In Tailscale, make sure the node is allowed to act as an exit node if your tailnet requires an additional approval/permission step.

Then, on the device that should use it:

**Tailscale → Exit node → select your GitHub runner**

Tailscale officially documents the exit-node flow here:

- https://tailscale.com/docs/features/exit-nodes

### 12. Test your connection

On the client device, enable the GitHub runner as the Tailscale exit node and then check your public IP.

The public IP should now be the IP of the GitHub runner rather than your normal connection.

You can also check the GitHub Actions log for the project's built-in health checks.

## How the automatic recovery works

A GitHub Actions job cannot run forever, so the exit node is a chain of runs rather than a single long one. Each run stays online for `ONLINE_MINUTES` (330 by default, under GitHub's 360-minute job ceiling) and then hands over to its successor:

1. **Handover.** Shortly before it ends, the running job dispatches the next run. Because the workflow uses a `concurrency` group, that run waits in the queue instead of starting a second exit node, and begins the moment the current run releases the group. The gap is the runner startup time.
2. **Relaunch job.** Runs only if the handover did not succeed, which covers cancellation, startup failure, and a rejected dispatch.
3. **Watchdog.** Triggered by `workflow_run: completed` on the exit node workflow, so it reacts as soon as a run finishes, plus a `*/10` cron as a last-resort backstop. It also replaces runs that are stuck: active, overdue, and no longer reporting progress to GitHub.
4. **Schedule.** The exit node workflow keeps a `17 */6` cron so the chain can restart itself even if every step above failed.

All four paths call the same script, `.github/scripts/ensure-exit-node.sh`, which never starts a node when one is already active or queued.

## Starting and stopping

| Action | How |
| ------ | --- |
| Start | Run **Tailscale Exit Node Watchdog** with `action=ensure`, or **Tailscale Exit Node** directly |
| Stop | Run **Tailscale Exit Node Watchdog** with `action=stop` |

Stopping is handled by the watchdog because a dispatch of the exit node workflow can only queue behind the run that already holds the concurrency group. `action=stop` sets the repository variable `EXIT_NODE_DISABLED` to `true` and then cancels the active runs. Cancelling alone would not be enough, since a cancelled run still triggers its own relaunch.

To start again, set `EXIT_NODE_DISABLED` to `false` or delete the variable, then run the watchdog.

## Crash-loop guard

If the last three runs all failed in under 15 minutes, the script stops dispatching instead of burning Actions minutes on a node that cannot start.

Runs ended by the concurrency group are ignored here, because they are a normal part of replacing a queued run.

The usual causes of a real crash loop are expired `TS_OAUTH_CLIENT_ID` / `TS_OAUTH_SECRET` credentials, an OAuth client that no longer owns `tag:exit`, or a GitHub Actions configuration problem.

## Configuration

### Secrets

| Name | Purpose |
| ---- | ------- |
| `TS_OAUTH_CLIENT_ID` | Tailscale OAuth client ID |
| `TS_OAUTH_SECRET` | Tailscale OAuth client secret |
| `ACTIONS_WATCHDOG_TOKEN` | Fine-grained GitHub PAT with Actions: read/write for this repository, used by the watchdog to dispatch workflows |

### Variables

| Name | Purpose |
| ---- | ------- |
| `EXIT_NODE_DISABLED` | Kill switch. `true` stops the relaunch chain. |

Tunable knobs live in `env:` at the top of the Exit Node workflow and as environment defaults in `ensure-exit-node.sh`.

## Troubleshooting

### The workflow does not start

Check:

1. **Actions are enabled** for your fork.
2. `ACTIONS_WATCHDOG_TOKEN` exists and has **Actions: Read and write** for the correct repository.
3. The workflow exists under `.github/workflows/`.
4. `EXIT_NODE_DISABLED` is not set to `true`.
5. You are running the workflow from your own fork, not the upstream repository.

### Tailscale authentication fails

Check that:

- `TS_OAUTH_CLIENT_ID` is correct.
- `TS_OAUTH_SECRET` is correct.
- The OAuth client is still active.
- The OAuth client can use the `tag:exit` tag.
- Your Tailscale account has enough permissions to create/use the OAuth client and tag.

Do not paste the secret into an issue or log. Rotate the credential in Tailscale if you accidentally expose it.

### The node appears in Tailscale but cannot be selected as an Exit Node

Check the GitHub Actions log for the exit-node advertisement and health-check steps. Then check the Tailscale admin console for device approval or exit-node approval requirements.

### The Exit Node stops later

That can happen. GitHub-hosted runners are not permanent servers, and GitHub may cancel a job or make a runner unavailable. This repository's purpose is to recover automatically when possible, not to provide an uptime guarantee.

Check **Actions → Tailscale Exit Node Watchdog** first. If the watchdog is repeatedly failing, inspect its logs before restarting the Exit Node manually.

### `action=stop` does not work

The stop operation needs permission to update the repository variable `EXIT_NODE_DISABLED`. If the token/workflow permissions in your fork were customized, verify that the workflow has the required Actions/Variables permissions.

## Security notes

- Never commit `TS_OAUTH_SECRET` or `ACTIONS_WATCHDOG_TOKEN`.
- Prefer a fine-grained GitHub PAT restricted to **only this repository**.
- Give the PAT only the permissions required by the workflow.
- Do not share your Tailscale OAuth secret with other people.
- If a credential is exposed, revoke/rotate it immediately.
- Remember that an exit node routes a device's internet traffic through the runner. Only use a tailnet and GitHub account you control, and only allow people/devices you trust to use the exit node.

## Tests

The handover logic is tested offline against a `curl` test double, so no network or GitHub token is needed:

```bash
bash .github/scripts/tests/ensure-exit-node.test.sh
```

## Official documentation

- Tailscale GitHub Action: https://tailscale.com/docs/integrations/github/github-action
- Tailscale OAuth clients: https://tailscale.com/docs/features/oauth-clients
- Tailscale Exit Nodes: https://tailscale.com/docs/features/exit-nodes
- GitHub Actions workflow dispatch API: https://docs.github.com/en/rest/actions/workflows
- GitHub Actions secrets: https://docs.github.com/en/actions/reference/security/secrets
