import tempfile
import unittest
import zipfile
from pathlib import Path
from apk_size_report import report


class SizeReportTest(unittest.TestCase):
    def test_report_separates_architectures_and_assets(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / 'sample.apk'
            with zipfile.ZipFile(path, 'w') as archive:
                archive.writestr('lib/arm64-v8a/libflutter.so', b'x' * 20)
                archive.writestr('lib/x86_64/libflutter.so', b'x' * 30)
                archive.writestr('assets/flutter_assets/assets/data/content.json', b'{}')
            self.assertEqual(report(path)['Native arm64-v8a'], 20)
            self.assertEqual(report(path)['Native x86_64'], 30)
            self.assertEqual(report(path)['Bundled data'], 2)


if __name__ == '__main__':
    unittest.main()