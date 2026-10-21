(() => {
  'use strict';
  const params=new URLSearchParams(location.search), flow=window.ONBOARDING_FLOW;
  let index=Math.max(0,flow.findIndex(s=>String(s.id)===params.get('id'))), state=Number(params.get('state')||0);
  const interactive=params.get('interactive')==='1';
  let stopExamAnimation=()=>{};
  let stopCommitAnimation=()=>{};
  let stopReviewAnimation=()=>{};
  const examEndings=["Just scrolling on your phone.","Not doing the work you're meant to be doing.","Not going over that one section you never understood.","Not doing that past paper you should have done.","Just… scrolling."];
  let answers={...window.ONBOARDING_DEFAULTS};
  if(interactive){try{answers={...answers,...JSON.parse(sessionStorage.getItem('sg-onboarding-review')||'{}')}}catch{}}
  const today=new Date();today.setHours(0,0,0,0);
  const dateKey=d=>`${d.getFullYear()}-${String(d.getMonth()+1).padStart(2,'0')}-${String(d.getDate()).padStart(2,'0')}`;
  const suggestedExam=new Date(today);suggestedExam.setDate(suggestedExam.getDate()+30);
  answers.examDate ||= dateKey(suggestedExam);
  const escape=t=>String(t).replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
  const subject=()=>escape((answers.subject||'').trim()||'your subject');
  const examDays=()=>{const p=answers.examDate.split('-').map(Number);return Math.max(0,Math.round((Date.UTC(p[0],p[1]-1,p[2])-Date.UTC(today.getFullYear(),today.getMonth(),today.getDate()))/86400000))};
  const examLabel=()=>new Date(answers.examDate+'T12:00:00').toLocaleDateString('en-GB',{day:'numeric',month:'short',year:'numeric'});
  const levelReady=()=>Number.isInteger(answers.studyLevel)&&answers.studyLevel>=0&&answers.studyLevel<4;
  const subjectReady=()=>(answers.subject||'').trim().length>0;
  const root=document.getElementById('screen');
  const img=(name,cls='',alt='')=>`<img class="${cls}" src="assets/${name}" alt="${alt}">`;
  const mascot=(pose='idle',cls='')=>img(pose+'.png','mascot '+cls);
  const apps=(large=false)=>`<div class="apps ${large?'large':''}">${['Facebook','Instagram','Tiktok','Youtube'].map(a=>img(a+'-onboarding.png','',a)).join('')}</div>`;
  const title=t=>`<h1 class="title">${t}</h1>`;
  const p=t=>`<p class="muted">${t}</p>`;
  const cta=(t='Continue',secondary='')=>`${secondary?`<button class="secondary" data-next>${secondary}</button>`:''}<button class="cta ${secondary?'with-secondary':''}" data-next>${t}</button>`;
  const persist=()=>{if(interactive)try{sessionStorage.setItem('sg-onboarding-review',JSON.stringify(answers))}catch{}};
  const baselineHours=()=>[1,3,5,6,4][answers.baseline];
  const format=m=>m<60?`${m}m`:`${Math.floor(m/60)}h${m%60?' '+m%60+'m':''}`;
  const phoneHours=()=>baselineHours()*examDays();
  const studyCards=()=>[5,10,20].includes(answers.studyCards)?answers.studyCards:10;
  const studyRule=()=>`${studyCards()} correct flashcards → 5 minutes`;
  // Scenario: 30 seconds/card, with study + earned scrolling sharing the
  // existing phone-time window rather than adding study on top of it.
  const studyShare=(cards=studyCards())=>(cards*.5)/(cards*.5+5);
  const studyHours=(cards=studyCards())=>phoneHours()*studyShare(cards);
  const studyHoursLabel=(cards=studyCards())=>studyHours(cards).toLocaleString(undefined,{maximumFractionDigits:1});
  const studyNumberSize=(cards=studyCards())=>Math.min(70,198/(studyHoursLabel(cards).length*.62));
  const studyEstimate=(cards=studyCards())=>`<p>Based on ${examDays()} days until your exam and your estimate of ${baselineHours()} hours a day on your phone.</p><p>We assume 30 seconds per correct flashcard: ${cards} cards take about ${cards*.5} minutes of study, followed by 5 minutes of scrolling.</p><p>If those study-and-scroll cycles replace that same phone-time window, about ${studyHoursLabel(cards)} hours shift to studying. Your actual usage and study pace will vary.</p>`;
  const studyDial=(cards)=>{
    const fraction=examDays()>0?studyShare(cards):0;
    return `<svg viewBox="0 0 292 292" aria-hidden="true">${Array.from({length:49},(_,i)=>`<rect class="dial-tick ${fraction>0&&i/48<=fraction?'filled':''}" x="145" y="8" width="2" height="${i%4===0?13:7}" rx="1" transform="rotate(${-135+i/48*270} 146 146)"/>`).join('')}<circle class="dial-marker" cx="146" cy="26" r="3" transform="rotate(${-135+fraction*270} 146 146)"/></svg>`;
  };

  const momentLabel=()=>['before your morning scroll','before scrolling during work or study','before scrolling in a spare moment','before your bedtime scroll'][answers.moment];
  const goal=()=>flow.find(s=>s.key==='studyLevel').choices[answers.studyLevel]||'Your studies';
  const moment=()=>flow.find(s=>s.key==='moment').choices[answers.moment];
  function progressBar(fraction,label='Onboarding progress',extraClass=''){
    const percent=Math.max(0,Math.min(1,Number.isFinite(fraction)?fraction:0))*100;
    return `<div class="progress ${extraClass}" role="progressbar" aria-label="${label}" aria-valuemin="0" aria-valuemax="100" aria-valuenow="${Math.round(percent)}"><i style="width:${percent}%"></i></div>`;
  }
  function chrome(){return `<div class="chrome"><button class="back" data-back aria-label="Previous screen">‹</button>${progressBar(index/(flow.findIndex(s=>s.key==='paywall')-1))}</div>`}
  function question(s){
    return chrome()+`<section class="question"><div class="speech-row">${mascot('clipboard')}<div class="bubble">${s.question}</div></div><div class="choices ${s.key==='habit'?'grid':''}">`+s.choices.map((c,i)=>{
      let illustration='';
      if(s.key==='goal')illustration=`<span class="illustration">${mascot(['clipboard','idle','teaching','idle','teaching','idle'][i])}<span class="badge">${s.icons[i]}</span></span>`;
      if(s.key==='pain')illustration=`<span class="illustration">${img(s.icons[i]+'.png')}</span>`;
      if(s.key==='habit')illustration=`<span class="emoji">${s.icons[i]}</span>`;
      return `<button class="choice ${['goal','pain'].includes(s.key)?'illustrated':''} ${interactive&&answers[s.key]===i?'selected':''}" data-choice="${i}" aria-pressed="${interactive&&answers[s.key]===i}">${illustration}<span>${c}</span></button>`;
    }).join('')+'</div></section>';
  }
  function renderBody(s){
    if(s.key==='studyLevel')return chrome()+`<section class="study-context"><div class="speech-row">${mascot('clipboard')}<div class="bubble">${s.question}</div></div><label class="form-label">YOUR STUDY LEVEL</label><div class="level-choices">${s.choices.map((c,i)=>`<button class="choice ${answers.studyLevel===i?'selected':''}" data-level="${i}" aria-pressed="${answers.studyLevel===i}"><span>${s.icons[i]}</span><span>${c}</span></button>`).join('')}</div></section><button class="cta" data-level-next ${levelReady()?'':'disabled'}>Continue</button>`;
    if(s.key==='subject')return chrome()+`<section class="study-context subject-question"><div class="speech-row">${mascot('clipboard')}<div class="bubble">${s.question}</div></div><label class="form-label" for="subject">EXAM SUBJECT</label><input id="subject" aria-label="Which subject is your next exam for?" maxlength="80" placeholder="e.g. Biology" value="${escape(answers.subject||'')}" autocomplete="off" enterkeyhint="next"></section><button class="cta" data-subject-next ${subjectReady()?'':'disabled'}>Continue</button>`;
    if(s.key==='examDate')return chrome()+`<section class="exam-form"><div class="speech-row">${mascot('clipboard')}<div class="bubble">${s.question}</div></div><h2>Your ${subject()} exam</h2><div class="calendar-preview"><label for="exam-date">EXAM DATE</label><input id="exam-date" type="date" min="${dateKey(today)}" value="${answers.examDate}"><div class="calendar-caption">${examLabel()}</div><strong>${examDays()}</strong><span>days to prepare</span></div>${p("We'll show you how much time your phone could take between now and then.")}</section><button class="cta" data-exam-next>Set my exam date</button>`;
    if(s.question)return question(s);
    switch(s.key){
      case 'welcome':return `<div class="welcome-video"><video src="assets/studyguard-demo.mp4" autoplay muted loop playsinline aria-label="Study Guard product demo"></video></div><section class="welcome-copy">${title('Scroll Less. Study More.')}${p('Turn your study time into screen time.')}</section>${cta('Get Started','I already have an account')}`;
      case 'demo':return `<div class="demo-bg"></div><div class="demo-center">${state===1?'<div class="earn-chip"><span>🧬</span><div><strong>Biology · 10 flashcards</strong><small>Answered correctly · +5 min</small></div></div><div class="earn-chip"><span>⚖️</span><div><strong>Criminal Law · 20 flashcards</strong><small>Answered correctly · +10 min</small></div></div>':'<div style="height:112px"></div>'}${mascot(state===1?'teaching':'sad')}<div class="minutes">${state===1?'15m':'0m'}</div>${apps()}</div><section class="demo-copy">${title(['At the start of every day,<br>your apps lock.','Answer flashcards.<br>Earn screen time.','Time on distracting apps<br>spends your balance.'][state])}${p(['No more mindless morning scrolling.','Correct answers unlock your apps.','The only screen time you get is what you earn.'][state])}</section>${cta()}`;
      case 'generation':return `<section class="generation ${interactive?'playing':state===1?'is-ready':'is-scanning'}" role="img" aria-label="Biology notes are scanned and turned into flashcards automatically. Example: the nucleus stores DNA and controls the cell."><div class="generation-halo"></div><div class="generation-orbit"></div><div class="source-icon source-notes">▤</div><div class="source-icon source-video">▶</div><div class="notes-sheet"><strong><span>▤</span> Biology.pdf</strong><div class="note-lines">${[120,102,128,89,111].map(w=>`<i style="width:${w}px"></i>`).join('')}</div><div class="scan-beam"></div></div><div class="generation-particles"><i></i><i></i><i></i></div><div class="generation-magic"><span class="magic-spark">✦</span><span class="magic-check">✓</span></div>${mascot('teaching','generation-mascot')}<span class="generation-spark spark-left">✦</span><span class="generation-spark spark-right">✦</span><div class="flashcard-deck"><div class="deck-back back-one"></div><div class="deck-back back-two"></div><span class="deck-placeholder">▱</span><div class="demo-flashcard"><div class="flashcard-face card-question"><header>BIOLOGY <span>✦</span></header><h2>What does the<br>nucleus do?</h2></div><div class="flashcard-face card-answer"><header>ANSWER <span>✓</span></header><h2>Stores DNA.<br>Controls the cell.</h2></div></div></div></section><section class="generation-copy">${title('Your notes.<br>Instant flashcards.')}${p('Less prep. More studying.')}</section>${cta()}`;
      case 'empathy':return state===2?`<div class="centered"><div class="stats"><strong>10,000+</strong><small>engineers</small><strong>$100B+</strong><small>in funding</small><strong>PhDs</strong><small>in behavioral psychology</small><p>All working to make sure</p><b>you. can't. stop. scrolling.</b></div></div>${cta()}`:`<div class="centered">${title("It's not your fault.").replace('class="title"','class="title empathy-title"')}${state===1?`<div class="headline-stack">${[1,2,3].map(i=>img(`law${i}.jpg`)).join('')}</div>`:''}</div><button class="tap-hint" data-next>Tap to continue</button>`;
      case 'examCost':{
        const days=examDays(),lost=phoneHours()/24,daysLabel=Number(lost.toFixed(3));
        const columns=Math.min(days,Math.max(8,Math.ceil(Math.sqrt(days*312/200)))),rows=Math.ceil(days/columns);
        const cell=Math.min(319/columns,207/rows,41),gap=Math.min(7,cell*.18),side=Math.max(1,cell-gap);
        const width=columns*cell-gap,height=rows*cell-gap;
        // The SVG pattern keeps one dot per day without adding thousands of DOM nodes.
        const dotPattern=`<pattern id="exam-day-pattern" width="${cell}" height="${cell}" patternUnits="userSpaceOnUse"><rect width="${side}" height="${side}" rx="${Math.min(7,side*.2)}" fill="white"/></pattern>`;
        const fullRows=Math.floor(days/columns),lastRow=days%columns,wholeLost=Math.floor(lost),partial=lost-wholeLost;
        const lostRows=Math.floor(wholeLost/columns),lostColumns=wholeLost%columns;
        const grid=days?`<div class="exam-days-grid" data-columns="${columns}" data-cell="${cell}" data-side="${side}" data-lost="${lost}" role="img" aria-label="${days} days until your exam. Scrolling takes the equivalent of ${daysLabel} full days. Partially filled dots show part of a day."><svg viewBox="0 0 ${width} ${height}" width="${width}" height="${height}" aria-hidden="true"><defs>${dotPattern}<mask id="exam-dot-mask"><rect width="${width}" height="${fullRows*cell}" fill="url(#exam-day-pattern)"/>${lastRow?`<rect y="${fullRows*cell}" width="${lastRow*cell}" height="${side}" fill="url(#exam-day-pattern)"/>`:''}</mask><clipPath id="exam-lost-clip"><rect id="exam-lost-rows" width="${width}" height="${lostRows*cell}"/><rect id="exam-lost-tail" y="${lostRows*cell}" width="${lostColumns*cell+(partial?side*partial:0)}" height="${side}"/></clipPath></defs><g mask="url(#exam-dot-mask)"><rect width="${width}" height="${height}" fill="#14211d29"/><g clip-path="url(#exam-lost-clip)"><rect class="exam-lost-fill" width="${width}" height="${height}" fill="#d9532f"/></g></g></svg></div>`:'';
        return chrome()+`<section class="exam-dots ${interactive?'exam-playing':'exam-static'}"><header><h1>${days?`${days} ${days===1?'day':'days'} until your exam.`:'Your exam is today.'}</h1><p>${days?'Each dot is one day.':'No full days left. Make today count.'}</p>${days?'<div class="exam-legend"><span><i></i>Time ahead</span><span><i></i>On your phone</span></div>':''}</header>${days?`${grid}<div class="exam-pace"><p>At your current pace,</p><div><strong>${daysLabel} ${lost===1?'day':'days'}</strong> will go to your phone.</div></div><div class="exam-hours"><h2>That's ${phoneHours()} ${phoneHours()===1?'hour':'hours'}.</h2><p class="exam-ending" aria-hidden="true">${interactive?'':examEndings[0]}</p><span class="sr-only">${phoneHours()} hours just scrolling on your phone.</span></div><small class="exam-estimate">Based on your estimate of ${baselineHours()} hours a day.</small>`:`<div class="exam-today">${mascot('teaching')}<h2>Make time for one more review.</h2></div>`}</section>${cta('I want that time to study')}`;
      }
      case 'studyRule':{
        const cards=interactive?studyCards():[10,5,20][state]||10,position=[5,10,20].indexOf(cards);
        return chrome()+`<section class="study-rule"><h1 class="title">Take your time back.</h1><div class="rule-dial" role="img" aria-label="Approximately ${studyHoursLabel(cards)} hours of potential extra study time before your ${subject()} exam">${studyDial(cards)}<div class="dial-number" style="font-size:${studyNumberSize(cards)}px">${studyHoursLabel(cards)}</div><div class="dial-unit">hours of <b>EXTRA</b><br>study time</div>${mascot('idle','dial-mascot')}</div><p class="rule-exam">${examDays()===0?'Your exam is today.<br>Every card counts.':`before your ${subject()} exam.`}</p><div class="rule-control"><p class="rule-exchange" aria-label="${cards} correct flashcards earn 5 minutes"><b><span id="rule-card-count">${cards}</span> flashcards</b> → 5 min scroll</p><input class="rule-slider" type="range" min="0" max="2" step="1" value="${position}" aria-label="Flashcards for 5 minutes" aria-valuetext="${cards} correct flashcards" style="--fill:${position*50}%"><div class="rule-stops">${[5,10,20].map((n,i)=>`<button data-rule="${i}" aria-label="${n} flashcards for 5 minutes" aria-pressed="${cards===n}"><b>${n}</b><small>${n===10?'default':'cards'}</small></button>`).join('')}</div><button class="rule-info" data-estimate aria-label="How your extra study time is estimated">ⓘ Estimate · 30 sec per card</button></div></section><dialog class="rule-estimate" aria-labelledby="estimate-title"><h2 id="estimate-title">Your potential study time</h2><div class="estimate-copy">${studyEstimate(cards)}</div><button data-close-estimate>Got it</button></dialog>${cta('Make this my goal')}`;
      }
      case 'method':return `<div class="method-content">${mascot('teaching')}${title('Study Guard Method')}${p("Built on proven science, grounded in behavioral research from the world's leading institutions.")}<div class="research"><p>Based on research in habit formation,<br>digital wellness & behavioral psychology</p><div class="institutions"><span>HARVARD</span>${img('ucl.jpg','','UCL')}${img('sciencedirect.png','','ScienceDirect')}</div></div></div>${cta()}`;
      case 'moreLife':{
        const reviews=[
          {name:'zara prakash',title:'the BEST app for studying',body:'…helped me ace my tests…',store:'India',url:'https://apps.apple.com/in/app/study-guard-study-focus/id6744607430?platform=iphone&see-all=reviews'},
          {name:'Nickname24567444',title:'Good',body:'I loved this, it helped my grades improve!',store:'UK',url:'https://apps.apple.com/gb/app/study-guard-study-focus/id6744607430'},
          {name:'Finé Taylor',title:'Review',body:'…it helps me a lot with studying…',store:'Germany',url:'https://apps.apple.com/de/app/study-guard-study-focus/id6744607430'}
        ];
        const cards=reviews.map(r=>`<article class="review"><header><span>${escape(r.name)}</span><span aria-hidden="true">▤</span></header><b>${escape(r.title)}</b><p>“${escape(r.body)}”</p><a href="${r.url}" target="_blank" rel="noopener">App Store · ${r.store} ↗</a></article>`).join('');
        return `<div class="more-icons" aria-hidden="true"><span>📚</span><span>🧠</span><span>🎓</span><span>⚖️</span><span>🧬</span></div><div class="more-copy">${title('<span id="study-review-phrase">Study More.</span><br>Scroll Less.')}${p('Turn your next scroll<br>into a quick study session.')}</div><div class="review-label">STUDY GUARD · APP STORE REVIEWS</div><div class="study-reviews ${interactive?'reviews-playing':''}"><div class="review-track">${cards}<div class="review-duplicate" aria-hidden="true" inert>${cards}</div></div></div><a class="review-source" href="https://apps.apple.com/gb/app/study-guard-study-focus/id6744607430" target="_blank" rel="noopener">Read Study Guard reviews ↗</a>${cta('I’m ready')}`;
      }
      case 'commitment':{
        return `<div class="commitment">${title('Study first.<br>Scroll after.')}<div class="oath">Before I scroll, I'll answer ${studyCards()} ${subject()} flashcards correctly to earn 5 minutes on my apps.</div><button class="fist-bump" data-fist-bump aria-label="Fist bump the Study Guard mascot to commit">${mascot('fistbump')}<span class="fist-pulse" aria-hidden="true"></span></button></div><div class="commit-hint" aria-live="polite">Tap his fist to commit.</div>`;
      }
      case 'assembly':return `<div class="centered assembly">${mascot('clipboard')}${title('Building your plan...')}<div class="checklist">${[`Your studies: ${goal()}`,`Your subject: ${subject()}`,`Your exam: ${examLabel()}`,`Your rule: ${studyRule()}`,`Your study moment: ${momentLabel()}`].map(t=>`<div><i>✓</i><span>${t}</span></div>`).join('')}</div></div>${interactive?'<button class="tap-hint" data-next>Continue to your plan</button>':''}`;
      case 'plan':{
        const chapter=Math.max(0,Math.min(2,Math.round(state)||0));
        const labels=['Start','Build','Exam day'],icons=['▤','ϟ','⚑'];
        const scenes=['start','rhythm','exam'];
        const headings=['One small start.','Study. Unlock. Repeat.','Walk in more prepared.'];
        const eyebrows=['TODAY','YOUR NEW RHYTHM','EXAM DAY'];
        const captions=[`Turn your ${subject()} notes into your first deck.`,`Answer ${studyCards()} cards correctly. Earn 5 minutes to scroll.`,`Little sessions now. More ${subject()} behind you.`];
        const badges=['Your notes → flashcards',`${studyCards()} correct → 5 min`,'One session at a time'];
        const descriptions=['A student opens their notes as the Study Guard mascot offers flashcards.','The same student practices flashcards with the mascot cheering them on.','The student and mascot walk toward the exam room together.'];
        const countdown=examDays()===0?'Your exam is today':`${examDays()} ${examDays()===1?'day':'days'} to your exam`;
        return `<section class="journey-page"><header><div class="journey-countdown">▦ ${countdown}</div>${title('Your next chapter.')}</header><div class="journey-art chapter-${chapter}" aria-label="Swipe to explore your study journey"><div class="journey-blob"></div>${img(`journey-${scenes[chapter]}.png`,'journey-illustration',descriptions[chapter])}<span class="journey-count">0${chapter+1} / 03</span><span class="journey-spark" aria-hidden="true">✦</span><div class="journey-badge"><span aria-hidden="true">${icons[chapter]}</span> ${badges[chapter]}</div></div><div class="journey-caption"><div class="eyebrow">${eyebrows[chapter]}</div><h2>${headings[chapter]}</h2><p>${captions[chapter]}</p></div><nav class="journey-nav" aria-label="Your journey chapters">${labels.map((label,i)=>`${i?`<i class="${i<=chapter?'visited':''}" aria-hidden="true"></i>`:''}<button data-journey-chapter="${i}" aria-label="Chapter ${i+1}: ${label}" aria-pressed="${i===chapter}" class="${i<=chapter?'visited':''}"><span aria-hidden="true">${icons[i]}</span><b>${label}</b></button>`).join('')}</nav><p class="journey-hint">Tap a stop or swipe to explore</p></section><div class="journey-rule">${studyRule()}</div>${cta("Let's start my journey")}`;
      }
      case 'paywall':return `<div class="offer-hero">${mascot()}</div><div class="offer-copy">${title('We want you to try<br>Study Guard.')}${p('One small habit. Less scrolling. More<br>time for what matters.')}</div>${cta(interactive?'Preview setup →':'Continue')}`;
      default:return setup(s);
    }
  }
  function setup(s){
    const number=['setup','permission','apps','notifications'].indexOf(s.key);
    const titles=['A little space<br>for your studies.','Make room for<br>what matters.','Which apps<br>can wait?','A friendly nudge.<br>A little momentum.'];
    const subtitles=["Give your studying a head start.<br>Your apps will be there when you're done.",'Connect Screen Time so Study Guard can pause the apps you choose.',"Pick the apps you'd like to earn time for. Your studying comes first.",'A nudge to study.<br>A heads-up when your apps are ready.'];
    let illustration='';
    if(number===0)illustration=`<div class="habit-card">${img('mascot-reading.png','setup-card-mascot')}<strong>Your studies first</strong><small>♧ Then, time to scroll</small></div>`;
    if(number===1)illustration='<div class="permission-symbol">⌛</div><div class="feature-row"><span class="feature-symbol">✋</span><div><strong>You’re in control</strong><small>Choose which apps to pause in the next step.</small></div></div>';
    if(number===2)illustration='<div class="app-tiles"><span>▶</span><span>▣</span><span>◈</span></div><div class="lock-mark">♙</div>'+p('Your choice. Your pace.');
    if(number===3)illustration='<div class="notifications-stack">'+[['Your flashcards are waiting','A quick review before your next scroll.','now'],['You earned this','Your apps are ready when you are.','2m']].map(n=>`<div class="notification">${img('app-logo.png','notification-logo','Study Guard app icon')}<div><strong>${n[0]}</strong><p>${n[1]}</p></div><small>${n[2]}</small></div>`).join('')+'</div>';
    const orbitIcons=['instagram','youtube','whatsapp','tiktok','spotify','facebook','snapchat','slack','pinterest'];
    const orbit=`<div class="setup-orbit" aria-hidden="true"><div class="setup-shield"></div>${img('mascot-reading.png','setup-orbit-mascot')}${img('app-logo.png','setup-orbit-logo')}${orbitIcons.map((n,i)=>`<div class="orbit-app orbit-${n}" style="--angle:${i*40-18}deg">${img(`orbit-${n}.png`)}</div>`).join('')}</div>`;
    const footnote=['A few small steps. A little more time for you.','iOS will ask you to confirm access.','',''][number];
    return `<div class="setup-background"></div>${orbit}<section class="setup-card"><header class="setup-card-chrome"><button class="setup-back" data-back aria-label="Previous setup step" ${number===0?'disabled aria-hidden="true"':''}>‹</button>${progressBar((number+1)/4,`Setup step ${number+1} of 4`,'setup-progress')}<span class="setup-step">${number+1} / 4</span></header><div class="setup-content">${title(titles[number])}${p(subtitles[number])}${illustration}</div><div class="setup-actions">${footnote?`<p class="setup-footnote">${footnote}</p>`:''}${cta(["Let's set it up",'Connect Screen Time','Choose apps','Enable notifications'][number],['','','Set up apps later','Maybe later'][number])}</div></section>`;
  }
  function render(){
    stopExamAnimation();
    stopCommitAnimation();
    stopReviewAnimation();
    const s=flow[index]; document.title=`${s.title} · Study Guard preview`;
    root.innerHTML=`<div class="status"><span>09:41</span><span class="signal">▮▮▮ ◉ <i class="battery"></i></span></div>${renderBody(s)}<div class="home"></div>`;
    const chooseChapter=(chapter,focus=false)=>{
      state=Math.max(0,Math.min(2,chapter));render();notify();
      if(focus)root.querySelector(`[data-journey-chapter="${state}"]`).focus();
    };
    root.querySelectorAll('[data-journey-chapter]').forEach(b=>{
      b.addEventListener('click',()=>chooseChapter(Number(b.dataset.journeyChapter),true));
      b.addEventListener('keydown',e=>{
        if(!['ArrowLeft','ArrowRight'].includes(e.key))return;
        e.preventDefault();chooseChapter(state+(e.key==='ArrowRight'?1:-1),true);
      });
    });
    const art=root.querySelector('.journey-art');let swipeStart;
    art?.addEventListener('pointerdown',e=>{swipeStart={x:e.clientX,y:e.clientY};art.setPointerCapture(e.pointerId)});
    art?.addEventListener('pointerup',e=>{
      if(!swipeStart)return;
      const dx=e.clientX-swipeStart.x,dy=e.clientY-swipeStart.y;swipeStart=null;
      if(Math.abs(dx)>45&&Math.abs(dx)>Math.abs(dy))chooseChapter(state+(dx<0?1:-1));
    });
    art?.addEventListener('pointercancel',()=>{swipeStart=null});
    root.querySelectorAll('[data-next]').forEach(b=>b.addEventListener('click',next));
    root.querySelector('[data-fist-bump]')?.addEventListener('click',event=>{
      const button=event.currentTarget;
      if(button.disabled)return;
      button.disabled=true;button.classList.add('bumped');
      root.querySelector('.commit-hint').textContent="You've got this.";
      const reduced=matchMedia('(prefers-reduced-motion: reduce)').matches;
      if(!reduced){
        ['✦','✧','✦','✧','✦','✧','✦','✧'].forEach((glyph,i)=>{
          const spark=document.createElement('span');spark.className='commit-spark';spark.textContent=glyph;spark.setAttribute('aria-hidden','true');
          const angle=i*Math.PI/4;spark.style.setProperty('--dx',`${Math.cos(angle)*110}px`);spark.style.setProperty('--dy',`${Math.sin(angle)*110}px`);button.append(spark);
        });
      }
      const step=index;
      const timer=setTimeout(()=>{if(index===step)next()},reduced?300:1120);
      stopCommitAnimation=()=>clearTimeout(timer);
    });
    if(s.key==='moreLife'&&interactive&&!matchMedia('(prefers-reduced-motion: reduce)').matches){
      const phrases=['Study More.','Learn More.','Remember More.'];let phraseIndex=0;
      const timer=setInterval(()=>{if(document.hidden)return;phraseIndex=(phraseIndex+1)%phrases.length;root.querySelector('#study-review-phrase').textContent=phrases[phraseIndex]},2500);
      stopReviewAnimation=()=>clearInterval(timer);
    }

    root.querySelector('[data-back]')?.addEventListener('click',()=>{index=Math.max(0,index-1);state=0;render();notify()});
    root.querySelectorAll('[data-choice]').forEach(b=>b.addEventListener('click',()=>{
      if(root.dataset.advancing==='1')return;
      answers[s.key]=Number(b.dataset.choice);
      persist();root.querySelectorAll('.choice').forEach(c=>{c.classList.remove('selected');c.setAttribute('aria-pressed','false')});
      b.classList.add('selected');b.setAttribute('aria-pressed','true');
      if(interactive){root.dataset.advancing='1';setTimeout(()=>{root.dataset.advancing='0';next()},300)}
    }));
    const chooseRule=position=>{
      answers.studyCards=[5,10,20][Math.max(0,Math.min(2,Math.round(position)))];persist();
      const slider=root.querySelector('.rule-slider');slider.value=[5,10,20].indexOf(studyCards());slider.style.setProperty('--fill',`${slider.value*50}%`);slider.setAttribute('aria-valuetext',`${studyCards()} correct flashcards`);
      root.querySelector('#rule-card-count').textContent=studyCards();
      root.querySelector('.rule-exchange').setAttribute('aria-label',`${studyCards()} correct flashcards earn 5 minutes`);
      root.querySelector('.dial-number').textContent=studyHoursLabel();
      root.querySelector('.dial-number').style.fontSize=studyNumberSize()+'px';
      root.querySelector('.rule-dial').setAttribute('aria-label',`Approximately ${studyHoursLabel()} hours of potential extra study time before your ${(answers.subject||'your subject').trim()} exam`);
      const fraction=examDays()>0?studyShare():0;
      root.querySelectorAll('.dial-tick').forEach((tick,i)=>tick.classList.toggle('filled',fraction>0&&i/48<=fraction));
      root.querySelector('.dial-marker').setAttribute('transform',`rotate(${-135+fraction*270} 146 146)`);
      root.querySelector('.estimate-copy').innerHTML=studyEstimate();
      root.querySelectorAll('[data-rule]').forEach(b=>b.setAttribute('aria-pressed',[5,10,20][Number(b.dataset.rule)]===studyCards()));
    };
    root.querySelector('.rule-slider')?.addEventListener('input',e=>chooseRule(Number(e.target.value)));
    root.querySelectorAll('[data-rule]').forEach(b=>b.addEventListener('click',()=>chooseRule(Number(b.dataset.rule))));
    root.querySelector('[data-estimate]')?.addEventListener('click',()=>root.querySelector('.rule-estimate').showModal());
    root.querySelector('[data-close-estimate]')?.addEventListener('click',()=>root.querySelector('.rule-estimate').close());
    root.querySelectorAll('[data-level]').forEach(b=>b.onclick=()=>{answers.studyLevel=Number(b.dataset.level);persist();render()});
    root.querySelector('#subject')?.addEventListener('input',e=>{answers.subject=e.target.value;persist();root.querySelector('[data-subject-next]').disabled=!subjectReady()});
    root.querySelector('[data-level-next]')?.addEventListener('click',()=>{if(levelReady())next()});
    const submitSubject=()=>{if(subjectReady()){answers.subject=answers.subject.trim();persist();next()}};
    root.querySelector('[data-subject-next]')?.addEventListener('click',submitSubject);
    root.querySelector('#subject')?.addEventListener('keydown',e=>{if(e.key==='Enter'){e.preventDefault();submitSubject()}});
    root.querySelector('#exam-date')?.addEventListener('input',e=>{const valid=e.target.validity.valid&&e.target.value>=dateKey(today);root.querySelector('[data-exam-next]').disabled=!valid;if(valid){answers.examDate=e.target.value;persist();root.querySelector('.calendar-caption').textContent=examLabel();root.querySelector('.calendar-preview strong').textContent=examDays()}});
    root.querySelector('[data-exam-next]')?.addEventListener('click',next);
    if(s.key==='examCost')animateExam();
    window.previewReady=true;
  }
  function animateExam(){
    const section=root.querySelector('.exam-dots'),line=root.querySelector('.exam-ending');
    if(!interactive||!line)return;
    let timer,ending=0,character=0;
    const motion=matchMedia('(prefers-reduced-motion: reduce)');
    const grid=section.querySelector('.exam-days-grid'),{columns,cell,side,lost}=Object.fromEntries(Object.entries(grid.dataset).map(([k,v])=>[k,Number(v)]));
    const colorDays=value=>{
      const whole=Math.floor(value),rows=Math.floor(whole/columns),tail=whole%columns,fraction=value-whole;
      section.querySelector('#exam-lost-rows').setAttribute('height',rows*cell);
      const last=section.querySelector('#exam-lost-tail');last.setAttribute('y',rows*cell);last.setAttribute('width',tail*cell+side*fraction);
    };
    const finish=()=>{clearTimeout(timer);colorDays(lost);section.classList.add('exam-settled');line.textContent=examEndings[0]};
    const type=()=>{
      if(document.hidden||motion.matches){finish();return}
      line.textContent=examEndings[ending].slice(0,++character);
      if(character<examEndings[ending].length)timer=setTimeout(type,32);
      else if(ending<examEndings.length-1)timer=setTimeout(()=>{ending++;character=0;type()},1500);
    };
    const visibility=()=>{if(document.hidden)finish()};
    document.addEventListener('visibilitychange',visibility);
    motion.addEventListener('change',finish);
    if(motion.matches||document.hidden)finish();else {
      colorDays(0);
      timer=setTimeout(()=>{
        const started=performance.now();
        const reveal=()=>{const progress=Math.min(1,(performance.now()-started)/1000);colorDays(lost*(.5-Math.cos(Math.PI*progress)/2));timer=setTimeout(progress<1?reveal:type,progress<1?16:50)};
        reveal();
      },450);
    }
    stopExamAnimation=()=>{clearTimeout(timer);document.removeEventListener('visibilitychange',visibility);motion.removeEventListener('change',finish)};
  }
  function next(){
    if(!interactive)return;
    const s=flow[index];
    if(['demo','empathy'].includes(s.key)&&state<s.states.length-1){state++;render();notify();return}
    if(index===flow.length-1){root.innerHTML=`<div class="finish">${mascot()}${title('You’re all set.')}${p('End of the onboarding review.')}<button class="cta" id="restart">Back to the beginning</button></div>`;document.getElementById('restart').onclick=()=>{index=0;state=0;render();notify()};return}
    index++;state=0;render();notify();
  }
  function notify(){parent.postMessage({type:'sg-preview-step',id:flow[index].id,state},location.protocol==='file:'?'*':location.origin)}
  window.addEventListener('message',e=>{if(e.source!==parent||e.origin!==location.origin||e.data?.type!=='sg-preview-go')return;index=Math.max(0,flow.findIndex(s=>s.id===e.data.id));state=e.data.state||0;render()});
  render();
})();
