import datetime as dt
import importlib.util
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

spec = importlib.util.spec_from_file_location('readme_status', Path(__file__).parents[1] / 'readme-status.py')
status = importlib.util.module_from_spec(spec)
spec.loader.exec_module(status)


class StatusTests(unittest.TestCase):
    def setUp(self):
        self.now = dt.datetime(2026, 9, 12, 3, tzinfo=dt.timezone.utc)
        self.repo = 'owner/repo'
        self.run = dict(id=1, status='in_progress', created_at='2026-09-12T01:00:00Z',
                        event='workflow_dispatch', head_repository={'full_name': self.repo})
        self.steps = [dict(name='Verify Exit Node', conclusion='success', status='completed'),
                      dict(name='Keep Exit Node Alive', status='in_progress', started_at='2026-09-12T02:00:00Z')]

    def collect(self, runs=None, steps=None, job_status='in_progress'):
        replies = [{'workflow_runs': runs if runs is not None else [self.run]},
                   {'jobs': [{'name': 'exit-node', 'status': job_status,
                              'steps': steps if steps is not None else self.steps}]}]
        with patch.object(status, 'api', side_effect=replies):
            return status.collect(self.repo, 'main', self.now)

    def test_queued_successor_does_not_hide_ready_node(self):
        queued = dict(self.run, id=2, status='pending', created_at='2026-09-12T02:59:00Z')
        result = self.collect([queued, self.run])
        self.assertEqual((result['state'], result['run_id']), ('running', 1))
        # Use the step's actual start, excluding the hour spent queued/setup.
        self.assertEqual(result['elapsed'], 60)
        self.assertEqual(status.timestamp(result['expected']).hour, 7)

    def test_running_workflow_is_not_enough_for_green(self):
        self.assertEqual(self.collect(steps=[])['state'], 'starting')
        self.steps[0]['conclusion'] = 'failure'
        self.assertEqual(self.collect()['state'], 'starting')

    def test_completed_keep_step_is_handover_not_green(self):
        self.steps[1]['status'] = 'completed'
        self.assertEqual(self.collect()['state'], 'handover')

    def test_queued_failed_idle_and_untrusted_runs(self):
        self.assertEqual(self.collect([dict(self.run, status='pending')])['state'], 'queued')
        self.assertEqual(self.collect([dict(self.run, status='completed', conclusion='failure')])['state'], 'failed')
        self.assertEqual(self.collect([])['state'], 'idle')
        self.assertEqual(self.collect([dict(self.run, event='pull_request')])['state'], 'idle')
        self.assertEqual(self.collect([dict(self.run, head_repository={'full_name': 'other/repo'})])['state'], 'idle')

    def test_only_marked_content_changes(self):
        original = 'human intro\n' + status.BEGIN + '\nold\n' + status.END + '\nhuman ending'
        block = status.render(self.collect(), self.repo)
        result = status.replace_block(original, block)
        self.assertTrue(result.startswith('human intro\n'))
        self.assertTrue(result.endswith('\nhuman ending'))
        self.assertEqual(status.replace_block(result, block), result)

    def test_missing_duplicate_or_reversed_markers_fail_closed(self):
        for text in ('no markers', status.BEGIN * 2 + status.END, status.END + status.BEGIN):
            with self.assertRaises(ValueError):
                status.replace_block(text, 'new')

    def test_both_languages_have_timestamp_and_staleness_notice(self):
        snapshot = self.collect()
        for fa in (True, False):
            rendered = status.render(snapshot, self.repo, fa)
            self.assertIn('2026-09-12 03:00:00 UTC', rendered)
            self.assertIn('/owner/repo/actions/runs/1', rendered)
            self.assertIn('۶۰' if fa else '60 minutes', rendered)
            self.assertNotIn('GH_TOKEN', rendered)

    def test_api_failure_replaces_old_green_with_unknown(self):
        with tempfile.TemporaryDirectory() as directory:
            import os
            previous = os.getcwd()
            try:
                os.chdir(directory)
                for name in ('README.md', 'README.fa.md', 'README.en.md'):
                    Path(name).write_text(status.BEGIN + '\n🟢 old\n' + status.END)
                with patch.dict(os.environ, {'GITHUB_REPOSITORY': self.repo}), \
                        patch('sys.argv', ['readme-status.py']), \
                        patch.object(status, 'api', side_effect=RuntimeError('private error')):
                    status.main()
                self.assertIn('Unknown', Path('README.en.md').read_text())
                self.assertNotIn('🟢', Path('README.en.md').read_text())
            finally:
                os.chdir(previous)


if __name__ == '__main__':
    unittest.main()
