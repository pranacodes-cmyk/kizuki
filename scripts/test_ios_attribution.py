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


if __name__ == "__main__":
    unittest.main()