import importlib.util
from pathlib import Path
import unittest

spec = importlib.util.spec_from_file_location('collector', Path(__file__).parents[1] / 'collect.py')
collector = importlib.util.module_from_spec(spec)
spec.loader.exec_module(collector)

class PlanTest(unittest.TestCase):
    def test_plan_is_preserved_when_display_name_is_email(self):
        c = {'id': 'a', 'provider': 'claude', 'name': '(5X) Account', 'email': 'a@example.com'}
        clean = collector.clean_connections({'connections': [c]})
        result = collector.normalize('A', {}, clean, {}, {}, {})['accounts'][0]
        self.assertEqual(result['name'], 'a@example.com')
        self.assertEqual(result['plan'], '5x')

    def test_explicit_plan_override_and_unknown_plan(self):
        c = {'id': 'a', 'provider': 'claude', 'name': 'Account', 'email': 'A@example.com'}
        self.assertEqual(collector.account_plan(c, {}), '')
        self.assertEqual(collector.account_plan(c, {'account_plans': {'a@example.com': '20x'}}), '20x')
        self.assertEqual(collector.account_plan({'provider': 'claude', 'name': '(20x) Account'}, {}), '20x')
        self.assertEqual(collector.account_plan({'provider': 'claude', 'name': '(25x) Account'}, {}), '')
        self.assertEqual(collector.account_plan({'provider': 'codex', 'name': '(5x)'}, {}), '')

    def test_name_and_configured_alias_supply_identity_without_exposing_secrets(self):
        self.assertEqual(collector.connection_email({'name': '(20x) Agents (ACCOUNT@example.com)'}, {}), 'account@example.com')
        self.assertEqual(collector.connection_email({'name': 'Account 2'}, {}), '')
        self.assertEqual(collector.connection_email({'id': 'alias', 'name': 'Account 2'}, {'account_emails': {'alias': 'a@example.com'}}), 'a@example.com')
        self.assertEqual(collector.account_plan({'provider':'claude', 'name':'a@example.com'}, {'account_plans': {'a@example.com':'20x'}}), '20x')
