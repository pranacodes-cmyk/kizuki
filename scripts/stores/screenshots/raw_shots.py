import asyncio, json, sys
from pathlib import Path
from playwright.async_api import async_playwright
OUT = Path('/tmp/browser/shots/raw'); OUT.mkdir(exist_ok=True)
SEED = json.load(open('/tmp/browser/shots/seed.json'))
W, H = int(sys.argv[1]) if len(sys.argv) > 1 else 430, int(sys.argv[2]) if len(sys.argv) > 2 else 932
TAG = sys.argv[3] if len(sys.argv) > 3 else 'ios'
CLIP = 'JTausXr-hMg-373'
async def main():
    async with async_playwright() as p:
        b = await p.chromium.launch(headless=True, args=['--autoplay-policy=no-user-gesture-required'])
        ctx = await b.new_context(viewport={'width': W, 'height': H}, device_scale_factor=3, is_mobile=True, has_touch=True)
        pg = await ctx.new_page()
        await pg.goto('http://localhost:8080/privacy', wait_until='domcontentloaded')
        await pg.evaluate('([k,v]) => localStorage.setItem(k, v)', ['mimi-state-v1', json.dumps(SEED, ensure_ascii=False)])
        async def shot(name):
            await pg.screenshot(path=str(OUT / f'{TAG}_{name}.png'))
            print('saved', name)
        await pg.goto(f'http://localhost:8080/clip/{CLIP}', wait_until='networkidle'); await pg.wait_for_timeout(9000)
        await shot('1_feed')
        await pg.goto('http://localhost:8080/vocab', wait_until='networkidle'); await pg.wait_for_timeout(2500)
        await shot('4_vocab')
        await pg.goto('http://localhost:8080/profile', wait_until='networkidle'); await pg.wait_for_timeout(2500)
        await shot('5_profile')
        await pg.goto('http://localhost:8080/explore', wait_until='networkidle'); await pg.wait_for_timeout(3500)
        await shot('6_explore')
        await pg.goto('http://localhost:8080/review', wait_until='networkidle'); await pg.wait_for_timeout(3000)
        await shot('3_review_front')
        await b.close()
asyncio.run(main())
