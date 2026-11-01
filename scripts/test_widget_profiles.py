import datetime
import sys
import unittest
sys.path.insert(0, 'scripts/stores')
from widget_profiles import profile_problem, GROUP, exact_bundle_ids

class WidgetProfileTest(unittest.TestCase):
    def test_main_app_does_not_match_widget_extension(self):
        candidates = [{'id': 'app', 'attributes': {'identifier': 'com.kizukijapan.app'}},
                      {'id': 'widget', 'attributes': {'identifier': 'com.kizukijapan.app.widgets'}}]
        self.assertEqual([item['id'] for item in exact_bundle_ids(candidates, 'com.kizukijapan.app')], ['app'])
        self.assertEqual([item['id'] for item in exact_bundle_ids(candidates, 'com.kizukijapan.app.widgets')], ['widget'])
    def profile(self):
        return {'ExpirationDate': datetime.datetime.now(datetime.timezone.utc) + datetime.timedelta(days=30),
                'Entitlements': {'application-identifier': 'TEAM.com.kizukijapan.app.widgets', 'com.apple.security.application-groups': [GROUP]}}
    def test_missing_group_blocks_signing(self):
        p = self.profile(); p['Entitlements'].pop('com.apple.security.application-groups')
        self.assertIn('not assigned', profile_problem(p, 'com.kizukijapan.app.widgets'))
    def test_wrong_bundle_blocks_signing(self):
        self.assertIn('wrong application', profile_problem(self.profile(), 'com.kizukijapan.app'))
    def test_correct_profile_is_accepted(self):
        self.assertIsNone(profile_problem(self.profile(), 'com.kizukijapan.app.widgets'))
    def test_expired_profile_blocks_signing(self):
        p = self.profile(); p['ExpirationDate'] = datetime.datetime(2020, 1, 1)
        self.assertIn('expired', profile_problem(p, 'com.kizukijapan.app.widgets'))

if __name__ == '__main__': unittest.main()