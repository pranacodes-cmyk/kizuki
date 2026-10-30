"""Install only profiles that actually grant the widget App Group.

CI uses its existing Apple distribution certificate. App Group registration and
membership for both IDs must be completed in Apple Developer first; the documented
ASC API does not expose App Group creation/membership.
"""
import argparse
import base64
import datetime
import os
import pathlib
import plistlib
import subprocess
from common import asc

GROUP = 'group.com.kizukijapan.app.widgets'
TARGETS = [('com.kizukijapan.app', 'Kizuki App Store CI'), ('com.kizukijapan.app.widgets', 'Kizuki Widgets App Store CI')]

def exact_bundle_ids(candidates, bundle):
    # Apple's identifier filter can also return a prefixed extension identifier.
    return [item for item in candidates if item.get('attributes', {}).get('identifier') == bundle]

def profile_problem(profile, bundle):
    ent = profile.get('Entitlements', {})
    if GROUP not in ent.get('com.apple.security.application-groups', []):
        return f'{bundle}: App Group {GROUP} is not assigned. Assign it to both App IDs in Apple Developer.'
    if not ent.get('application-identifier', '').endswith('.' + bundle):
        return f'{bundle}: wrong application identifier'
    expiration = profile.get('ExpirationDate')
    if not isinstance(expiration, datetime.datetime) or expiration.replace(tzinfo=datetime.timezone.utc) <= datetime.datetime.now(datetime.timezone.utc):
        return f'{bundle}: expired profile'
    return None

def install_profiles(seed_path):
    # Match the certificate embedded in the app's existing CI profile, never pick
    # a random distribution certificate that the CI keychain cannot sign with.
    seed = plistlib.loads(subprocess.check_output(['security', 'cms', '-D', '-i', seed_path]))
    certs = seed.get('DeveloperCertificates', [])
    candidates = asc('GET', '/v1/certificates', params={'limit': 100})['data']
    matching = [c for c in candidates if base64.b64decode(c['attributes']['certificateContent']) in certs]
    if len(matching) != 1:
        raise RuntimeError('Cannot uniquely match the installed CI signing certificate. No profiles changed.')
    for bundle, name in TARGETS:
        ids = exact_bundle_ids(asc('GET', '/v1/bundleIds', params={'filter[identifier]': bundle})['data'], bundle)
        if len(ids) != 1:
            raise RuntimeError(f'Register the widget App ID {bundle} first.')
        bid = ids[0]['id']
        # A temporary uniquely named profile avoids deleting a working old profile.
        profile = asc('POST', '/v1/profiles', {'data': {'type': 'profiles', 'attributes': {
            'name': f'{name} widget-check {os.environ.get("GITHUB_RUN_ID", "local")}', 'profileType': 'IOS_APP_STORE'},
            'relationships': {'bundleId': {'data': {'type': 'bundleIds', 'id': bid}},
                              'certificates': {'data': [{'type': 'certificates', 'id': matching[0]['id']}]}}}})['data']
        raw = base64.b64decode(profile['attributes']['profileContent'])
        temp = pathlib.Path(os.environ.get('RUNNER_TEMP', '/tmp')) / (bundle + '.mobileprovision')
        temp.write_bytes(raw)
        decoded = plistlib.loads(subprocess.check_output(['security', 'cms', '-D', '-i', str(temp)]))
        problem = profile_problem(decoded, bundle)
        if problem:
            asc('DELETE', '/v1/profiles/' + profile['id'])
            raise RuntimeError(problem + ' Refusing to build an incompatible signed IPA.')
        for directory in ['Library/MobileDevice/Provisioning Profiles', 'Library/Developer/Xcode/UserData/Provisioning Profiles']:
            dest = pathlib.Path.home() / directory
            dest.mkdir(parents=True, exist_ok=True)
            (dest / (decoded['UUID'] + '.mobileprovision')).write_bytes(raw)
        # Export by UUID; update both target build settings and export dictionary.
        project = pathlib.Path('ios/Runner.xcodeproj/project.pbxproj')
        text = project.read_text().replace(f'PROVISIONING_PROFILE_SPECIFIER = "{name}";', f'PROVISIONING_PROFILE_SPECIFIER = "{decoded["UUID"]}";')
        project.write_text(text)
        export = pathlib.Path('ios/ExportOptions.plist')
        options = plistlib.loads(export.read_bytes())
        options['provisioningProfiles'][bundle] = decoded['UUID']
        export.write_bytes(plistlib.dumps(options))
        print(f'Validated widget App Group and installed profile for {bundle}.')

if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--seed-profile', required=True)
    args = parser.parse_args()
    install_profiles(args.seed_profile)