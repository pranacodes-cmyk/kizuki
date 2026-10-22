"""Composes store screenshots: caption + framed app screen. Output: store/screenshots/{ios,play}/NN.png"""
import asyncio, base64
from pathlib import Path
from playwright.async_api import async_playwright
FONTS = '/dev-server/mobile/assets/fonts'
RAW = Path('/tmp/browser/shots/raw')
SHOTS = [
    ('ios_1_feed', 'Learn Japanese from <em>real videos</em>', 'Vlogs, dramas and street interviews with tappable subtitles'),
    ('ios_2_word', 'Tap any word to <em>understand it</em>', 'Meaning, reading and examples in one tap'),
    ('ios_3_review', 'Never <em>forget</em> a word', 'Smart flashcards that replay the original clip'),
    ('ios_4_vocab', 'Watch your <em>vocabulary</em> grow', 'Every word you save, level by level'),
    ('ios_5_profile', 'Build a daily <em>habit</em>', 'Streaks and goals that keep you going'),
    ('ios_6_explore', '3,000+ clips for <em>your level</em>', 'Search by word, JLPT level, topic or grammar'),
]
def font(w):
    return f"@font-face{{font-family:N;font-weight:{w};src:url(data:font/ttf;base64,{base64.b64encode(open(f'{FONTS}/Nunito-{w}.ttf','rb').read()).decode()})}}"
FONTCSS = ''.join(font(w) for w in (700, 800, 900))
def page(img, title, sub, w, h, dev_w, top, tsize, ssize):
    b64 = base64.b64encode(open(RAW / f'{img}.png', 'rb').read()).decode()
    return f"""<html><head><style>{FONTCSS}
    *{{margin:0;padding:0;box-sizing:border-box}}
    body{{width:{w}px;height:{h}px;overflow:hidden;font-family:N;background:#16171B;color:#F5F2ED;position:relative}}
    .glow{{position:absolute;border-radius:50%;filter:blur(60px)}}
    .cap{{position:absolute;left:0;right:0;top:{top}px;text-align:center;padding:0 {w*0.07:.0f}px}}
    h1{{font-weight:900;font-size:{tsize}px;line-height:1.12;letter-spacing:-0.01em}}
    h1 em{{font-style:normal;color:#FF8A3D}}
    p{{margin-top:{tsize*0.35:.0f}px;font-weight:700;font-size:{ssize}px;line-height:1.35;color:#9D9CA4}}
    .dev{{position:absolute;left:50%;transform:translateX(-50%);bottom:{-dev_w*0.06:.0f}px;width:{dev_w}px;border-radius:{dev_w*0.13:.0f}px;padding:{dev_w*0.025:.1f}px;background:#0E0F12;
         box-shadow:0 0 0 {max(2,dev_w*0.008):.1f}px #383942, 0 {dev_w*0.12:.0f}px {dev_w*0.25:.0f}px -{dev_w*0.06:.0f}px rgba(0,0,0,.7), 0 0 {dev_w*0.4:.0f}px rgba(255,138,61,.12)}}
    .dev img{{display:block;width:100%;border-radius:{dev_w*0.11:.0f}px}}
    </style></head><body>
    <div class="glow" style="width:{w*0.9}px;height:{w*0.9}px;left:-{w*0.35}px;top:-{w*0.3}px;background:rgba(255,138,61,.16)"></div>
    <div class="glow" style="width:{w}px;height:{w}px;right:-{w*0.45}px;bottom:{h*0.05}px;background:rgba(200,96,28,.14)"></div>
    <div class="cap"><h1>{title}</h1><p>{sub}</p></div>
    <div class="dev"><img src="data:image/png;base64,{b64}"></div></body></html>"""
async def main():
    async with async_playwright() as pw:
        b = await pw.chromium.launch(headless=True)
        for kind, (w, h, dev_w, top, ts, ss) in {'ios': (430, 932, 318, 64, 37, 17), 'play': (360, 640, 236, 40, 28, 13.5)}.items():
            out = Path(f'/dev-server/store/screenshots/{kind}'); out.mkdir(parents=True, exist_ok=True)
            ctx = await b.new_context(viewport={'width': w, 'height': h}, device_scale_factor=3)
            pg = await ctx.new_page()
            for i, (img, t, s) in enumerate(SHOTS, 1):
                await pg.set_content(page(img, t, s, w, h, dev_w, top, ts, ss)); await pg.wait_for_timeout(300)
                await pg.screenshot(path=str(out / f'{i:02d}.png'))
            await ctx.close()
        # Play feature graphic 1024x500
        icon = base64.b64encode(open('/dev-server/mobile/ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-1024x1024@1x.png','rb').read()).decode()
        s1 = base64.b64encode(open(RAW/'ios_1_feed.png','rb').read()).decode()
        s2 = base64.b64encode(open(RAW/'ios_2_word.png','rb').read()).decode()
        html = f"""<html><head><style>{FONTCSS}*{{margin:0;padding:0;box-sizing:border-box}}
        body{{width:1024px;height:500px;overflow:hidden;font-family:N;background:#16171B;color:#F5F2ED;position:relative}}
        .glow{{position:absolute;border-radius:50%;filter:blur(70px)}}
        .l{{position:absolute;left:64px;top:0;bottom:0;display:flex;flex-direction:column;justify-content:center;width:470px}}
        .l img{{width:112px;height:112px;border-radius:28px;box-shadow:0 0 0 2px #383942}}
        h1{{margin-top:22px;font-weight:900;font-size:58px;letter-spacing:-0.01em}}
        h2{{margin-top:6px;font-weight:800;font-size:30px;line-height:1.2;color:#FF8A3D}}
        p{{margin-top:14px;font-weight:700;font-size:19px;color:#9D9CA4;line-height:1.4}}
        .ph{{position:absolute;width:218px;border-radius:30px;padding:6px;background:#0E0F12;box-shadow:0 0 0 2px #383942,0 30px 60px -10px rgba(0,0,0,.7)}}
        .ph img{{display:block;width:100%;border-radius:25px}}</style></head><body>
        <div class="glow" style="width:600px;height:600px;left:-260px;top:-300px;background:rgba(255,138,61,.18)"></div>
        <div class="glow" style="width:520px;height:520px;right:-120px;bottom:-320px;background:rgba(200,96,28,.2)"></div>
        <div class="l"><img src="data:image/png;base64,{icon}"><h1>Kizuki</h1><h2>Learn Japanese from real clips</h2><p>Tap any word · Smart flashcards · Every JLPT level</p></div>
        <div class="ph" style="left:590px;top:70px;transform:rotate(-6deg)"><img src="data:image/png;base64,{s1}"></div>
        <div class="ph" style="left:790px;top:40px;transform:rotate(5deg)"><img src="data:image/png;base64,{s2}"></div>
        </body></html>"""
        ctx = await b.new_context(viewport={'width': 1024, 'height': 500}, device_scale_factor=1)
        pg = await ctx.new_page(); await pg.set_content(html); await pg.wait_for_timeout(300)
        await pg.screenshot(path='/dev-server/store/play/feature-graphic.png')
        await b.close()
asyncio.run(main())
