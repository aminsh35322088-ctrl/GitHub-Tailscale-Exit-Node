#!/usr/bin/env python3
"""Publish a GitHub execution snapshot, never control the exit node.

Only the marked blocks in the three READMEs are edited. No Tailscale API,
credentials, addresses, or device inventory are included in the report.
"""
import argparse
import datetime as dt
import json
import os
from pathlib import Path
import re
import subprocess
import time
import urllib.request
from urllib.parse import urlencode

BEGIN = '<!-- EXIT-NODE-STATUS:START -->'
END = '<!-- EXIT-NODE-STATUS:END -->'
UTC = dt.timezone.utc


def timestamp(value):
    return dt.datetime.fromisoformat(value.replace('Z', '+00:00')) if value else None


def utc(value):
    return value.astimezone(UTC).strftime('%Y-%m-%d %H:%M:%S UTC') if value else '—'


def api(path):
    headers = {'Accept': 'application/vnd.github+json', 'User-Agent': 'exit-node-status',
               'X-GitHub-Api-Version': '2022-11-28'}
    if os.environ.get('GH_TOKEN'):
        headers['Authorization'] = 'Bearer ' + os.environ['GH_TOKEN']
    request = urllib.request.Request('https://api.github.com' + path, headers=headers)
    with urllib.request.urlopen(request, timeout=20) as response:
        return json.load(response)


def collect(repo, branch, now):
    query = urlencode({'per_page': 30, 'branch': branch})
    runs = api(f'/repos/{repo}/actions/workflows/tailscale-exit-node.yml/runs?{query}')['workflow_runs']
    runs = [r for r in runs if r.get('head_repository', {}).get('full_name') == repo
            and r.get('event') in ('workflow_dispatch', 'schedule')]
    # Prefer an active run over a newer queued successor. Never infer readiness
    # from run.status alone: it also covers queue/setup/relaunch time.
    runs.sort(key=lambda r: (r.get('created_at', ''), r['id']), reverse=True)
    active = [r for r in runs if r['status'] == 'in_progress']
    pending = [r for r in runs if r['status'] not in ('completed', 'in_progress')]
    run = next(iter(active or pending or runs), None)
    state = {'state': 'idle', 'checked': now.isoformat(), 'run_id': None,
             'started': None, 'elapsed': None, 'expected': None}
    if not run:
        return state
    state['run_id'] = run['id']
    if run['status'] == 'completed':
        state['state'] = 'failed' if run.get('conclusion') in ('failure', 'timed_out', 'startup_failure') else 'idle'
        return state
    state['state'] = 'queued' if not active else 'starting'
    if not active:
        return state
    jobs = api(f'/repos/{repo}/actions/runs/{run["id"]}/jobs?filter=latest&per_page=100')['jobs']
    job = next((j for j in jobs if j['name'] == 'exit-node'), {})
    steps = {s['name']: s for s in job.get('steps', [])}
    keep = steps.get('Keep Exit Node Alive', {})
    verify = steps.get('Verify Exit Node', {})
    if (job.get('status') == 'in_progress' and keep.get('status') == 'in_progress'
            and verify.get('conclusion') == 'success' and keep.get('started_at')):
        start = timestamp(keep['started_at'])
        minutes = re.search(r'^  ONLINE_MINUTES:\s*(\d+)\s*$',
                            Path('.github/workflows/tailscale-exit-node.yml').read_text(), re.M)
        # Read the nominal setting for display only; do not alter the workflow.
        state.update(state='running', started=start.isoformat(),
                     elapsed=max(0, int((now - start).total_seconds() / 60)),
                     expected=(start + dt.timedelta(minutes=int(minutes[1]))).isoformat() if minutes else None)
    elif keep.get('status') == 'completed' or job.get('status') == 'completed':
        state['state'] = 'handover'
    return state


LABELS = {
    'running': ('🟢 Keep-alive running · setup verified', '🟢 نگهداری اتصال در حال اجرا · راه‌اندازی تأیید شده'),
    'starting': ('🟡 Starting · readiness not confirmed', '🟡 در حال راه‌اندازی · آمادگی هنوز تأیید نشده'),
    'queued': ('🟡 Waiting for a runner', '🟡 در انتظار اجرا'),
    'handover': ('🟡 Finishing / handing over', '🟡 در حال پایان یا تعویض اجرا'),
    'idle': ('⚪ No active exit-node run observed', '⚪ اجرای فعال خروجی مشاهده نشد'),
    'failed': ('🔴 Latest run failed · no active run observed', '🔴 آخرین اجرا ناموفق بود · اجرای فعالی مشاهده نشد'),
    'unknown': ('⚪ Unknown · GitHub API check failed', '⚪ نامشخص · بررسی API گیت‌هاب ناموفق بود'),
}


def render(state, repo, fa=False):
    index = 1 if fa else 0
    title = '📡 آخرین وضعیت ثبت‌شده' if fa else '📡 Latest recorded status'
    labels = ['وضعیت اجرا', 'آخرین بررسی', 'نام تنظیم‌شده', 'شروع مرحلهٔ نگهداری',
              'زمان سپری‌شده تا این بررسی', 'تعویض تقریبی', 'جزئیات اجرا'] if fa else [
              'Execution state', 'Last checked', 'Configured name', 'Keep-alive started',
              'Elapsed at this check', 'Nominal handover', 'Run details']
    link = f'https://github.com/{repo}/actions'
    if state['run_id']:
        link += f'/runs/{int(state["run_id"])}'
    values = [LABELS[state['state']][index], utc(timestamp(state['checked'])), '`GitHub-Exit`',
              utc(timestamp(state['started'])),
              f'{state["elapsed"]} ' + ('دقیقه' if fa else 'min') if state['elapsed'] is not None else '—',
              utc(timestamp(state['expected'])), f'[{"مشاهده" if fa else "Open run"}]({link})']
    note = ('این گزارش از مراحل GitHub Actions است، نه تست اینترنت گوشی یا تأیید سلامت لحظه‌ای تونل. '
            'به‌روزرسانی هنگام رویداد اجرا و تقریباً هر ۳۰ دقیقه؛ گزارش قدیمی‌تر از ۶۰ دقیقه را نامعتبر بدانید. '
            'زمان تعویض تخمینی است و شمارنده فقط در زمان بررسی به‌روز می‌شود.') if fa else (
            'This is a GitHub Actions step snapshot, not a phone connectivity test or a live tunnel probe. '
            'Refreshes on run events and approximately every 30 minutes; treat snapshots older than 60 minutes as stale. '
            'Handover is an estimate; elapsed time only advances when checked.')
    direction = '<div dir="rtl">\n\n' if fa else ''
    tail = '\n\n</div>' if fa else ''
    return (BEGIN + '\n\n' + direction + '## ' + title + '\n\n| ' +
            ('مورد | مقدار' if fa else 'Item | Value') + ' |\n| :--- | :--- |\n' +
            '\n'.join(f'| {k} | {v} |' for k, v in zip(labels, values)) +
            '\n\n> ' + note + tail + '\n\n' + END)


def replace_block(text, block):
    if text.count(BEGIN) != 1 or text.count(END) != 1:
        raise ValueError('README must contain exactly one status marker pair')
    start = text.index(BEGIN)
    end = text.index(END)
    if end < start:
        raise ValueError('Status markers are out of order')
    return text[:start] + block + text[end + len(END):]


def write_readmes(state, repo):
    # Validate all three before writing any of them.
    changes = {name: replace_block(Path(name).read_text(), render(state, repo, name != 'README.en.md'))
               for name in ('README.md', 'README.fa.md', 'README.en.md')}
    for name, content in changes.items():
        Path(name).write_text(content)


def git(*args):
    return subprocess.run(['git', *args], check=True, capture_output=True, text=True).stdout.strip()


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--publish', action='store_true')
    parser.add_argument('--snapshot', help='Read a local snapshot for preview/testing; no API request')
    args = parser.parse_args()
    repo = os.environ['GITHUB_REPOSITORY']
    branch = os.environ.get('DEFAULT_BRANCH', 'main')
    if not re.fullmatch(r'[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+', repo):
        raise ValueError('Invalid repository name')
    state = None
    if args.snapshot:
        state = json.loads(Path(args.snapshot).read_text())
    else:
        # Allow a newly-started runner up to one minute to pass setup. This
        # observer has its own job and never delays the exit-node job.
        for attempt in range(7):
            try:
                state = collect(repo, branch, dt.datetime.now(UTC))
            except Exception:
                print('::warning::Status API check failed; publishing unknown (no credentials logged).')
                state = dict(state='unknown', checked=dt.datetime.now(UTC).isoformat(),
                             run_id=None, started=None, elapsed=None, expected=None)
                break
            if state['state'] != 'starting' or attempt == 6:
                break
            time.sleep(10)
    if not args.publish:
        write_readmes(state, repo)
        return
    # This job owns a disposable checkout. Refresh it on each retry and only
    # reapply marker blocks, preserving any concurrent human README edits.
    git('config', 'user.name', 'github-actions[bot]')
    git('config', 'user.email', '41898282+github-actions[bot]@users.noreply.github.com')
    for attempt in range(3):
        git('fetch', 'origin', branch)
        git('reset', '--hard', 'FETCH_HEAD')
        write_readmes(state, repo)
        git('add', '--', 'README.md', 'README.fa.md', 'README.en.md')
        if not git('diff', '--cached', '--name-only'):
            return
        git('commit', '-m', 'docs: refresh exit node status')
        try:
            git('push', 'origin', f'HEAD:refs/heads/{branch}')
            return
        except subprocess.CalledProcessError:
            if attempt == 2:
                raise RuntimeError('Status push failed; check branch rules and contents: write permission') from None
    raise RuntimeError('Status was not published')


if __name__ == '__main__':
    main()
