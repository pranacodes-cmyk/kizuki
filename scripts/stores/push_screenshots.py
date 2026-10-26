"""Upload only approved screenshots; never change listing text or app releases."""
import sys
import time
import requests
from common import PLAY_UPLOAD, asc, asc_app, play, play_token
from push_listing import LISTING, IOS_SHOTS, PLAY_SHOTS, _screenshots


def apple():
    app = asc_app()
    versions = asc('GET', f"/v1/apps/{app['id']}/appStoreVersions", params={'filter[platform]': 'IOS', 'limit': 20})['data']
    editable = [v for v in versions if v['attributes']['appStoreState'] in ('PREPARE_FOR_SUBMISSION', 'DEVELOPER_REJECTED', 'REJECTED', 'METADATA_REJECTED')]
    if not editable:
        raise RuntimeError('No editable iOS version; existing screenshots untouched')
    version = editable[0]
    locs = asc('GET', f"/v1/appStoreVersions/{version['id']}/appStoreVersionLocalizations")['data']
    loc = next((l for l in locs if l['attributes']['locale'] == LISTING['apple']['locale']), None)
    if not loc:
        raise RuntimeError('Matching iOS localization missing; existing screenshots untouched')
    if len(IOS_SHOTS) != 6:
        raise RuntimeError('Expected exactly six iOS screenshots')
    _screenshots(loc['id'], 'APP_IPHONE_67', IOS_SHOTS)
    sets = asc('GET', f"/v1/appStoreVersionLocalizations/{loc['id']}/appScreenshotSets")['data']
    target = next(s for s in sets if s['attributes']['screenshotDisplayType'] == 'APP_IPHONE_67')
    for attempt in range(12):
        shots = asc('GET', f"/v1/appScreenshotSets/{target['id']}/appScreenshots")['data']
        states = [s['attributes'].get('assetDeliveryState', {}).get('state') for s in shots]
        if len(shots) == 6 and all(s == 'COMPLETE' for s in states):
            print(f"VERIFIED Apple {version['attributes']['versionString']}: 6 screenshots COMPLETE; not submitted for review", flush=True)
            return
        if any(s == 'FAILED' for s in states):
            raise RuntimeError(f'Apple screenshot processing failed: {states}')
        time.sleep(5)
    raise RuntimeError(f'Apple screenshots uploaded, processing still pending: {states}')


def google():
    if len(PLAY_SHOTS) != 6:
        raise RuntimeError('Expected exactly six Play screenshots')
    edit = play('POST', '/edits', {})['id']
    lang = play('GET', f'/edits/{edit}/details').get('defaultLanguage') or LISTING['play']['language']
    play('DELETE', f'/edits/{edit}/listings/{lang}/phoneScreenshots')
    for path in PLAY_SHOTS:
        response = requests.post(f'{PLAY_UPLOAD}/edits/{edit}/listings/{lang}/phoneScreenshots', params={'uploadType': 'media'}, data=path.read_bytes(), timeout=300,
                                 headers={'Authorization': f'Bearer {play_token()}', 'Content-Type': 'image/png'})
        if response.status_code != 200:
            raise RuntimeError(f'Play screenshot {path.name}: HTTP {response.status_code}')
    play('POST', f'/edits/{edit}:validate')
    try:
        play('POST', f'/edits/{edit}:commit')
    except RuntimeError as error:
        if 'changesNotSentForReview' not in str(error):
            raise
        play('POST', f'/edits/{edit}:commit', params={'changesNotSentForReview': 'true'})
    check = play('POST', '/edits', {})['id']
    try:
        images = play('GET', f'/edits/{check}/listings/{lang}/phoneScreenshots').get('images', [])
        if len(images) != 6:
            raise RuntimeError(f'Play readback: expected 6 screenshots, found {len(images)}')
        print('VERIFIED Play: 6 screenshots committed and read back; binaries/text/icon unchanged', flush=True)
    finally:
        play('DELETE', f'/edits/{check}')


if __name__ == '__main__':
    {'apple': apple, 'play': google}[sys.argv[1]]()