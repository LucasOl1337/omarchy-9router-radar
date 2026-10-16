import importlib.util
from pathlib import Path
import unittest
from unittest.mock import patch
from types import SimpleNamespace

spec = importlib.util.spec_from_file_location('collector', Path(__file__).parents[1] / 'collect.py')
collector = importlib.util.module_from_spec(spec)
spec.loader.exec_module(collector)

class CollectorTest(unittest.TestCase):
    def test_custom_credential_command_is_an_argument_list(self):
        with patch.object(collector.subprocess, 'run', return_value=SimpleNamespace(returncode=0, stdout='test-value\n')) as run:
            value = collector.dashboard_password('custom', {'password_command': ['secret-tool', 'lookup', 'label', 'a; b']})
        self.assertEqual(value, 'test-value')
        self.assertEqual(run.call_args.args[0][-1], 'a; b')
        self.assertNotIn('shell', run.call_args.kwargs)

    def test_missing_credential_does_not_fall_back_to_another_router(self):
        with self.assertRaisesRegex(RuntimeError, 'Configure'):
            collector.dashboard_password('custom', {})
        with patch.dict(collector.os.environ, {}, clear=True):
            with self.assertRaisesRegex(RuntimeError, 'indisponível'):
                collector.dashboard_password('custom', {'password_env': 'MISSING'})

    def test_slow_credential_command_reports_busy_vault(self):
        with patch.object(collector.subprocess, 'run', side_effect=collector.subprocess.TimeoutExpired('cofre', 180)):
            with self.assertRaisesRegex(RuntimeError, 'Cofre ocupado'):
                collector.dashboard_password('custom', {'password_command': ['cofre']})

    def test_ssh_uses_configured_host_container_and_port(self):
        payload = SimpleNamespace(returncode=0, stdout='{"connections":[],"stats":{},"quotas":{}}')
        with patch.object(collector.subprocess, 'run', return_value=payload) as run:
            collector.ssh_gateway('custom', {'ssh_host': 'server', 'container': 'router;echo unsafe', 'api_port': 1234}, {})
        self.assertEqual(run.call_args.args[0][-2], 'server')
        self.assertEqual(run.call_args.args[0][-1], "docker exec -i 'router;echo unsafe' node")
        self.assertIn('port:1234', run.call_args.kwargs['input'])

    def test_only_explicit_connection_fields_survive(self):
        result = collector.clean_connections({'connections': [{'id': 'a', 'email': 'a@example.com', 'providerSpecificData': {'accessToken': 'private'}, 'refreshToken': 'private'}]})
        self.assertEqual(result[0]['email'], 'a@example.com')
        self.assertNotIn('providerSpecificData', result[0])
        self.assertNotIn('refreshToken', result[0])

    def test_historical_account_gets_zero_in_available_empty_period(self):
        result = collector.normalize('R', {}, [], {'today': {'byAccount': {}}, 'all': {'byAccount': {'model': {'connectionId': 'old', 'accountName': 'Old', 'provider': 'codex', 'requests': 4, 'promptTokens': 100}}}}, {}, {})
        account = result['accounts'][0]
        self.assertFalse(account['active'])
        self.assertEqual(account['periods']['today']['tokens'], 0)
        self.assertEqual(account['periods']['all']['requests'], 4)
        self.assertNotIn('7d', account['periods'])

    def test_failed_refresh_retains_previous_quota_and_timestamp(self):
        connection = {'id': 'a', 'email': 'a@example.com', 'isActive': True}
        previous = {'accounts': [{'id': 'a', 'quotas': [{'label': 'session', 'percent': 40}], 'quotaUpdatedAt': 123}]}
        result = collector.normalize('R', {}, [connection], {}, {'a': {'error': 'Falha'}}, previous)
        account = result['accounts'][0]
        self.assertEqual(account['quotas'][0]['percent'], 40)
        self.assertEqual(account['quotaUpdatedAt'], 123)
        self.assertEqual(account['quotaError'], 'Falha')
        self.assertEqual(account['email'], 'a@example.com')

    def test_quota_keeps_used_and_total_for_the_counter(self):
        result = collector.clean_quotas({'quotas': {'session (5h)': {'used': 52, 'total': 100, 'resetAt': '2026-10-16T12:00:00Z'}, 'weekly': {'remainingPercentage': 70}}})
        self.assertEqual(result[0]['percent'], 52)
        self.assertEqual((result[0]['used'], result[0]['total']), (52, 100))
        self.assertEqual(result[1]['percent'], 30)
        self.assertIsNone(result[1]['total'])

if __name__ == '__main__':
    unittest.main()
