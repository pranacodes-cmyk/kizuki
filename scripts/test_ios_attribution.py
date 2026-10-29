"""Guard native iOS startup settings before Flutter can apply ATT authorization."""
import plistlib
from pathlib import Path
import unittest


class IOSAttributionStartupTest(unittest.TestCase):
    def test_advertiser_id_collection_is_disabled_before_att(self):
        path = Path(__file__).resolve().parents[1] / "mobile/ios/Runner/Info.plist"
        with path.open("rb") as source:
            settings = plistlib.load(source)
        self.assertIs(settings["FacebookAdvertiserIDCollectionEnabled"], False)

    def test_app_privacy_manifest_tracking_is_valid(self):
        # ITMS-91064: NSPrivacyTracking true needs a non-empty domain list (and vice versa).
        path = Path(__file__).resolve().parents[1] / "mobile/ios/Runner/PrivacyInfo.xcprivacy"
        with path.open("rb") as source:
            manifest = plistlib.load(source)
        self.assertIs(manifest["NSPrivacyTracking"], bool(manifest["NSPrivacyTrackingDomains"]))


if __name__ == "__main__":
    unittest.main()