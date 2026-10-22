import asyncio, json, sys
from pathlib import Path
from playwright.async_api import async_playwright
OUT = Path('/tmp/browser/shots/raw')
SEED = json.load(open('/tmp/browser/shots/seed.json'))
W, H = int(sys.argv[1]) if len(sys.argv) > 1 else 430, int(sys.argv[2]) if len(sys.argv) > 2 else 932
TAG = sys.argv[3] if len(sys.argv) > 3 else 'ios'
async def main():
    async with async_playwright() as p:
        b = await p.chromium.launch(headless=True, args=['--autoplay-policy=no-user-gesture-required'])
        ctx = await b.new_context(viewport={'width': W, 'height': H}, device_scale_factor=3, is_mobile=True, has_touch=True)
        pg = await ctx.new_page()
        await pg.goto('http://localhost:8080/privacy', wait_until='domcontentloaded')
        await pg.evaluate('([k,v]) => localStorage.setItem(k, v)', ['mimi-state-v1', json.dumps(SEED, ensure_ascii=False)])
        await pg.goto('http://localhost:8080/feed', wait_until='networkidle'); await pg.wait_for_timeout(9000)
        await pg.screenshot(path=str(OUT / f'{TAG}_0_feed.png'))
        await pg.goto('http://localhost:8080/clip/JTausXr-hMg-373', wait_until='networkidle'); await pg.wait_for_timeout(6000)
        await pg.locator('button', has_text='ryokou').first.click()
        await pg.wait_for_timeout(2500)
        await pg.screenshot(path=str(OUT / f'{TAG}_2_word.png'))
        await pg.goto('http://localhost:8080/review', wait_until='networkidle'); await pg.wait_for_timeout(2500)
        await pg.get_by_text('Tap to reveal').click(); await pg.wait_for_timeout(2500)
        await pg.screenshot(path=str(OUT / f'{TAG}_3_review.png'))
        print('ok')
        await b.close()
asyncio.run(main())
