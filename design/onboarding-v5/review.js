(() => {
  'use strict';
  const flow=window.ONBOARDING_FLOW, captures=window.STUDY_GUARD_CAPTURES||{};
  const board=document.getElementById('board'), viewer=document.getElementById('viewer'), player=document.getElementById('player');
  let mode='studyguard',phase='All',current=0,previousFocus;
  const states=flow.map(()=>0);
  const phaseNames=['Value','Personalize','Time back','Your plan','Setup'];
  const el=(tag,cls,text)=>{const e=document.createElement(tag);if(cls)e.className=cls;if(text!==undefined)e.textContent=text;return e};
  const matches=s=>phase==='All'||(phase==='Round 1'&&s.revised)||s.phase===phase||(phase==='Setup'&&s.phase==='Subscribe');
  function captureFor(s,reference=false){
    const i=flow.indexOf(s),state=states[i];
    if(reference)return s.reference[state]?'reference/'+s.reference[state]:s.reference[0]?'reference/'+s.reference[0]:null;
    return captures[s.id]?.[state]||`screenshots/${s.id}-${state}.png`;
  }
  function shot(s,reference=false,large=false){
    const path=captureFor(s,reference), container=el(large?'div':'button',large?'large-shot':'phone-button');
    if(!large){container.type='button';container.setAttribute('aria-label',`Enlarge ${s.title}${reference?' original':''}`);container.onclick=()=>openViewer(flow.indexOf(s))}
    if(path){const img=el('img');img.src=path+'?v=20261021-setup-artwork';img.alt=`${reference?'OneThing original':captures[s.id]?.[states[flow.indexOf(s)]]?'Study Guard native':'Study Guard HTML preview'}: ${s.title}, ${s.states[states[flow.indexOf(s)]]}`;img.width=368;img.height=800;img.loading=large?'eager':'lazy';container.append(img)}
    else{const empty=el('div','empty-reference');empty.append(el('b','',s.title),el('span','','Added in the latest SwiftUI source. No saved original capture.'));container.append(empty)}
    return container;
  }
  function stateButtons(s,target,onChange){
    target.replaceChildren();if(s.states.length<2)return;
    const i=flow.indexOf(s);
    s.states.forEach((name,n)=>{const b=el('button','',name);b.type='button';b.setAttribute('aria-pressed',states[i]===n);b.onclick=()=>{states[i]=n;onChange()};target.append(b)});
  }
  function render(){
    board.replaceChildren();board.classList.toggle('compare-mode',mode==='compare');
    phaseNames.forEach((name,p)=>{
      const list=flow.filter(s=>(s.phase===name||(name==='Setup'&&s.phase==='Subscribe'))&&matches(s));if(!list.length)return;
      const section=el('section','phase-section'),heading=el('div','phase-heading');
      heading.append(el('span','phase-index',`0${p+1}`),el('h2','',name==='Setup'?'Offer & setup':name),el('span','rule'));
      section.append(heading);const grid=el('div','screens');
      list.forEach(s=>{
        const i=flow.indexOf(s),card=el('article','screen-card'),caption=el('div','screen-caption');
        caption.append(el('span','',String(i+1).padStart(2,'0')),el('h3','',s.title));card.append(caption);
        if(mode==='compare'){const pair=el('div','compare-row');[false,true].forEach(ref=>{const column=el('div');column.append(el('p','compare-label',ref?'OneThing original':'Study Guard'),shot(s,ref));pair.append(column)});card.append(pair)}
        else card.append(shot(s,mode==='reference'));
        const stateRow=el('div','states');stateButtons(s,stateRow,render);card.append(stateRow);
        const native=captures[s.id]?.[states[i]];
        const label=mode==='reference'?(s.referenceStale?'Older source capture · see note':'Original iOS capture'):(native?'Native Study Guard capture':'HTML layout preview');
        card.append(el('p','capture-tag',label),el('p','screen-note',s.note));grid.append(card);
      });
      section.append(grid);board.append(section);
    });
    document.getElementById('result-count').textContent=`${flow.filter(matches).length} screens · in app order`;
  }
  function openViewer(i){previousFocus=document.activeElement;current=i;updateViewer();viewer.showModal();document.getElementById('close').focus()}
  function updateViewer(){
    const s=flow[current];document.getElementById('viewer-counter').textContent=`SCREEN ${String(current+1).padStart(2,'0')} / ${flow.length} · ${s.phase.toUpperCase()}`;
    document.getElementById('viewer-title').textContent=s.title;
    const content=document.getElementById('viewer-content');content.replaceChildren();
    if(mode==='compare'){content.append(shot(s,false,true),shot(s,true,true))}
    else content.append(shot(s,mode==='reference',true));
    document.getElementById('viewer-note').textContent=(mode!=='reference'&&!captures[s.id]?.[states[current]]?'This additional state is an HTML preview; the first state is a native iOS capture. ':'')+s.note;
    stateButtons(s,document.getElementById('viewer-states'),()=>{render();updateViewer()});
    document.getElementById('prev').disabled=current===0;document.getElementById('next').disabled=current===flow.length-1;
  }
  document.querySelectorAll('[data-mode]').forEach(b=>b.onclick=()=>{mode=b.dataset.mode;document.querySelectorAll('[data-mode]').forEach(x=>x.setAttribute('aria-pressed',x===b));render()});
  document.querySelectorAll('[data-phase]').forEach(b=>b.onclick=()=>{phase=b.dataset.phase;document.querySelectorAll('[data-phase]').forEach(x=>x.setAttribute('aria-pressed',x===b));render()});
  document.getElementById('size').oninput=e=>document.documentElement.style.setProperty('--phone-width',e.target.value+'px');
  document.getElementById('print').onclick=()=>window.print();
  document.getElementById('close').onclick=()=>viewer.close();
  viewer.addEventListener('close',()=>previousFocus?.focus());
  document.getElementById('prev').onclick=()=>{if(current>0){current--;updateViewer()}};
  document.getElementById('next').onclick=()=>{if(current<flow.length-1){current++;updateViewer()}};
  viewer.addEventListener('keydown',e=>{if(e.key==='ArrowLeft'||e.key==='ArrowRight'){e.preventDefault();current=Math.max(0,Math.min(flow.length-1,current+(e.key==='ArrowRight'?1:-1)));updateViewer()}});
  [viewer,player].forEach(dialog=>dialog.addEventListener('click',e=>{if(e.target!==dialog)return;const b=dialog.getBoundingClientRect();if(e.clientX<b.left||e.clientX>b.right||e.clientY<b.top||e.clientY>b.bottom)dialog.close()}));
  const jump=document.getElementById('jump');flow.forEach((s,i)=>{const o=el('option','',`${String(i+1).padStart(2,'0')} · ${s.title}`);o.value=s.id;jump.append(o)});
  const preview=document.getElementById('preview');
  const go=()=>preview.contentWindow.postMessage({type:'sg-preview-go',id:Number(jump.value)},location.protocol==='file:'?'*':location.origin);
  jump.onchange=go;
  document.getElementById('walkthrough').onclick=()=>{previousFocus=document.activeElement;preview.src='screen.html?interactive=1&id=800&v=20261021-setup-artwork';jump.value='800';player.showModal();document.getElementById('close-player').focus()};
  document.getElementById('close-player').onclick=()=>player.close();
  document.getElementById('player-next').onclick=()=>{jump.selectedIndex=Math.min(flow.length-1,jump.selectedIndex+1);go()};
  player.addEventListener('close',()=>{preview.src='about:blank';previousFocus?.focus()});
  window.addEventListener('message',e=>{if(e.source===preview.contentWindow&&e.origin===location.origin&&e.data?.type==='sg-preview-step')jump.value=e.data.id});
  render();
})();
