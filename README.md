# supreme-palm-tree

A Tailscale exit node that runs on GitHub Actions and keeps itself online.

## How it stays online

A GitHub Actions job cannot run forever, so the exit node is a chain of runs
rather than a single long one. Each run stays online for `ONLINE_MINUTES`
(330 by default, under GitHub's 360-minute job ceiling) and then hands over to
its successor:

1. **Handover.** Shortly before it ends, the running job dispatches the next
   run. Because the workflow uses a `concurrency` group, that run waits in the
   queue instead of starting a second exit node, and begins the moment the
   current run releases the group. The gap is the runner startup time.
2. **Relaunch job.** Runs only if the handover did not succeed, which covers
   cancellation, startup failure, and a rejected dispatch.
3. **Watchdog.** Triggered by `workflow_run: completed` on the exit node
   workflow, so it reacts as soon as a run finishes, plus a `*/10` cron as a
   last-resort backstop. It also replaces runs that are stuck: active, overdue,
   and no longer reporting progress to GitHub.
4. **Schedule.** The exit node workflow keeps a `17 */6` cron so the chain can
   restart itself even if every step above failed.

All four paths call the same script, `.github/scripts/ensure-exit-node.sh`,
which never starts a node when one is already active or queued.

## Starting and stopping

| Action | How |
| ------ | --- |
| Start  | Run **Tailscale Exit Node Watchdog** with `action=ensure`, or **Tailscale Exit Node** directly |
| Stop   | Run **Tailscale Exit Node Watchdog** with `action=stop` |

Stopping is handled by the watchdog because a dispatch of the exit node
workflow can only queue behind the run that already holds the concurrency
group. `action=stop` sets the repository variable `EXIT_NODE_DISABLED` to
`true` and then cancels the active runs. Cancelling alone would not be enough,
since a cancelled run still triggers its own relaunch.

To start again, set `EXIT_NODE_DISABLED` to `false` or delete the variable,
then run the watchdog.

## Crash-loop guard

If the last three runs all failed in under 15 minutes, the script stops
dispatching instead of burning Actions minutes on a node that cannot start.
Runs ended by the concurrency group are ignored here, because they are a
normal part of replacing a queued run. The usual causes of a real crash loop
are expired `TS_OAUTH_CLIENT_ID` / `TS_OAUTH_SECRET` secrets, or an OAuth
client that no longer owns `tag:exit`.

## Configuration

Secrets:

| Name | Purpose |
| ---- | ------- |
| `TS_OAUTH_CLIENT_ID` | Tailscale OAuth client, must own `tag:exit` |
| `TS_OAUTH_SECRET`    | Tailscale OAuth secret |
| `ACTIONS_WATCHDOG_TOKEN` | PAT with `repo` and `workflow` scope, used to dispatch the successor. Falls back to `github.token`. |

The fallback to `github.token` keeps the chain working but is weaker in two
ways: it cannot write the `EXIT_NODE_DISABLED` variable, so `action=stop` fails,
and runs it creates are attributed to the Actions bot, where GitHub applies
recursion limits to some derived events. If the watchdog's `workflow_run`
trigger stops firing after a handover, that is the likely cause, and recovery
then depends on the `*/10` cron instead.

Variables:

| Name | Purpose |
| ---- | ------- |
| `EXIT_NODE_DISABLED` | Kill switch. `true` stops the relaunch chain. |

Tunable knobs live in `env:` at the top of the exit node workflow and as
environment defaults in `ensure-exit-node.sh`.

## Tests

The handover logic is tested offline against a `curl` test double, so no
network or GitHub token is needed:

```bash
bash .github/scripts/tests/ensure-exit-node.test.sh
```
