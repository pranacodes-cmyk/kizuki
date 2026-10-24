"""Report actual packaged bytes without extracting APKs or reading credentials."""
import collections
import sys
import zipfile
from pathlib import Path


def report(path):
    groups = collections.defaultdict(int)
    with zipfile.ZipFile(path) as archive:
        for entry in archive.infolist():
            name = entry.filename
            if name.startswith('lib/'):
                group = 'Native ' + name.split('/')[1]
            elif name.startswith('assets/flutter_assets/assets/'):
                group = 'Bundled ' + name.split('/')[3]
            elif name.endswith('.dex'):
                group = 'Plugin/application code'
            else:
                group = 'Other resources'
            groups[group] += entry.compress_size
    return groups


if __name__ == '__main__':
    for arg in sys.argv[1:]:
        path = Path(arg)
        print(f'\n### {path.name}: {path.stat().st_size / 1_000_000:.2f} MB')
        print('| Packaged area | MB |\n|---|---:|')
        for name, size in sorted(report(path).items(), key=lambda row: row[1], reverse=True):
            print(f'| {name} | {size / 1_000_000:.2f} |')