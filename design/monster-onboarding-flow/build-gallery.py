"""Build the standalone HTML screenshot walkthrough from screenshots.json."""
import json
from html import escape
from pathlib import Path

ROOT = Path(__file__).resolve().parent
screens = json.loads((ROOT / 'screenshots.json').read_text())
for screen in screens:
    assert (ROOT / screen['file']).is_file(), screen['file']

groups = [
    ('intro', '01', 'Show the product, then personalize', 'Welcome → two visual steps → personalize → gender → age → phone time → time estimate → choose a buddy.'),
    ('chat', '02', 'Let your monster take over', 'Only unanswered questions. Notes are uploaded before the exam date, and the subject is detected from them. Example: Alex · Cell Biology.'),
    ('purchase', '03', 'Choose a subscription', 'The existing paywall sits between practice and real app guarding.'),
    ('setup', '04', 'Finish setup with your buddy', 'Read-only native UI previews. In the app, these follow verified purchase or restore.'),
]
sections = []
for key, number, title, description in groups:
    cards = []
    for item in [s for s in screens if s['section'] == key]:
        badge = '<span class="badge">Setup preview</span>' if key == 'setup' else ''
        animation = f"animations/{item['id']}.mp4"
        video_attribute = f' data-video="{animation}"' if (ROOT / animation).is_file() else ''
        if video_attribute:
            badge = '<span class="badge">Animated · tap to play</span>'
        cards.append(f'''<li id="step-{item['number']}">
            <div class="card-heading"><span class="number">{item['number']:02}</span><h3>{escape(item['title'])}</h3>{badge}</div>
            <a class="shot" href="{item['file']}"{video_attribute} data-title="{item['number']:02} · {escape(item['title'], quote=True)}" aria-label="Enlarge {escape(item['title'], quote=True)}">
              <img src="{item['file']}" alt="{escape(item['title'], quote=True)} · actual iPhone app screen" width="1206" height="2622" loading="lazy">
            </a><p class="caption">{escape(item['note'])}</p></li>''')
    sections.append(f'''<section id="{key}" aria-labelledby="{key}-title">
      <div class="section-heading"><span class="section-number">{number}</span><div><h2 id="{key}-title">{title}</h2><p>{description}</p></div></div>
      <ol class="screens">{''.join(cards)}</ol></section>''')

page = '''<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<meta name="description" content="The current Study Guard onboarding, screen by screen, with native iPhone screenshots.">
<title>Study Guard · Onboarding screenshots</title>
<style>
:root{color-scheme:light;--ink:#19382e;--muted:#66766d;--line:#dce4dd;--paper:#f7f8f3;--mint:#def1d0}
*{box-sizing:border-box}[hidden]{display:none!important}html{scroll-behavior:smooth;scroll-padding-top:20px}body{margin:0;background:var(--paper);color:var(--ink);font:14px/1.5 -apple-system,BlinkMacSystemFont,"Segoe UI",sans-serif}
main{max-width:1500px;margin:auto;padding:44px 36px 60px}header{border-bottom:1px solid var(--line);padding-bottom:24px}.eyebrow{text-transform:uppercase;font-size:11px;letter-spacing:.15em;color:var(--muted);font-weight:650}h1{font-size:clamp(28px,4vw,46px);line-height:1.12;letter-spacing:-.045em;margin:10px 0 12px}header p{color:var(--muted);margin:5px 0;max-width:840px}nav{display:flex;flex-wrap:wrap;gap:8px;margin-top:20px}a{color:inherit}nav a{padding:8px 14px;background:white;border:1px solid var(--line);border-radius:30px;text-decoration:none;font-size:12px}nav a:hover{background:var(--mint)}
section{padding-top:32px}.section-heading{display:flex;gap:14px;align-items:flex-start;margin-bottom:22px}.section-number{font-size:12px;border:1px solid var(--line);border-radius:50%;width:32px;height:32px;display:grid;place-items:center;flex-shrink:0}h2{margin:0;font-size:22px;letter-spacing:-.025em}.section-heading p{color:var(--muted);font-size:12px;margin:4px 0 0}.screens{list-style:none;display:grid;grid-template-columns:repeat(4,minmax(0,1fr));gap:28px 24px;padding:0;margin:0}.screens li{min-width:0}.card-heading{display:flex;gap:8px;align-items:center;min-height:46px;margin-bottom:10px;flex-wrap:wrap}h3{margin:0;font-size:13px;font-weight:650}.number{font-variant-numeric:tabular-nums;color:var(--muted);font-size:11px}.badge{font-size:9px;background:var(--mint);padding:3px 7px;border-radius:20px}.shot{display:block;background:#fff;border:1px solid var(--line);border-radius:24px;overflow:hidden;box-shadow:0 5px 20px #153d2d07;cursor:zoom-in;transition:box-shadow .15s}.shot:hover{box-shadow:0 8px 25px #153d2d18}.shot img{width:100%;height:auto;display:block}.caption{font-size:12px;color:var(--muted);margin:10px 2px 0;min-height:36px}footer{margin-top:38px;padding-top:20px;border-top:1px solid var(--line);color:var(--muted);font-size:12px}footer p{margin:5px 0;max-width:850px}.footer-links{display:flex;gap:18px;margin-top:12px}
dialog{padding:14px;background:var(--paper);color:var(--ink);border:0;border-radius:20px;max-width:calc(100vw - 24px);max-height:calc(100dvh - 24px);overflow:auto}dialog::backdrop{background:#0b2019bd;backdrop-filter:blur(5px)}.viewer-bar{display:flex;align-items:center;gap:16px;justify-content:space-between;margin-bottom:12px}.viewer-bar h2{font-size:14px;max-width:290px}button{font:inherit;color:inherit;background:white;border:1px solid var(--line);padding:8px 12px;border-radius:24px;cursor:pointer}.viewer-buttons{display:flex;gap:6px}.viewer-image{display:block;max-height:calc(100dvh - 115px);max-width:100%;width:auto;height:auto;border-radius:18px;margin:auto}a:focus-visible,button:focus-visible{outline:3px solid #548840;outline-offset:4px}
@media(min-width:1500px){main{padding-inline:50px}}@media(max-width:1050px){.screens{grid-template-columns:repeat(3,minmax(0,1fr));gap:24px 18px}}@media(max-width:740px){main{padding:28px 18px}.screens{grid-template-columns:repeat(2,minmax(0,1fr));gap:20px 14px}.card-heading{min-height:60px;align-content:center}.shot{border-radius:17px}}@media(max-width:440px){.screens{grid-template-columns:minmax(0,1fr)}.card-heading{min-height:30px}.screens li{max-width:345px;width:100%;margin:auto}.caption{min-height:0}}@media(prefers-reduced-motion:reduce){html{scroll-behavior:auto}.shot{transition:none}}@media print{main{padding:0}.screens{grid-template-columns:repeat(3,minmax(0,1fr))}.screens li{break-inside:avoid}nav,dialog{display:none}.shot{box-shadow:none}}
</style></head><body><main>
<header><div class="eyebrow">Study Guard · Current onboarding · 1 November 2026</div><h1>Meet your buddy. Get your time back.</h1>
<p>{{count}} screens and chat moments, in order. Tap any screenshot to enlarge it.</p>
<p>See the product, answer a few questions, then meet your monster. Screenshots use the current native app with sample answers.</p>
<nav aria-label="Flow sections"><a href="#intro">Product introduction</a><a href="#chat">Monster conversation</a><a href="#purchase">Subscription</a><a href="#setup">Setup → Home</a></nav></header>
''' + '\n'.join(sections) + '''
<footer><p>Captured on iPhone 17 Pro. Welcome uses the existing recording placeholder. Chat screenshots are read-only sample states rendered by the actual app.</p>
<p>Setup previews show the app’s questions. The iOS permission dialogs, app picker, and live study round open from those steps. No purchase, authorization or earned reward was performed for these captures.</p>
<div class="footer-links"><a href="flow-outline.html">Text flow outline</a><a href="screenshots.json">Screenshot manifest</a></div></footer>
</main>
<dialog aria-labelledby="viewer-title"><div class="viewer-bar"><h2 id="viewer-title"></h2><div class="viewer-buttons"><button id="previous" aria-label="Previous screen">←</button><button id="next" aria-label="Next screen">→</button><button id="close">Close</button></div></div><img class="viewer-image" alt=""><video class="viewer-image" controls muted loop playsinline hidden></video></dialog>
<script>
const shots = [...document.querySelectorAll('.shot')], viewer = document.querySelector('dialog'), photo = viewer.querySelector('img'), video = viewer.querySelector('video'), title = document.getElementById('viewer-title');
let current = 0;
function show(index) {
  current = (index + shots.length) % shots.length; const shot = shots[current];
  photo.src = shot.href; photo.alt = shot.querySelector('img').alt; title.textContent = shot.dataset.title;
  video.pause(); video.removeAttribute('src'); video.hidden = !shot.dataset.video; photo.hidden = !!shot.dataset.video;
  if (shot.dataset.video) { video.src = shot.dataset.video; video.poster = shot.href; video.loop = shot.dataset.video !== 'animations/how-study.mp4'; video.setAttribute('aria-label', shot.dataset.title + ' animation'); }
  if (!viewer.open) viewer.showModal();
  if (shot.dataset.video && !matchMedia('(prefers-reduced-motion: reduce)').matches) video.play().catch(() => {});
}
shots.forEach((shot, i) => shot.addEventListener('click', event => { event.preventDefault(); show(i); }));
document.getElementById('previous').addEventListener('click', () => show(current - 1)); document.getElementById('next').addEventListener('click', () => show(current + 1)); document.getElementById('close').addEventListener('click', () => viewer.close());
viewer.addEventListener('click', event => { if (event.target === viewer) viewer.close(); });
viewer.addEventListener('close', () => video.pause());
viewer.addEventListener('keydown', event => { if (event.key === 'ArrowRight' || event.key === 'ArrowLeft') { event.preventDefault(); show(current + (event.key === 'ArrowRight' ? 1 : -1)); } });
</script></body></html>
'''
(ROOT / 'index.html').write_text(page.replace('{{count}}', str(len(screens))))
print(f'Built index.html with {len(screens)} native screenshots.')
