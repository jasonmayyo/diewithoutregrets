/* Usage: NODE_PATH=<bundled node_modules> node capture-preview.cjs [base URL]
 * Captures the optional HTML companion. Native captures are registered separately.
 */
const {chromium}=require('playwright');
const fs=require('node:fs/promises');
const path=require('node:path');
let browser;
(async()=>{
  const base=process.argv[2]||'http://127.0.0.1:4174';
  browser=await chromium.launch({headless:true,channel:'chrome'});
  const page=await browser.newPage({viewport:{width:368,height:800},deviceScaleFactor:2,reducedMotion:'reduce'});
  const failures=[];
  page.on('pageerror',e=>failures.push(e.message));
  page.on('response',r=>{if(r.status()>=400)failures.push(`${r.status()} ${r.url()}`)});
  await page.goto(base+'/screen.html');
  const flow=await page.evaluate(()=>ONBOARDING_FLOW);
  await fs.mkdir(path.join(__dirname,'screenshots'),{recursive:true});
  let count=0;
  for(const screen of flow){
    for(let state=0;state<screen.states.length;state++){
      await page.goto(`${base}/screen.html?id=${screen.id}&state=${state}`);
      await page.waitForFunction(()=>window.previewReady);
      await page.evaluate(()=>Promise.all([...document.images].map(i=>i.decode().catch(()=>{}))));
      const broken=await page.locator('img').evaluateAll(images=>images.filter(i=>!i.complete||i.naturalWidth===0).map(i=>i.src));
      if(broken.length)failures.push(...broken);
      await page.screenshot({path:path.join(__dirname,'screenshots',`${screen.id}-${state}.png`)});
      count++;
    }
  }
  await page.goto(base+'/screen.html?interactive=1&id=803');
  await page.getByText('Postgraduate',{exact:true}).click();
  await page.getByRole('button',{name:'Continue',exact:true}).click();
  await page.waitForFunction(()=>document.title.startsWith('Your scrolling concern'));
  await page.goto(base+'/screen.html?interactive=1&id=820');
  await page.waitForFunction(()=>document.title.startsWith('Your exam subject'));
  await page.getByLabel('Which subject is your next exam for?',{exact:true}).fill('Chemistry');
  await page.getByRole('button',{name:'Continue',exact:true}).click();
  await page.waitForFunction(()=>document.title.startsWith('Your next exam'));
  await page.goto(base+'/screen.html?interactive=1&id=812');
  for(const [position,cards] of [[0,5],[1,10],[2,20]]){
    await page.getByRole('slider').fill(String(position));
    if(await page.locator('#rule-card-count').innerText()!==String(cards))failures.push('Study rule selection');
    const hours=await page.locator('.dial-number').innerText();
    if(!Number.isFinite(Number(hours.replace(/,/g,''))))failures.push('Study hours projection');
  }
  await browser.close();
  console.log(JSON.stringify({screens:flow.length,capturedStates:count,failures:[...new Set(failures)]},null,2));
  if(failures.length)process.exitCode=1;
})().catch(async e=>{console.error(e);await browser?.close();process.exitCode=1});
