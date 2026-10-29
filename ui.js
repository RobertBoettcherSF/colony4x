(function(){
'use strict';
const T=22,cv=document.getElementById('map'),ctx=cv.getContext('2d');
const $=id=>document.getElementById(id);
let S=null,ME=-1,selU=null,selC=null,selTile=-1,lastLogShown=0;
const SPEEDS=[{n:'Pause',ms:null},{n:'1x',ms:900},{n:'Fast',ms:220},{n:'Max',ms:0}];
const AP={speed:0,prev:1,timer:null};let reveal=false,follow=true,UG=false;
function isTun(i){const t=S.tiles[i];return t.tun!=null&&t.tun>=0;}
function setView(ug){UG=!!ug;uilog('view',{underground:UG});const b=$('bView');if(b)b.textContent=UG?'View: Underground (U)':'View: Surface (U)';if(b)b.classList.toggle('ugon',UG);afterAction();}
/* ---------- errors & logging ---------- */
function err(msg,src){setTimeout(()=>liveSave('error'),0);try{if(S){S.errors.push({t:S.turn,msg:String(msg),src:src||'',at:new Date().toISOString()});G.logEv(S,'error',{msg:String(msg),src:src||''});}}catch(e){}feed('⚠ Error: '+msg+' (recorded in log)');}
window.onerror=(m,s,l,c,e)=>{err(m,(s||'')+':'+l+':'+c+(e&&e.stack?'\n'+e.stack:''));errDl();};
let lastErrDl=0;function errDl(){if(LIVE){liveSave('uncaught-error');return;}if(Date.now()-lastErrDl>60000){lastErrDl=Date.now();try{exportLog('uncaught-error');}catch(x){}}}
window.addEventListener('unhandledrejection',e=>{err(e.reason);errDl();});
function uilog(type,data){if(S&&!S._placeholder)G.logEv(S,'ui:'+type,data||{});const C=window.COLLOG;if(C&&C.push)C.push(Object.assign({type:'ui:'+type},data||{}));}
function feed(t){const d=document.createElement('div');d.textContent=(S?'T'+S.turn+' ':'')+t;$('feed').prepend(d);while($('feed').childNodes.length>200)$('feed').lastChild.remove();}
let saveT=null;function persistGame(){clearTimeout(saveT);saveT=setTimeout(()=>{if(!S||S._placeholder)return;try{localStorage.setItem('colony4x_autosave',JSON.stringify(G.buildLog(S,'autosave')));}catch(e){}},600);}
function do_(a,quiet){if(a.f==null)a.f=ME;const r=G.act(S,a);liveSave('action:'+a.type);persistGame();if(!r.ok){feed('✖ '+r.msg);toast(r.msg,'bad');}else if(r.msg&&!quiet)feed(r.msg);afterAction();return r;}
function fname(f){return f<0?'Natives':S.factions[f].name;}
function mine(f){return ME>=0&&f===ME;}
function describe(e){
 const m={shipBuilt:()=>mine(e.f)||ME<0?fname(e.f)+' launched a '+e.ship+(e.city?' at '+e.city:''):null,shipSunk:()=>fname(e.f)+' lost a '+e.ship+(e.cargo?' with '+e.cargo+' unit(s) aboard':'')+(e.by!=null&&e.by>=0?' to '+fname(e.by):''),landing:()=>fname(e.f)+' landed a '+e.unit+' from the sea',boarded:()=>mine(e.f)?e.unit+' boarded the '+e.ship:null,bombard:()=>fname(e.f)+' '+e.ship+' bombarded '+e.city+(e.ug?' (warren)':'')+': '+e.hits+'/3 hits'+(e.popLost?', pop −'+e.popLost:''),tradeRun:()=>mine(e.f)||ME<0?fname(e.f)+' trade run'+(e.partner!=null&&e.partner!==e.f?' to '+fname(e.partner):'')+(e.credits?' +'+e.credits+' cr':''):null,aiNavalResearch:()=>null,cityFounded:()=>fname(e.f)+' founded '+e.city+(e.sea?' (sea city)':'')+(e.ug?' (underground base)':''),tunnelDug:()=>mine(e.f)?'Tunnel completed'+(e.rush?' (war tunnel)':''):null,tunnelBreached:()=>(mine(e.f)||mine(e.from)||ME<0)?fname(e.f)+' breached a '+fname(e.from)+' tunnel':null,supplyCut:()=>(mine(e.f)||e.by===ME&&ME>=0||ME<0)?'⚠ '+e.city+' ('+fname(e.f)+') is cut off from surface supply'+(e.by!=null?' – besieged by '+fname(e.by):''):null,supplyRestored:()=>mine(e.f)?e.city+': surface supply restored':null,reservesLow:()=>mine(e.f)||ME<0?'⚠ '+e.city+' reserves low (air '+e.air+', food '+e.food+', power '+e.pow+')':null,tunnelCollapsed:()=>(mine(e.f)||ME<0)?fname(e.f)+' collapsed a tunnel'+(e.hit?' on '+e.hit+' unit(s)':''):null,tunnelFlooded:()=>(mine(e.f)||mine(e.owner)||ME<0)?fname(e.f)+' flooded a '+fname(e.owner)+' tunnel':null,tunnelRepaired:()=>mine(e.f)?'Tunnel repaired':null,warrenSurrendered:()=>e.city+' ('+fname(e.f)+') ran out of air and '+(e.to!=null?'surrendered to '+fname(e.to):'was abandoned'),capitalMoved:()=>fname(e.f)+' moved its capital to '+e.city+(e.ug?' (underground – hard to reach!)':''),combat:()=>fname(e.attF)+' '+e.att+' attacked '+fname(e.defF)+' '+e.def+' (odds '+Math.round(e.odds*100)+'%) – '+e.winner+' won',cityCaptured:()=>fname(e.f)+' captured '+e.city,cityDestroyed:()=>e.city+' was destroyed',cityRavaged:()=>'Spore beasts ravaged '+e.city,techDiscovered:()=>fname(e.f)+' discovered '+e.tech,victory:()=>'VICTORY: '+fname(e.f)+' – '+e.kind,eliminated:()=>e.name+' eliminated',built:()=>mine(e.f)?e.city+' completed '+e.item:null,cityGrew:()=>mine(e.f)?e.city+' grew to '+e.pop:null,cityStarved:()=>mine(e.f)?e.city+' is starving ('+e.pop+')':null,terraformDone:()=>mine(e.f)?e.kind+' completed':null,autoQueue:()=>mine(e.f)?e.city+' queue empty – auto-queued '+e.item:null,facilitySold:()=>fname(e.f)+' sold '+e.item+' (out of credits)',nativeSpawn:()=>visible(e.at)&&ME>=0?'A Spore Beast emerged from the fungus':null,projectAnnounced:()=>'📣 '+fname(e.f)+' has begun the Ascension Array in '+e.city+'!',ascensionStarted:()=>'⚠ '+fname(e.f)+' completed the Ascension Array in '+e.city+' – it ascends in '+e.turns+' turns unless the city falls!',ascensionFailed:()=>fname(e.f)+'\'s ascension FAILED – '+e.city+' was lost',dominionStarted:()=>fname(e.f)+' controls '+Math.round(e.share*100)+'% of the land – dominion in '+e.turns+' turns if held',randomEvent:()=>(mine(e.f)||ME<0)?'✦ '+e.msg:null,relation:()=>(ME<0||e.a===ME||e.b===ME)?'🕊 '+fname(e.a)+' & '+fname(e.b)+': '+(e.openBorders?'open borders':G.REL_NAMES[e.rel])+(e.why&&e.why!=='deal'?' ('+e.why+')':''):null,betrayal:()=>'⚔ '+fname(e.f)+' broke its '+e.treaty+' with '+fname(e.vs)+' – Reputation '+e.rep,diploOffer:()=>(e.to===ME&&ME>=0&&S.factions[e.from].ai)?'📜 '+fname(e.from)+' offers '+e.text+' – answer in Diplomacy (D)':null,diploAnswer:()=>(ME>=0&&e.from===ME)?fname(e.to)+' '+e.answer+' '+e.text+(e.why&&e.why!=='ok'&&e.why!=='player'?' ('+e.why+')':''):null,contact:()=>(ME<0||e.a===ME||e.b===ME)?'First contact: '+fname(e.a)+' meets '+fname(e.b):null,contractDone:()=>(mine(e.seller)||mine(e.buyer))?'Trade contract completed ('+e.res+')':null,reputation:()=>(mine(e.f)&&Math.abs(e.d)>=2)?'Your Reputation '+(e.d>0?'+':'')+e.d+' → '+e.rep+' ('+e.why+')':null,unitsWithdrawn:()=>mine(e.f)?e.n+' unit(s) withdrawn from '+fname(e.from)+' territory':null,diplomacyStarted:()=>fname(e.f)+' leads a council of '+e.pacts+' treaty partners – diplomatic victory in '+e.turns+' turns if held',cooperationStarted:()=>'Alliance of '+e.fs.map(fname).join(' & ')+' ('+e.how+') – cooperative victory in '+e.turns+' turns if held'};
 if(!m[e.type])return;const s=m[e.type]();if(!s)return;
 const big=['betrayal','diplomacyStarted','cooperationStarted','warrenSurrendered','capitalMoved','victory','eliminated','cityCaptured','cityDestroyed','projectAnnounced','ascensionStarted','ascensionFailed','dominionStarted'].includes(e.type);if(['projectAnnounced','ascensionStarted','ascensionFailed','diplomacyStarted','cooperationStarted'].includes(e.type)&&AP.speed!==3)toast(s);if(e.type==='diploOffer'||(e.type==='betrayal'&&(e.vs===ME)))toast(s);
 if(ME<0){if(big||e.type==='techDiscovered'||e.type==='cityFounded'||(e.type==='combat'&&AP.speed!==3))feed(s);}
 else if((['relation','diploOffer','diploAnswer','contact','contractDone','reputation'].includes(e.type))||mine(e.f)||e.attF===ME||e.defF===ME||(e.type==='tunnelBreached'&&mine(e.from))||(e.type==='tunnelFlooded'&&mine(e.owner))||(e.type==='supplyCut'&&e.by===ME)||big||['techDiscovered','cityFounded'].includes(e.type))feed(s);
}
function afterAction(){
 let focus=-1;for(const e of S.log.slice(lastLogShown)){describe(e);if(e.at!=null&&['combat','cityFounded','cityCaptured','cityDestroyed','cityRavaged'].includes(e.type))focus=e.at;}lastLogShown=S.log.length;
 if(ME<0&&follow&&focus>=0)scrollTo(focus,true);
 if(selU&&S.units.indexOf(selU)<0)selU=null;if(selC&&S.cities.indexOf(selC)<0)selC=null;
 if(ME>=0&&selU&&selU.f===ME&&(selU.mp<=0||selU.skip||selU.work))nextUnit(true);
 draw();panel();top();checkEnd();
}
/* ---------- drawing ---------- */
function seenArr(){return(ME<0||reveal)?null:S.factions[ME].seen;}
function visible(i){const s=seenArr();return!s||!!s[i];}
function tileColor(t){if(!t.land)return'rgb(20,50,110)';if(t.f)return'#7a2f6e';const g=[[150,130,90],[95,135,70],[50,110,60]][t.m];const k=1-t.r*0.12+t.e*0.15;return'rgb('+(g[0]*k|0)+','+(g[1]*k|0)+','+(g[2]*k|0)+')';}
function draw(){window.__c4xTurn=S.turn;
 if(cv.width!==S.W*T)cv.width=S.W*T;if(cv.height!==S.H*T)cv.height=S.H*T;const seen=seenArr();
 for(let i=0;i<S.tiles.length;i++){const x=G.X(S,i)*T,y=G.Y(S,i)*T,t=S.tiles[i];
  if(seen&&!seen[i]){ctx.fillStyle='#000';ctx.fillRect(x,y,T,T);continue;}
  ctx.fillStyle=tileColor(t);ctx.fillRect(x,y,T,T);
  if(t.land&&t.r===2&&!t.f){ctx.fillStyle='#0004';ctx.fillRect(x+4,y+12,4,4);ctx.fillRect(x+13,y+5,5,5);}
  if(t.f){ctx.fillStyle='#c25bb3';ctx.fillRect(x+3,y+4,3,3);ctx.fillRect(x+14,y+12,3,3);ctx.fillRect(x+8,y+16,2,2);}
  if(t.road&&t.land){ctx.strokeStyle='#a07040';ctx.lineWidth=2;let any=false;for(const n of G.nbrs(S,i))if(S.tiles[n].road&&S.tiles[n].land){any=true;ctx.beginPath();ctx.moveTo(x+T/2,y+T/2);ctx.lineTo(x+T/2+(G.X(S,n)-G.X(S,i))*T/2,y+T/2+(G.Y(S,n)-G.Y(S,i))*T/2);ctx.stroke();}if(!any){ctx.fillStyle='#a07040';ctx.fillRect(x+9,y+9,4,4);}}
  if(t.imp==='farm'){ctx.strokeStyle='#e6d36a';ctx.lineWidth=1;for(let k=4;k<T;k+=5){ctx.beginPath();ctx.moveTo(x+2,y+k);ctx.lineTo(x+T-2,y+k);ctx.stroke();}}
  if(t.imp==='mine'){ctx.fillStyle='#bbb';ctx.beginPath();ctx.moveTo(x+4,y+T-4);ctx.lineTo(x+T/2,y+5);ctx.lineTo(x+T-4,y+T-4);ctx.fill();}
  if(t.imp==='solar'){ctx.fillStyle='#4fd1e8';ctx.fillRect(x+5,y+5,T-10,T-10);ctx.strokeStyle='#123';ctx.strokeRect(x+5,y+5,T-10,T-10);}
 }
 if(UG){drawUG(seen);return;}
 // tunnel entrances (surface)
 for(let i=0;i<S.tiles.length;i++){if(!isTun(i)||(seen&&!seen[i])||G.cityAt(S,i))continue;const x=G.X(S,i)*T,y=G.Y(S,i)*T;ctx.fillStyle='#120c08';ctx.fillRect(x+T-9,y+T-9,7,7);ctx.strokeStyle=S.factions[S.tiles[i].tun].color;ctx.lineWidth=1;ctx.strokeRect(x+T-9.5,y+T-9.5,8,8);}
 for(let i=0;i<S.tiles.length;i++){const t=S.tiles[i];if((seen&&!seen[i])||!(t.fl||t.col))continue;const x=G.X(S,i)*T,y=G.Y(S,i)*T;if(t.fl){ctx.fillStyle='#3a7bd5';ctx.fillRect(x+T-9,y+T-9,7,7);}else{ctx.fillStyle='#777';ctx.fillRect(x+T-9,y+T-5,3,3);ctx.fillRect(x+T-5,y+T-8,3,3);}}
 // territory borders
 const tr=G.territory(S);ctx.lineWidth=2;
 for(let i=0;i<tr.length;i++){const o=tr[i];if(o<0||(seen&&!seen[i]))continue;const x=G.X(S,i),y=G.Y(S,i);ctx.strokeStyle=S.factions[o].color;ctx.beginPath();
  if(y===0||tr[i-S.W]!==o){ctx.moveTo(x*T,y*T+1);ctx.lineTo(x*T+T,y*T+1);}
  if(y===S.H-1||tr[i+S.W]!==o){ctx.moveTo(x*T,y*T+T-1);ctx.lineTo(x*T+T,y*T+T-1);}
  if(x===0||tr[i-1]!==o){ctx.moveTo(x*T+1,y*T);ctx.lineTo(x*T+1,y*T+T);}
  if(x===S.W-1||tr[i+1]!==o){ctx.moveTo(x*T+T-1,y*T);ctx.lineTo(x*T+T-1,y*T+T);}ctx.stroke();}
 // own city radius outlines
 if(ME>=0){ctx.save();ctx.setLineDash([3,3]);ctx.strokeStyle='#ffffff70';ctx.lineWidth=1;for(const c of S.cities)if(c.f===ME){const x=G.X(S,c.at),y=G.Y(S,c.at);const x0=Math.max(0,x-2),y0=Math.max(0,y-2),x1=Math.min(S.W-1,x+2),y1=Math.min(S.H-1,y+2);ctx.strokeRect(x0*T+3,y0*T+3,(x1-x0+1)*T-6,(y1-y0+1)*T-6);}ctx.restore();}
 if(selC){ctx.strokeStyle='#fff9';ctx.lineWidth=1;for(const w of selC.worked)ctx.strokeRect(G.X(S,w)*T+2,G.Y(S,w)*T+2,T-4,T-4);}
 for(const c of S.cities){if(seen&&!seen[c.at])continue;const x=G.X(S,c.at)*T,y=G.Y(S,c.at)*T,f=S.factions[c.f];
  if(c.ug){ctx.fillStyle='#2a1d14';ctx.fillRect(x+1,y+1,T-2,T-2);ctx.strokeStyle=f.color;ctx.lineWidth=c===selC?4:3;ctx.strokeRect(x+2,y+2,T-4,T-4);ctx.fillStyle=f.color;ctx.beginPath();ctx.moveTo(x+4,y+4);ctx.lineTo(x+T-4,y+4);ctx.lineTo(x+T/2,y+9);ctx.fill();}
  else{ctx.fillStyle=f.color;ctx.fillRect(x+1,y+1,T-2,T-2);ctx.strokeStyle=c.sea?'#9cf':'#fff';ctx.lineWidth=c===selC?3:1;ctx.strokeRect(x+1,y+1,T-2,T-2);}
  ctx.fillStyle=c.ug?'#fff':'#000';ctx.font='bold 12px sans-serif';ctx.textAlign='center';ctx.fillText(c.pop,x+T/2,y+T/2+4);
  if(c.ug&&(c.cut||c.low))warnIcon(x,y,c.cut&&c.res&&(c.res.air<=1)?'#ff3030':'#ffa500');
  const nu=S.units.filter(u=>u.at===c.at).length;if(nu){ctx.fillStyle='#111';ctx.beginPath();ctx.arc(x+T-3,y+3,6,0,7);ctx.fill();ctx.fillStyle='#fff';ctx.font='bold 9px sans-serif';ctx.fillText(nu,x+T-3,y+6);}
  ctx.font='11px sans-serif';ctx.fillStyle='#fff';ctx.strokeStyle='#000';ctx.lineWidth=3;ctx.strokeText(c.name,x+T/2,y-2);ctx.fillText(c.name,x+T/2,y-2);}
 const shown={};
 for(const u of S.units){if(seen&&!seen[u.at])continue;const c=G.cityAt(S,u.at);if(c&&u!==selU&&u.f===c.f)continue;if(shown[u.at]&&u!==selU)continue;shown[u.at]=1;drawUnit(u);}
 if(selU){const x=G.X(S,selU.at)*T,y=G.Y(S,selU.at)*T;ctx.strokeStyle='#ff0';ctx.lineWidth=2;ctx.strokeRect(x,y,T,T);if(selU.goto>=0){ctx.strokeStyle='#ff08';ctx.strokeRect(G.X(S,selU.goto)*T+3,G.Y(S,selU.goto)*T+3,T-6,T-6);}}
 if(selTile>=0&&!selU&&!selC){ctx.strokeStyle='#fff';ctx.lineWidth=1;ctx.strokeRect(G.X(S,selTile)*T,G.Y(S,selTile)*T,T,T);}
}
function warnIcon(x,y,col){ctx.fillStyle=col;ctx.beginPath();ctx.moveTo(x+2,y+T-2);ctx.lineTo(x+9,y+T-14);ctx.lineTo(x+16,y+T-2);ctx.fill();ctx.fillStyle='#000';ctx.font='bold 10px sans-serif';ctx.textAlign='center';ctx.fillText('!',x+9,y+T-4);}
function drawUG(seen){
 ctx.fillStyle='#000';ctx.fillRect(0,0,cv.width,cv.height);
 for(let i=0;i<S.tiles.length;i++){const x=G.X(S,i)*T,y=G.Y(S,i)*T,t=S.tiles[i];if(seen&&!seen[i])continue;ctx.fillStyle=t.land?['#2b231c','#332a20','#3d3226'][t.r]:'#060a14';ctx.fillRect(x,y,T,T);if(t.land&&t.r===2){ctx.fillStyle='#0006';ctx.fillRect(x+5,y+6,3,3);ctx.fillRect(x+13,y+13,4,4);}}
 ctx.lineCap='round';
 for(let i=0;i<S.tiles.length;i++){if(!isTun(i)||(seen&&!seen[i]))continue;const x=G.X(S,i)*T+T/2,y=G.Y(S,i)*T+T/2,col=S.factions[S.tiles[i].tun].color;ctx.strokeStyle=col;ctx.lineWidth=6;let any=false;
  for(const n of G.nbrs(S,i))if(isTun(n)||(G.cityAt(S,n)&&G.cityAt(S,n).f===S.tiles[i].tun)){any=true;ctx.beginPath();ctx.moveTo(x,y);ctx.lineTo(x+(G.X(S,n)-G.X(S,i))*T/2,y+(G.Y(S,n)-G.Y(S,i))*T/2);ctx.stroke();}
  ctx.fillStyle=col;ctx.beginPath();ctx.arc(x,y,any?3:5,0,7);ctx.fill();if(S.tiles[i].fl){ctx.fillStyle='#3a7bd5cc';ctx.fillRect(x-T/2+2,y-T/2+2,T-4,T-4);}}
 for(let i=0;i<S.tiles.length;i++){if(!S.tiles[i].col||(seen&&!seen[i]))continue;const x=G.X(S,i)*T,y=G.Y(S,i)*T;ctx.strokeStyle='#888';ctx.lineWidth=2;ctx.beginPath();ctx.moveTo(x+5,y+5);ctx.lineTo(x+T-5,y+T-5);ctx.moveTo(x+T-5,y+5);ctx.lineTo(x+5,y+T-5);ctx.stroke();}
 for(const c of S.cities){if(seen&&!seen[c.at])continue;const x=G.X(S,c.at)*T,y=G.Y(S,c.at)*T,f=S.factions[c.f];
  if(c.ug){ctx.fillStyle=f.color;ctx.fillRect(x+1,y+1,T-2,T-2);ctx.strokeStyle='#fff';ctx.lineWidth=c===selC?3:1;ctx.strokeRect(x+1,y+1,T-2,T-2);ctx.fillStyle='#000';ctx.font='bold 12px sans-serif';ctx.textAlign='center';ctx.fillText(c.pop,x+T/2,y+T/2+4);if(c.cut||c.low)warnIcon(x,y,c.cut&&c.res&&c.res.air<=1?'#ff3030':'#ffa500');}
  else{ctx.strokeStyle=f.color;ctx.lineWidth=2;ctx.strokeRect(x+5,y+5,T-10,T-10);}
  ctx.font='11px sans-serif';ctx.textAlign='center';ctx.fillStyle=c.ug?'#fff':'#aaa';ctx.strokeStyle='#000';ctx.lineWidth=3;ctx.strokeText(c.name,x+T/2,y-2);ctx.fillText(c.name,x+T/2,y-2);}
 if(selC&&selC.ug){ctx.strokeStyle='#fff9';ctx.lineWidth=1;for(const w of selC.worked)ctx.strokeRect(G.X(S,w)*T+2,G.Y(S,w)*T+2,T-4,T-4);}
 const shown={};for(const u of S.units){if(seen&&!seen[u.at])continue;const c=G.cityAt(S,u.at);if(!(isTun(u.at)||(c&&c.ug)))continue;if(c&&u!==selU&&u.f===c.f)continue;if(shown[u.at]&&u!==selU)continue;shown[u.at]=1;drawUnit(u);}
 if(selU){const x=G.X(S,selU.at)*T,y=G.Y(S,selU.at)*T;ctx.strokeStyle='#ff0';ctx.lineWidth=2;ctx.strokeRect(x,y,T,T);}
 if(selTile>=0&&!selU&&!selC){ctx.strokeStyle='#fff';ctx.lineWidth=1;ctx.strokeRect(G.X(S,selTile)*T,G.Y(S,selTile)*T,T,T);}
 ctx.fillStyle='#fffa';ctx.font='bold 13px sans-serif';ctx.textAlign='left';const w=$('mapwrap');ctx.fillText('UNDERGROUND VIEW (U = back to surface)',(w?w.scrollLeft:0)+8,(w?w.scrollTop:0)+18);
}
function ready(u){return u.mp>0&&!u.skip&&!u.work;}
function drawUnit(u){const x=G.X(S,u.at)*T,y=G.Y(S,u.at)*T,col=u.f<0?'#b04ad0':S.factions[u.f].color;
 const dim=u.f===ME&&!ready(u);ctx.globalAlpha=dim?0.45:1;
 if(u.on!=null){ctx.globalAlpha=1;return;}const ship=G.isShip(u);ctx.fillStyle=col;ctx.beginPath();if(ship){ctx.moveTo(x+2,y+T/2-3);ctx.lineTo(x+T-2,y+T/2-3);ctx.lineTo(x+T-6,y+T-4);ctx.lineTo(x+6,y+T-4);ctx.closePath();}else ctx.arc(x+T/2,y+T/2,T/2-3,0,7);ctx.fill();ctx.strokeStyle=u.f===ME&&ready(u)?'#fff':'#000';ctx.lineWidth=1.5;ctx.stroke();
 ctx.fillStyle='#000';ctx.font='bold 11px sans-serif';ctx.textAlign='center';ctx.fillText(G.UNITS[u.type].ch,x+T/2,y+T/2+4);if(G.isShip(u)){const n=G.cargoOf(S,u).length;if(n){ctx.fillStyle='#ff0';ctx.font='bold 10px sans-serif';ctx.fillText(String(n),x+T-5,y+9);}}
 if(u.hp<10){ctx.fillStyle='#f33';ctx.fillRect(x+3,y+T-3,(T-6)*u.hp/10,2);}
 const n=S.units.filter(o=>o.at===u.at).length;if(n>1){ctx.fillStyle='#111';ctx.beginPath();ctx.arc(x+T-3,y+3,6,0,7);ctx.fill();ctx.fillStyle='#fff';ctx.font='bold 9px sans-serif';ctx.fillText(n,x+T-3,y+6);}
 ctx.globalAlpha=1;}
/* ---------- panels ---------- */
function ystr(y){return'<span class="y n">●'+y[0]+' nutr</span><span class="y m">●'+y[1]+' min</span><span class="y e">●'+y[2]+' energy</span>';}
function top(){
 if(ME>=0){const f=S.factions[ME],inc=f.lastIncome||{};
  $('stat').innerHTML='Turn <b>'+S.turn+'</b> · <span style="color:'+f.color+'">'+f.name+'</span> · Credits <b>'+f.credits+'</b>'+(inc.econ!=null?' ('+(inc.econ-inc.maint>=0?'+':'')+(inc.econ-inc.maint)+')':'')+' · Research: <b>'+(f.research?G.TECHS[f.research].name:'<span style="color:#f85">none – pick one!</span>')+'</b> '+f.rp+'/'+G.techCost(S,ME)+(inc.labs!=null?' (+'+inc.labs+')':'')+' · Seed '+S.seed;
  $('labs').value=Math.round(f.labs*100);$('labsv').textContent=Math.round(f.labs*100)+'%';$('labs').disabled=false;}
 else{$('stat').innerHTML='Turn <b>'+S.turn+'</b> · <b style="color:#d2a8ff">AUTOPLAY</b> – watching AI play all factions · Seed '+S.seed;$('labs').disabled=true;$('labsv').textContent='–';}
 if(S.ascension){const A=S.ascension;$('stat').innerHTML+=' · <b style="color:#ff7b72">⚠ '+fname(A.f)+' ascends in '+A.left+'</b>';}
 for(const f of S.factions)if(f.domTurns>0)$('stat').innerHTML+=' · <span style="color:'+f.color+'">dominion '+f.domTurns+'/'+G.DOMINION_TURNS+'</span>';
 $('stat').innerHTML+=' · <span class="small">'+G.DIFFICULTY[S.opts.difficulty==null?2:S.opts.difficulty].name+'</span>';
 for(let k=0;k<SPEEDS.length;k++)$('sp'+k).classList.toggle('on',ME<0&&AP.speed===k);
 $('bCtl').textContent=ME<0?'Take control (C)':'Hand back to AI (C)';
 const rdy=ME>=0&&S.winner==null&&!S.units.some(u=>u.f===ME&&ready(u)&&u.goto<0);
 $('bEnd').classList.toggle('pulse',rdy);$('bEnd').disabled=ME<0;
 $('revealCb').checked=reveal;$('followCb').checked=follow;
}
function unitList(i){const us=S.units.filter(u=>u.at===i);if(!us.length)return'';
 return'<h4>Units here ('+us.length+')</h4>'+us.map(u=>{const d=G.UNITS[u.type],lab=d.name+' <span class="small">'+fname(u.f)+' · HP '+u.hp+' · '+(u.work?G.TERRA[u.work.kind].name+' '+u.work.left+'t':(u.mp/3).toFixed(1)+' mv')+'</span>';
  return'<div class="ul'+(u===selU?' cur':'')+(u.f===ME&&!ready(u)?' dim':'')+'">'+(u.f===ME?'<a href="#" data-sel="'+u.id+'">'+lab+'</a>':lab)+'</div>';}).join('');}
function panel(){const el=$('sel');let h='';
 if(selC){const c=selC,y=G.cityYield(S,c);
  h+='<h3>'+c.name+(c.sea?' <span class="small">(sea city)</span>':'')+(c.ug?' <span class="small ugtag">(underground base)</span>':'')+(c.capital?' <span class="small">★ capital</span>':'')+' <span class="small">pop '+c.pop+'/'+G.popCap(c)+' · '+fname(c.f)+'</span>'+(c.f===ME?' <button data-rename="1" title="Rename city">✎ Rename</button>':'')+'</h3>'+ystr(y)+'<div class="small">Food '+c.food+'/'+G.foodBox(S,c)+' (net '+(y[0]-2*c.pop)+'/turn) · Production '+c.prod+(c.queue.length?'/'+G.itemCost(c.queue[0]):'')+'</div>';
  if(c.ug){const cap=G.resCaps(c),r=c.res||cap;const bar=(n,k,lab)=>'<span class="y '+(r[k]<=1?'bad':'')+'">'+lab+' '+r[k]+'/'+cap[k]+'</span>';h+='<div class="res">Reserves: '+bar(0,'air','💨 air')+' '+bar(0,'food','🍞 food')+' '+bar(0,'pow','⚡ power')+(c.cut?' <b class="warn">SUPPLY CUT</b>':' <span class="small">supplied</span>')+'</div>';}
  if(c.ug)h+='<div class="small">Underground base: mines the rock below (no nutrients – feed it with a Hydroponics Vat), pop cap '+G.popCap(c)+', immune to fungus, beasts and surface events; only attackable from a tunnel tile or by attack-4+ units (or any unit with Seismic Sapping). Needs surface supply: a held entrance (its own shaft or a tunnel end next to your city) with no enemy next to it, linked by your tunnels. Cut off, air drains fast (CO2 Scrubbers only slow it), then food and power; no air = population loss, then surrender.</div>';
  h+='<div class="small">Facilities: '+(c.fac.map(k=>G.FAC[k].name).join(', ')||'none')+'</div>';
  if(c.f===ME){h+='<h4>Queue</h4>'+(c.queue.map((q,i)=>'<div>'+(i+1)+'. '+G.itemName(q)+' <button data-unq="'+i+'">x</button></div>').join('')||'<div class="small">empty (an item will be auto-queued)</div>');
   if(c.queue.length)h+='<button data-buy="1">Buy now ('+G.buyCost(c)+' cr)</button>';
   h+='<h4>Add to queue</h4><div class="row">'+G.buildable(S,c).map(k=>{const d=G.UNITS[k]||G.FAC[k];return'<button data-q="'+k+'" title="'+(d.desc||('A'+d.a+' D'+d.d+' M'+d.mv))+'">'+d.name+' ('+d.cost+')</button>';}).join('')+'</div>';}
  h+=unitList(c.at)+'<button data-close="1">Close (Esc)</button>';
 } else if(selU){const u=selU,d=G.UNITS[u.type];
  h+='<h3>'+d.name+' <span class="small">'+fname(u.f)+'</span></h3><div>Attack '+d.a+' · Defence '+d.d+' · HP '+u.hp+'/10 · Moves '+(u.mp/3).toFixed(1)+'/'+d.mv+(u.fort?' · fortified':'')+'</div>';
  if(u.work)h+='<div>Working: '+G.TERRA[u.work.kind].name+' ('+u.work.left+' turns left)</div>';
  if(d.desc)h+='<div class="small">'+d.desc+'</div>';
  if(u.f===ME){h+='<div class="row">';if(d.found)h+='<button data-a="found">'+(d.ug?'Found Warren (B)':'Found city (B)')+'</button>';if(u.type==='burrower')h+='<button data-t="tunnel">'+((S.tiles[u.at].fl||S.tiles[u.at].col)?'Repair tunnel (J)':'Dig tunnel (J)')+'</button>';if(d.a>0&&[u.at].concat(G.nbrs(S,u.at)).some(n=>G.canFlood(S,u.f,n)))h+='<button data-a="flood">Flood tunnel (L)</button>';
   if(u.type==='terraformer'){for(const[k,key]of[['farm','F'],['mine','M'],['solar','S'],['road','R'],['clear','X']])h+='<button data-t="'+k+'">'+G.TERRA[k].name+' ('+key+')</button>';}
   if(!G.isShip(u)&&u.on==null&&G.transportAt(S,u.at,u.f))h+='<button data-a="board">Board (E)</button>';if(u.on!=null)h+='<button data-a="unboard">Unboard</button>';if(G.UNITS[u.type].bomb){const bt=G.bombardTargets(S,u);for(const b of bt)h+='<button data-bomb="'+b+'">Bombard '+esc(G.cityAt(S,b).name)+' (O)</button>';}if(G.isShip(u)&&G.UNITS[u.type].cap)h+='<div class="small">Cargo: '+G.cargoOf(S,u).map(x=>G.UNITS[x.type].name).join(', ')+' ('+G.cargoOf(S,u).length+'/'+G.UNITS[u.type].cap+')</div>';h+='<button data-a="fortify">Fortify (H)</button><button data-a="skip">Skip (Space/5)</button><button data-a="next">Next (N)</button><button data-a="disband">Disband</button></div>';}
  const n=S.units.filter(o=>o.at===u.at).length;if(n>1)h+=unitList(u.at);
  h+=tileInfo(u.at);
 } else if(selTile>=0){h+=unitList(selTile)+tileInfo(selTile);} else h+='<div class="small">'+(ME<0?'Autoplay: use the speed buttons; press <kbd>C</kbd> to take control of a faction. Click anything to inspect.':'Click a unit or city. Left-click adjacent tile = move/attack, right-click = go to. Press <kbd>?</kbd> for help.')+'</div>';
 if(ME>=0){const mc=S.cities.filter(c=>c.f===ME);h+='<h4>Your cities</h4>'+mc.map(c=>'<div><a href="#" data-city="'+c.id+'">'+c.name+'</a> pop '+c.pop+' → '+(c.queue[0]?G.itemName(c.queue[0]):'—')+'</div>').join('');}
 h+='<h4>Factions</h4>'+S.factions.map(f=>'<div style="color:'+f.color+'">'+f.name+(f.alive?'':' ✝')+(f.id===ME?' (you)':f.ai?' (AI)':'')+' – cities '+S.cities.filter(c=>c.f===f.id).length+', score '+G.score(S,f.id)+'</div>').join('')+'<button data-stats="1">Stats</button>';
 el.innerHTML=h;}
function moveCostTxt(i){const t=S.tiles[i];if(!t.land)return G.cityAt(S,i)?'1 (sea city)':'1 for ships; land units need a Troop Transport';if(t.road)return'⅓ along roads, otherwise 1';if(t.f){const free=ME>=0&&(S.factions[ME].techs.includes('myco')||S.factions[ME].pers==='eco');return free?'1':'2 (fungus)';}return'1';}
function tileInfo(i){const t=S.tiles[i];if(!visible(i))return'<div class="small">Unexplored</div>';const tr=G.territory(S)[i];
 return'<h4>Tile ('+G.X(S,i)+','+G.Y(S,i)+')</h4><div class="small">'+(t.land?['Arid','Moist','Lush'][t.m]+', '+['flat','rolling','rocky'][t.r]+', elevation '+t.e+(t.f?', <b style="color:#c25bb3">fungus</b>':'')+(t.imp?', '+t.imp:'')+(t.road?', road':''):'Sea')+'<br>Move cost: '+moveCostTxt(i)+(t.land&&t.r===2?' · +25% defence':'')+(tr>=0?'<br>Territory: <span style="color:'+S.factions[tr].color+'">'+S.factions[tr].name+'</span>':'')+(isTun(i)?'<br>Tunnel: <span style="color:'+S.factions[t.tun].color+'">'+S.factions[t.tun].name+'</span> (free moves for its owner; enemies breach it by stepping in)'+(t.fl?' – <b>flooded</b> (Burrower J pumps it out)':'')+(ME>=0&&t.tun===ME&&!G.cityAt(S,i)?' <button data-collapse="'+i+'">Collapse tunnel (K)</button>':''):'')+(t.col?'<br>Collapsed tunnel (a Burrower can re-dig it)':'')+'</div>'+ystr(G.yields(S,i,ME>=0?ME:0))+(t.land&&(UG||isTun(i))?'<div class="small">Underground: '+ystr(G.yields(S,i,ME>=0?ME:0,true))+'</div>':'');}
$('sel').addEventListener('click',e=>{const b=e.target.closest('button,a')||e.target;const D=b.dataset||{};
 if(D.q)do_({type:'queue',c:selC.id,item:D.q});else if(D.unq)do_({type:'unqueue',c:selC.id,i:+D.unq});else if(D.buy)do_({type:'buy',c:selC.id});else if(D.close){selC=null;afterAction();}
 else if(D.bomb!=null)do_({type:'bombard',u:selU.id,at:+D.bomb});else if(D.collapse!=null)do_({type:'collapse',at:+D.collapse});
 else if(D.rename)renameDlg(selC);else if(D.stats)statsDlg();
 else if(D.t)do_({type:'terra',u:selU.id,kind:D.t});else if(D.a){const a=D.a;if(a==='next')nextUnit();else if(a==='found')foundDlg(selU);else if(a==='flood')do_({type:'flood',u:selU.id});else if(a==='disband'){if(confirm('Disband unit?'))do_({type:'disband',u:selU.id});}else do_({type:a,u:selU.id});}
 else if(D.sel){e.preventDefault();selU=S.units.find(u=>u.id==D.sel);selC=null;afterAction();}else if(D.city){e.preventDefault();selC=S.cities.find(c=>c.id==D.city);selU=null;scrollTo(selC.at);afterAction();}});
function nextUnit(auto){if(ME<0){selU=null;return;}const list=S.units.filter(u=>u.f===ME&&ready(u)&&u.goto<0).sort((a,b)=>a.id-b.id);if(!list.length){selU=null;if(!auto)afterAction();return;}
 const k=selU?list.findIndex(u=>u.id>selU.id):0;selU=list[k>=0?k:0];selC=null;scrollTo(selU.at);if(!auto)afterAction();}
function scrollTo(i,smooth){const w=$('mapwrap'),x=G.X(S,i)*T,y=G.Y(S,i)*T;if(x<w.scrollLeft+40||x>w.scrollLeft+w.clientWidth-40)w.scrollLeft=x-w.clientWidth/2;if(y<w.scrollTop+40||y>w.scrollTop+w.clientHeight-40)w.scrollTop=y-w.clientHeight/2;}
function tileFromEvent(e){const r=cv.getBoundingClientRect();const x=Math.floor((e.clientX-r.left)/T),y=Math.floor((e.clientY-r.top)/T);if(x<0||y<0||x>=S.W||y>=S.H)return -1;return y*S.W+x;}
cv.addEventListener('click',e=>clickTile(tileFromEvent(e)));
function clickTile(i){if(i<0)return;
 if(selU&&selU.f===ME&&ME>=0&&G.dist(S,selU.at,i)===1&&G.UNITS[selU.type].bomb&&!G.canBombard(S,selU,i)){do_({type:'bombard',u:selU.id,at:i});return;}
 if(selU&&selU.f===ME&&ME>=0&&G.dist(S,selU.at,i)===1){do_({type:'move',u:selU.id,to:i});return;}
 const myU=S.units.filter(u=>u.at===i&&u.f===ME&&ME>=0),c=G.cityAt(S,i);selTile=i;
 if(c&&visible(i)&&!(selU&&selU.at===i&&myU.length>1)){if(selC===c&&myU.length){selC=null;selU=myU.find(ready)||myU[0];}else{selC=c;selU=null;}}
 else if(myU.length){const k=selU?myU.indexOf(selU):-1;selU=myU[(k+1)%myU.length];selC=null;}
 else{selU=null;selC=null;const any=S.units.filter(u=>u.at===i);if(any.length===1&&visible(i))selU=any[0];}
 draw();panel();}
cv.addEventListener('contextmenu',e=>{e.preventDefault();const i=tileFromEvent(e);if(i<0)return;if(selU&&selU.f===ME&&ME>=0)do_({type:'goto',u:selU.id,to:i});else toast(ME<0?'Take control first (C)':'Select one of your units first','bad');});
const DIRS={ArrowUp:[0,-1],ArrowDown:[0,1],ArrowLeft:[-1,0],ArrowRight:[1,0],Home:[-1,-1],PageUp:[1,-1],End:[-1,1],PageDown:[1,1],Numpad8:[0,-1],Numpad2:[0,1],Numpad4:[-1,0],Numpad6:[1,0],Numpad7:[-1,-1],Numpad9:[1,-1],Numpad1:[-1,1],Numpad3:[1,1],
 '8':[0,-1],'2':[0,1],'4':[-1,0],'6':[1,0],'7':[-1,-1],'9':[1,-1],'1':[-1,1],'3':[1,1]};
const SKIPKEYS=['Numpad5','5','Clear',' ','Spacebar'];
document.addEventListener('keydown',e=>{
 if(e.key==='F9'){e.preventDefault();exportLog('manual-F9');return;}
 if(!S)return;
 if(!$('modal').hidden){if(e.key==='Escape'){closeModal();}else if(e.key==='Enter'&&$('mOk')){e.preventDefault();$('mOk').click();}return;}
 if(e.target.tagName==='INPUT'&&e.target.type!=='range'&&e.target.type!=='checkbox')return;
 if(e.target.tagName==='SELECT')return;
 const k=(e.key||'').toLowerCase();
 if(k==='c'){e.preventDefault();ctlBtn();return;}
 if(k==='p'&&ME<0){setSpeed(AP.speed===0?(AP.prev||1):0);return;}
 if(k==='v'){reveal=!reveal;uilog('reveal',{on:reveal});afterAction();return;}
 if(e.key==='?'||k==='/'){help();return;}
 if(k==='g'){statsDlg();return;}
 if(k==='d'){e.preventDefault();diploDlg();return;}
 if(k==='u'){setView(!UG);return;}
 if(k==='y'){policyDlg();return;}
 if(ME<0){if(DIRS[e.code]||DIRS[e.key]||SKIPKEYS.includes(e.code)||SKIPKEYS.includes(e.key)||'bfmsrxhntjkl'.includes(k)&&k)toast('Autoplay is running – press C to take control','bad');if(e.key==='Enter')toast('Autoplay: use the speed buttons (P = pause/resume)','bad');return;}
 const isNum=/^Numpad\d$/.test(e.code)||/^[1-9]$/.test(e.key);
 if(SKIPKEYS.includes(e.code)||SKIPKEYS.includes(e.key)){e.preventDefault();if(selU&&selU.f===ME)do_({type:'skip',u:selU.id});else toast('No unit selected','bad');return;}
 const d=DIRS[e.code]||DIRS[e.key];
 if(d){e.preventDefault();if(!selU||selU.f!==ME){toast('No unit selected – press N for the next unit','bad');return;}const x=G.X(S,selU.at)+d[0],y=G.Y(S,selU.at)+d[1];if(x<0||y<0||x>=S.W||y>=S.H){toast('Edge of the map','bad');return;}do_({type:'move',u:selU.id,to:y*S.W+x});return;}
 if(e.key==='Enter'){e.preventDefault();endTurn();return;}
 if(e.key==='Escape'){selU=null;selC=null;selTile=-1;afterAction();return;}
 if(k==='n'){nextUnit();if(!selU)toast('All units have moved – press Enter to end turn');return;}
 if(k==='t'){research();return;}
 if(k==='k'){e.preventDefault();if(selTile<0){toast('Click one of your empty tunnel tiles first, then K','bad');return;}do_({type:'collapse',at:selTile});return;}
 if(k==='l'){e.preventDefault();if(!selU||selU.f!==ME){toast('Select a unit next to a tunnel first','bad');return;}do_({type:'flood',u:selU.id});return;}
 if(k==='e'){e.preventDefault();if(!selU||selU.f!==ME){toast('Select a land unit on a Troop Transport tile','bad');return;}do_({type:selU.on!=null?'unboard':'board',u:selU.id});return;}
 if(k==='o'){e.preventDefault();if(!selU||selU.f!==ME){toast('Select a Frigate or Assault Cruiser first','bad');return;}const bt=G.bombardTargets(S,selU);if(!bt.length){toast(G.canBombard(S,selU,G.nbrs(S,selU.at)[0])||'Nothing to bombard next to this ship','bad');return;}do_({type:'bombard',u:selU.id,at:bt[0]});return;}
 const map={j:['terra','tunnel'],b:['found'],h:['fortify'],f:['terra','farm'],m:['terra','mine'],s:['terra','solar'],r:['terra','road'],x:['terra','clear']};const a=map[k];
 if(a){e.preventDefault();if(!selU||selU.f!==ME){toast('Select a unit first (N = next unit)','bad');return;}
  if(a[0]==='terra')do_({type:'terra',u:selU.id,kind:a[1]});else if(a[0]==='found')foundDlg(selU);else do_({type:a[0],u:selU.id});}
});
/* ---------- dialogs ---------- */
function esc(s){return String(s).replace(/[&<>"]/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;'})[c]);}
function foundDlg(u){const e=G.canFound(S,u);if(e){toast(e,'bad');G.logEv(S,'player:rejected',{f:ME,action:{type:'found',u:u.id},reason:e});feed('✖ '+e);return;}
 const sug=G.suggestName(S,ME);const uid=u.id;
 modal('<h3>Found a new city</h3><p>Name: <input id="cityName" value="'+esc(sug)+'" maxlength="24" size="24"></p><button id="mOk" class="end">Found city</button> <button data-close-modal="1">Cancel</button>');
 setTimeout(()=>{const i=$('cityName');if(i){i.focus();i.select();}},20);
 $('mOk').onclick=()=>{const n=$('cityName').value;closeModal();do_({type:'found',u:uid,name:n});};}
function renameDlg(c){modal('<h3>Rename '+esc(c.name)+'</h3><p><input id="cityName" value="'+esc(c.name)+'" maxlength="24" size="24"></p><button id="mOk" class="end">Rename</button> <button data-close-modal="1">Cancel</button>');
 setTimeout(()=>{const i=$('cityName');if(i){i.focus();i.select();}},20);$('mOk').onclick=()=>{const n=$('cityName').value;closeModal();do_({type:'rename',c:c.id,name:n});};}
function ctlBtn(){if(!S||S._placeholder)return;
 if(ME>=0){do_({type:'handBack'});ME=-1;selU=null;toast('All factions AI-controlled – autoplay resumes');setSpeed(AP.prev||1);return;}
 setSpeed(0,true);
 modal('<h3>Take control</h3><p>Pick a faction to play. Autoplay pauses while you play; press <kbd>C</kbd> again to hand it back to the AI.</p>'+S.factions.filter(f=>f.alive).map(f=>'<div class="tech avail" data-ctl="'+f.id+'" style="border-color:'+f.color+'"><b style="color:'+f.color+'">'+f.name+'</b> <span class="small">'+f.pers+' · cities '+S.cities.filter(c=>c.f===f.id).length+' · score '+G.score(S,f.id)+'</span></div>').join('')+'<button data-close-modal="1">Cancel</button>');}
function takeControl(id){closeModal();const r=do_({type:'control',target:id,f:ME});if(!r.ok)return;ME=id;reveal=false;selU=null;nextUnit(true);toast('You now control '+S.factions[id].name);if(!S.factions[ME].research)setTimeout(()=>{if($('modal').hidden)research();},50);afterAction();}
function setSpeed(k,silent){if(!S)return;if(ME>=0&&k>0){toast('You are controlling a faction – hand back to AI first (C)','bad');return;}
 if(k===AP.speed&&AP.timer)return;if(AP.speed>0)AP.prev=AP.speed;AP.speed=k;if(!silent)uilog('autoplaySpeed',{speed:SPEEDS[k].n});clearTimeout(AP.timer);AP.timer=null;if(k>0)AP.timer=setTimeout(tick,SPEEDS[k].ms);top();}
function tick(){AP.timer=null;if(!S||ME>=0||S.winner!=null||!SPEEDS[AP.speed].ms&&SPEEDS[AP.speed].ms!==0)return;
 if(!$('modal').hidden&&AP.speed!==3){AP.timer=setTimeout(tick,300);return;}
 try{G.act(S,{type:'endTurn',f:-1});}catch(e){err('autoplay: '+e.message,e.stack);setSpeed(0);return;}
 liveSave('autoplay');persistGame();afterAction();
 if(S.winner==null&&ME<0&&AP.speed>0)AP.timer=setTimeout(tick,SPEEDS[AP.speed].ms);}
function endTurn(){if(S.winner!=null){feed('Game is over – start a New game or keep looking around.');statsDlg();return;}if(ME<0){toast('Autoplay – use the speed buttons','bad');return;}
 const f=S.factions[ME];if(!f.research&&G.availTechs(S,ME).length){const t=G.availTechs(S,ME)[0];do_({type:'setResearch',tech:t});feed('Auto-picked research: '+G.TECHS[t].name);}
 do_({type:'endTurn'});
 try{localStorage.setItem('colony4x_autosave',JSON.stringify(G.buildLog(S,'autosave')));}catch(e){}
 if(!LIVE&&$('autoDl').checked&&S.turn>1&&(S.turn-1)%10===0)exportLog('auto-every-10-turns');
 nextUnit();}
function statsDlg(){if(!S||S._placeholder)return;uilog('statsOpened',{});const rows=G.statsTable(S),ts=S.turnSummaries;
 let h='<h2>Statistics – turn '+S.turn+(S.winner!=null?' · '+(S.winner>=0?S.factions[S.winner].name:'nobody')+' won by '+S.winType:'')+'</h2><table class="st"><tr><th>Faction</th><th>Cities</th><th>Pop</th><th>Techs</th><th>Units</th><th>Built</th><th>Lost</th><th>Kills</th><th>Founded</th><th>Score</th></tr>'+
  rows.map(r=>'<tr><td style="color:'+S.factions[r.f].color+'">'+r.name+(r.alive?'':' ✝')+'</td><td>'+r.cities+'</td><td>'+r.pop+'</td><td>'+r.techs+'</td><td>'+r.units+'</td><td>'+r.built+'</td><td>'+r.lost+'</td><td>'+r.kills+'</td><td>'+r.founded+'</td><td><b>'+r.score+'</b></td></tr>').join('')+'</table>';
 const chart=(key,label)=>{if(ts.length<2)return'';const W=640,H=150;let mx=1;for(const s of ts)for(const f of s.factions)mx=Math.max(mx,f[key]);
  let svg='<svg width="'+W+'" height="'+(H+18)+'" style="background:#0d1117;border:1px solid #30363d"><text x="4" y="12" fill="#8b949e" font-size="11">'+label+' (max '+mx+')</text>';
  for(const f of S.factions){const pts=ts.map((s,j)=>{const v=(s.factions.find(x=>x.f===f.id)||{})[key]||0;return((j/(ts.length-1))*(W-10)+5).toFixed(1)+','+(H+14-(v/mx)*(H-10)).toFixed(1);}).join(' ');svg+='<polyline fill="none" stroke="'+f.color+'" stroke-width="2" points="'+pts+'"/>';}
  return svg+'</svg>';};
 h+=chart('score','Score over time')+chart('pop','Population')+chart('cities','Cities')+'<p><button data-close-modal="1">Close</button></p>';modal(h);}
/* ---------- live log / export ---------- */
function checkEnd(){if(S.winner!=null&&!S._endShown){S._endShown=true;clearTimeout(AP.timer);AP.timer=null;uilog('gameOver',{winner:S.winner,type:S.winType});exportLog('game-end');liveSave('game-end');statsDlg();$('mbox').insertAdjacentHTML('afterbegin','<h2>'+(ME>=0?(S.winner===ME?'Victory!':'Defeat'):'Game over')+'</h2><p class="small">col-feedback.json was downloaded – attach it to your feedback message.</p>');}}
let LIVE=false,liveT=null,liveBusy=false,liveAgain=false;const SESSION=(window.COLLOG&&window.COLLOG.pageLoad||new Date().toISOString()).replace(/[^0-9]/g,'').slice(0,14);
function makeLog(reason){const C=window.COLLOG||{};let L;try{L=S&&!S._placeholder?G.buildLog(S,reason):null;}catch(e){L=null;C.errors&&C.errors.push({type:'error',msg:'buildLog failed: '+e});}
 if(!L)L={format:'colony4x-log',version:G.VERSION,seed:null,turn:0,reason,exportedAt:new Date().toISOString(),summary:['Colony4X v'+G.VERSION+' | no game in progress | reason: '+reason,'UI events: '+(C.events||[]).length+', errors: '+(C.errors||[]).length]};
 L.session={id:SESSION,sessionStart:C.sessionStart,pageLoads:C.pageLoads,pageLoad:C.pageLoad,url:C.url,userAgent:C.userAgent,platform:C.platform,language:C.language,screen:C.screen,viewport:C.viewport,storageOK:C.storageOK,liveLog:LIVE,controlling:ME,autoplaySpeed:SPEEDS[AP.speed].n,errors:C.errors,uiEvents:C.events};
 if(L.summary)L.summary.splice(1,0,'Browser: '+C.userAgent+' | page opened '+C.pageLoad+' | UI events '+(C.events||[]).length+' | page errors '+(C.errors||[]).length+' | controlling: '+(S&&ME>=0?S.factions[ME].name:'none (autoplay)'));return L;}
function liveInd(t,c){const el=$('liveInd');if(el){el.textContent='live log: '+t;el.style.color=c;}}
function liveSave(reason){if(!LIVE)return;clearTimeout(liveT);liveT=setTimeout(()=>liveFlush(reason||'live'),400);}
function liveFlush(reason){if(liveBusy){liveAgain=true;return;}liveBusy=true;
 fetch('/api/log',{method:'POST',headers:{'Content-Type':'application/json','X-Session':SESSION},body:JSON.stringify(makeLog(reason))}).then(r=>r.json()).then(j=>{liveInd(j.ok?'on':'error',j.ok?'#3fb950':'#f85149');}).catch(()=>liveInd('lost','#f85149')).finally(()=>{liveBusy=false;if(liveAgain){liveAgain=false;liveSave(reason);}});}
window.__c4xLive=()=>liveSave('ui-event');
if(/^https?:/.test(location.protocol))fetch('/api/ping').then(r=>r.json()).then(j=>{if(j.live){LIVE=true;liveInd('on','#3fb950');liveSave('page-open');}}).catch(()=>{});
function exportLog(reason,obj){const L=obj||makeLog(reason);const b=new Blob([JSON.stringify(L,null,1)],{type:'application/json'});const a=document.createElement('a');a.href=URL.createObjectURL(b);a.download='col-feedback.json';document.body.appendChild(a);a.click();setTimeout(()=>{URL.revokeObjectURL(a.href);a.remove();},1000);feed('Feedback saved ('+reason+'): col-feedback.json');toast(obj?'Batch results saved as col-feedback.json':(S&&S._endShown&&/manual/.test(reason)?'Game end log already saved – saved again as col-feedback.json':'Saved col-feedback.json to Downloads'),'good');}
function toast(t,kind){const el=$('toast');el.textContent=t;el.className=kind==='bad'?'bad':'';el.hidden=false;clearTimeout(toast.t);toast.t=setTimeout(()=>el.hidden=true,kind==='bad'?2200:3500);if(kind==='bad'&&S&&!S._placeholder)uilog('toast',{msg:t});}
function modal(h){$('mbox').innerHTML=h;const th=$('top').offsetHeight;$('modal').style.top=th+'px';$('mbox').style.maxHeight='calc(100vh - '+(th+30)+'px)';$('modal').hidden=false;}
function closeModal(){$('modal').hidden=true;}
$('modal').addEventListener('click',e=>{if(diploClick(e))return;const pol=e.target.closest('[data-pol]');if(pol){const [ax,v]=pol.dataset.pol.split(':');do_({type:'setPolicy',axis:ax,value:v});policyDlg();return;}if(e.target.id==='modal'||e.target.closest('[data-close-modal]'))return closeModal();const t=e.target.closest('[data-tech]');if(t){do_({type:'setResearch',tech:t.dataset.tech});closeModal();return;}const c=e.target.closest('[data-ctl]');if(c)takeControl(+c.dataset.ctl);});
function research(){if(ME<0){toast('Take control of a faction first (C)','bad');return;}const f=S.factions[ME],blind=G.rule(S,'blindResearch'),av=blind?[]:G.availTechs(S,ME);let h='<h3>Research <span class="small">'+(blind?'blind research: your scientists choose':'click a green tech')+' · cost '+G.techCost(S,ME)+'</span></h3>';
 for(const k in G.TECHS){const t=G.TECHS[k],known=f.techs.includes(k),a=av.includes(k);h+='<div class="tech '+(known?'known':a?'avail':'')+(f.research===k?' cur':'')+'" '+(a?'data-tech="'+k+'"':'')+'><b>'+t.name+'</b> '+(known?'✓':'')+'<div class="small">'+t.desc+(t.pre.length?' · needs '+t.pre.map(p=>G.TECHS[p].name).join(' + '):'')+'</div></div>';}
 modal(h+'<button data-close-modal="1">Close</button>');}
function help(){modal(`<h2>Colony4X v${G.VERSION} – how to play</h2>
<p>Land on a hostile world, found cities, out-research or out-fight the rival factions. <b>Win</b> by eliminating every rival (conquest), completing the <b>Ascension Array</b> (needs Ascendant Convergence), economic reserves, land dominion, or through diplomacy (diplomatic or shared cooperative victory). At turn 300 the highest score wins.</p>
<ul><li>Click a unit to select; click an adjacent tile (arrows, numpad 1-9 with NumLock on or off, Home/PgUp/End/PgDn) to move or attack. Right-click = go to (multi-turn). Greyed units have no moves left.</li>
<li><kbd>B</kbd> found city/warren · <kbd>J</kbd> dig/repair tunnel · <kbd>K</kbd> collapse tunnel · <kbd>L</kbd> flood tunnel · <kbd>U</kbd> surface/underground view · <kbd>F</kbd> farm · <kbd>M</kbd> mine · <kbd>S</kbd> solar · <kbd>R</kbd> road · <kbd>X</kbd> clear fungus · <kbd>H</kbd> fortify · <kbd>Space</kbd>/<kbd>5</kbd> skip · <kbd>N</kbd> next unit · <kbd>T</kbd> research · <kbd>G</kbd> stats · <kbd>D</kbd> diplomacy · <kbd>V</kbd> reveal map · <kbd>Enter</kbd> end turn (glows when all units are done) · <kbd>Esc</kbd> deselect · <kbd>F9</kbd> save feedback</li>
<li><b>Autoplay:</b> tick it on the New game screen to watch the AI play every faction. Speed buttons (Pause / 1x / Fast / Max, <kbd>P</kbd> pause/resume), "Follow" moves the camera to the action. <kbd>C</kbd> = take control of any faction / hand it back to the AI – also works in normal games.</li>
<li>Tiles yield <span class="n">nutrients</span> (growth; each citizen eats 2), <span class="m">minerals</span> (production) and <span class="e">energy</span> (split by the slider into credits and labs).</li>
<li>Coloured borders show territory (city radius + 1, + 2 for big cities). You cannot found cities inside a rival's territory. Dashed boxes show your cities' work radius.</li>
<li>Magenta <b>fungus</b> spreads, yields nothing (until Mycelial Accord), slows movement and spawns Spore Beasts (ψ). Terraformers can clear it.</li>
<li>Colonists cost 1 population; cities need to be 3+ tiles apart. <b>Tidal Harvest</b> unlocks the Sea Colonist (≈): stand on the coast and press B to found a city on the adjacent ocean.</li>
<li><b>Ships (Hydrodynamic Hulls):</b> build <b>Coastal Docks</b> in a coastal city, then <b>Scout Skiffs</b>, <b>Troop Transports</b> (carry 3 land units) and <b>Frigates</b>; Naval Ordnance and Armoured Hulls bring <b>Assault Cruisers</b>. Move a land unit onto your transport to board (or <kbd>E</kbd> on the same tile); move it onto a shore tile to land. A sunk transport takes its cargo down. Frigates and Cruisers <b>bombard</b> (<kbd>O</kbd> or click) coastal cities and warren entrances next to them. Ships defend ×1.25 along coasts, ×0.9 in open ocean. With docks, Sea Colonists sail alone and found up to 3 tiles from land; Fisheries and Tidal Collectors add food/energy per worked ocean tile. Sea tiles held by sea cities count toward dominion. Try the <b>islands</b> map type.</li>
<li><b>Underground (Lithic Boring):</b> the <b>Burrower</b> (U) founds an <b>Underground Base</b> (Warren) on rocky or high ground (<kbd>B</kbd>) and digs <b>tunnels</b> tile by tile (<kbd>J</kbd>, 2 turns, 3 on rock). Warrens work the rock below: lots of minerals, no nutrients, pop cap 6 (10 with a Dome), +1 energy on tunnel tiles. They ignore fungus, beasts and surface events and defend at x1.5; enemies can only attack them from a tunnel tile or with attack-4+ units. Your units move <b>free</b> along your own tunnels (up to 8 steps a turn). An enemy that steps onto your tunnel tile <b>breaches</b> it and it becomes theirs. If your capital falls, a warren becomes the new capital if you have one. <b>Supply:</b> a warren needs at least one held surface entrance (its own shaft, or a tunnel end next to one of your cities) linked by your unflooded tunnels; an entrance is lost while an enemy unit stands next to it. Cut off, reserves drain (air fast, food slower, power): no air = population loss, units inside take damage, then it <b>surrenders</b> to the besieger. CO2 Scrubbers and Hydroponic Vats only slow the drain. <kbd>K</kbd> collapses a selected empty tunnel tile of yours (seals it, crushes intruders, the tile is lost); <kbd>L</kbd> floods a tunnel next to the selected unit (needs water alongside or Seismic Sapping); a Burrower re-digs/pumps out with <kbd>J</kbd>. <b>Seismic Sapping</b> (late tech) lets all your units assault warrens from the surface. Press <kbd>U</kbd> to see the tunnel network; on the surface, tunnel entrances are small dark squares and warrens are dark tiles with a coloured frame.</li>
<li><b>Diplomacy (<kbd>D</kbd>):</b> every faction starts at war. Once you have met a faction you can offer a <b>ceasefire</b> (lapses after 15 turns), then <b>peace</b>, then an <b>alliance</b>, plus <b>open borders</b> and <b>resource trades</b> (credits for energy or minerals over 10 turns). Under any treaty you cannot attack that faction or enter its territory (unless borders are open or you are allied) – declare war from the Diplomacy screen first. Keeping treaties raises your <b>Reputation</b>; breaking one drops it hard and rivals refuse good deals for a while. Rivals read your Reputation and their own personality: Iron fights, Lumen buys energy for research, Drift sells for credits, Verdant seeks peace. Wins: <b>diplomatic</b> and <b>cooperative</b> (shared with allies).</li>
<li>Combat: attack vs defence, modified by HP, fortify (+25%), rocky terrain (+25%), city (+25%), shield (x2). Credits buy production instantly; facilities cost upkeep.</li>
<li><b>Feedback log:</b> everything is recorded. Press <b>F9</b> / <b>Save feedback</b> anytime: it downloads <b>col-feedback.json</b> – attach it to your message.</li></ul>
<button data-close-modal="1">Close</button>`);}
function diploDlg(){if(!S||S._placeholder)return;uilog('diplomacyOpened',{});const D=G.dip(S),P=G.DIPLO,me=ME;const nm=i=>'<span style="color:'+S.factions[i].color+'">'+esc(S.factions[i].name)+'</span>';
 const relTxt=(a,b)=>{const r=D.rel[a][b];return'<span class="rel-'+r+'">'+G.REL_NAMES[r]+'</span>'+(r!=='war'?' <span class="small">since T'+D.since[a][b]+(r==='ceasefire'?', lapses T'+(D.since[a][b]+P.CEASE_TURNS):'')+'</span>':'')+(D.ob[a][b]?' <span class="small">· open borders</span>':'')+(D.contact[a][b]?'':' <span class="small">· no contact</span>');};
 const rep=i=>'<b>'+D.rep[i]+'</b> <span class="small">'+G.repLabel(D.rep[i])+(G.locked(S,i)?' · locked out until T'+D.lock[i]:'')+'</span>';
 let h='<h2>Diplomacy – turn '+S.turn+'</h2>';
 if(me>=0)h+='<p>Your Reputation: '+rep(me)+'. Honouring treaties and trade contracts raises it; breaking a ceasefire, peace or alliance costs '+P.BREAK.ceasefire+' / '+P.BREAK.peace+' / '+P.BREAK.alliance+' and locks you out of good deals for '+P.LOCK+' turns.</p>';
 else h+='<p class="small">Autoplay – read-only view of all factions.</p>';
 const pend=D.pending.filter(o=>o.to===me);
 if(me>=0&&pend.length){h+='<h4>Offers waiting for your answer</h4>';for(const o of pend)h+='<div class="tech avail">'+nm(o.from)+' offers <b>'+esc(G.dealText(S,o))+'</b>'+(o.kind==='trade'?' <span class="small">('+(o.buy?'they buy, you deliver':'they deliver, you pay')+')</span>':'')+' <button data-dans="'+o.id+':1">Accept</button> <button data-dans="'+o.id+':0">Decline</button></div>';}
 h+='<table class="st" id="dipTable"><tr><th>Faction</th>'+(me>=0?'<th>Standing with you</th>':'<th>Relations</th>')+'<th>Reputation</th><th>Diplomatic / co-op</th>'+(me>=0?'<th>Propose</th>':'')+'</tr>';
 for(const f of S.factions){if(f.id===me)continue;const j=f.id;let rels;if(me>=0)rels=relTxt(me,j);else rels=S.factions.filter(o=>o.id!==j).map(o=>'<span class="small">'+esc(o.name.split(' ')[0])+':</span> '+relTxt(j,o.id)).join('<br>');
  let acts='';if(me>=0&&f.alive){const r=D.rel[me][j];const b=(k,l)=>'<button data-dp="'+k+':'+j+'"'+(G.validDeal(S,{from:me,to:j,kind:k})?' disabled title="'+esc(G.validDeal(S,{from:me,to:j,kind:k}))+'"':'')+'>'+l+'</button>';
   acts=b('ceasefire','Ceasefire')+b('peace','Peace')+b('alliance','Alliance')+b('openBorders','Open borders')+(r!=='war'?'<button data-dwar="'+j+'" class="warbtn">Declare war</button>':'');}
  h+='<tr><td>'+nm(j)+(f.alive?'':' ✝')+'<div class="small">'+f.pers+'</div></td><td>'+rels+'</td><td>'+rep(j)+'</td><td class="small">'+(D.dipTurns[j]?'council '+D.dipTurns[j]+'/'+P.DIP_TURNS:'–')+'</td>'+(me>=0?'<td>'+acts+'</td>':'')+'</tr>';}
 h+='</table>';
 if(me>=0){const opts=S.factions.filter(f=>f.id!==me&&f.alive).map(f=>'<option value="'+f.id+'">'+esc(f.name)+'</option>').join('');
  h+='<h4>Resource trade <span class="small">(contract runs '+P.TRADE_TURNS+' turns; credits change hands at once)</span></h4><div id="dipTrade">With <select id="dtTo">'+opts+'</select> I <select id="dtBuy"><option value="1">buy</option><option value="0">sell</option></select> <input id="dtAmt" type="number" min="1" max="6" value="2" style="width:3em"> <select id="dtRes"><option value="energy">energy</option><option value="minerals">minerals</option></select> per turn for <input id="dtPrice" type="number" min="0" max="500" value="30" style="width:4em"> credits <button data-dtrade="1">Offer trade</button> <span class="small">You have '+S.factions[me].credits+' credits.</span></div>';}
 if(D.contracts.length)h+='<h4>Running contracts</h4>'+D.contracts.map(c=>'<div class="small">'+nm(c.seller)+' → '+nm(c.buyer)+': '+c.amt+' '+c.res+'/turn, '+c.left+' turns left</div>').join('');
 h+='<h4>Recent deals</h4>'+(D.deals.length?D.deals.slice(-12).reverse().map(d=>'<div class="small">T'+d.t+' '+nm(d.a)+' & '+nm(d.b)+': '+esc(d.text)+'</div>').join(''):'<div class="small">None yet.</div>');
 h+='<h4>Offer log</h4><div id="dipOffers">'+(D.offers.length?D.offers.slice(-20).reverse().map(o=>'<div class="small">T'+o.t+' '+nm(o.from)+' → '+nm(o.to)+': '+esc(G.dealText(S,o))+' – <b class="ans-'+o.answer+'">'+o.answer+'</b>'+(o.why&&o.why!=='ok'?' ('+esc(o.why)+')':'')+'</div>').join(''):'<div class="small">No offers yet.</div>')+'</div>';
 h+='<p class="small">Victories: diplomatic = council leader (top score) at peace or allied with a majority of living factions, Reputation '+P.DIP_REP+'+, for '+P.DIP_TURNS+' turns (from turn '+P.MIN_TURN+')'+(G.rule(S,'diplomatic')?'':' – OFF')+'; cooperative = shared win when all survivors are allied, or an alliance holds '+Math.round(P.COOP_SHARE*100)+'% of the land, for '+P.COOP_TURNS+' turns'+(G.rule(S,'cooperative')?'':' – OFF')+'.</p>';
 modal(h+'<button data-close-modal="1">Close</button>');}
function diploClick(e){const t=e.target;if(!t.closest)return false;let b=t.closest('[data-dp]');if(b){const [k,j]=b.dataset.dp.split(':');do_({type:'propose',to:+j,kind:k});diploDlg();return true;}
 b=t.closest('[data-dwar]');if(b){const j=+b.dataset.dwar,r=G.dip(S).rel[ME][j];if(confirm('Break your '+G.REL_NAMES[r].toLowerCase()+' with '+S.factions[j].name+'? Your Reputation drops by '+(G.DIPLO.BREAK[r]||0)+' and good deals are locked for '+G.DIPLO.LOCK+' turns.')){do_({type:'declareWar',to:j});}diploDlg();return true;}
 b=t.closest('[data-dans]');if(b){const [id,acc]=b.dataset.dans.split(':');do_({type:'answer',id:+id,accept:acc==='1'});diploDlg();return true;}
 b=t.closest('[data-dtrade]');if(b){do_({type:'propose',to:+$('dtTo').value,kind:'trade',buy:$('dtBuy').value==='1',res:$('dtRes').value,amt:+$('dtAmt').value,price:+$('dtPrice').value});diploDlg();return true;}
 return false;}
function policyDlg(){if(ME<0){toast('Take control of a faction first (C)','bad');return;}const f=S.factions[ME],p=f.policy||{};let h='<h3>Social policy <span class="small">changing costs 30 credits · you have '+f.credits+'</span></h3>';
 for(const ax in G.POLICIES){const A=G.POLICIES[ax];h+='<h4>'+A.label+'</h4>';for(const k in A.opts){const o=A.opts[k],cur=(p[ax]||'balanced')===k;h+='<div class="tech '+(cur?'cur':'avail')+'" '+(cur?'':'data-pol="'+ax+':'+k+'"')+'><b>'+o.name+'</b>'+(cur?' ✓':'')+'<div class="small">'+o.desc+'</div></div>';}}
 modal(h+'<button data-close-modal="1">Close</button>');}
function lastSettings(){try{return JSON.parse(localStorage.getItem('c4x_last')||'null');}catch(e){return null;}}
const RULE_LABELS={conquest:'Conquest victory (eliminate all rivals)',ascension:'Ascension victory (Beacon → Array → 12-turn charge)',economic:'Economic victory ('+G.ECON_TARGET+' credits in reserve)',dominion:'Dominion victory ('+Math.round(G.DOMINION_SHARE*100)+'% of land for '+G.DOMINION_TURNS+' turns)',fullMap:'Full map survey (whole map visible from the start)',accelerated:'Accelerated start (extra units, 2 techs, credits)',slowResearch:'Slower research (+50% tech cost)',blindResearch:'Blind research (your scientists pick techs)',aggressive:'Aggressive rivals',events:'Random events',diplomatic:'Diplomatic victory (council leader at peace/allied with a majority, Reputation '+G.DIPLO.DIP_REP+'+, '+G.DIPLO.DIP_TURNS+' turns)',cooperative:'Cooperative victory (shared win with allies, '+G.DIPLO.COOP_TURNS+' turns)'};
function menu(){setSpeed(0,true);const L=lastSettings();
 modal('<h2 style="text-align:center">Colony4X <span class="small">v'+G.VERSION+'</span></h2><div class="menu">'+[['start','Start game'],['quick','Quick start'+(L?' <span class="small">('+G.DIFFICULTY[L.difficulty].name+', '+(G.FACTIONS.find(f=>f.key===L.playerKey)||{}).name+')</span>':'')],['load','Load game'],['watch','Watch autoplay'],['batch','Batch run (balance test)'],['credits','Credits']].map(m=>'<button data-menu="'+m[0]+'">'+m[1]+'</button>').join('')+'</div>');
 $('mbox').onclick=e=>{const b=e.target.closest('[data-menu]');if(!b)return;const m=b.dataset.menu;uilog('menu',{item:m});
  if(m==='start')setupDlg(false);else if(m==='batch')batchDlg();else if(m==='watch')setupDlg(true);
  else if(m==='quick'){const st=Object.assign({playerKey:'lumen',numAI:2,w:48,h:32,difficulty:2,rules:Object.assign({},G.DEFAULT_RULES),autoplay:false},L||{});st.seed=(Math.random()*1e9)|0;launch(st);}
  else if(m==='load'){$('mbox').onclick=null;closeModal();$('bLoad').click();}
  else if(m==='credits')modal('<h2>Credits</h2><p>Colony4X – a clean-room, browser-based 4X game built by Grok Bot for Robert Boettcher.</p><p>All names, text and graphics are original. Mechanics are loosely inspired by the classic genre of alien-planet colonisation games.</p><button data-close-modal="1">Back</button>');};}
function setupDlg(ap){const L=lastSettings()||{};const R=Object.assign({},G.DEFAULT_RULES,L.rules||{});const std=JSON.stringify(R)===JSON.stringify(G.DEFAULT_RULES);const dsel=L.difficulty==null?2:L.difficulty;
 let h='<h2>New game</h2><h4>1 · Rules</h4><label><input type="radio" name="rmode" value="std" '+(std?'checked':'')+'> Standard</label> <label><input type="radio" name="rmode" value="custom" '+(std?'':'checked')+'> Customize</label><div id="rulesBox" class="rules"'+(std?' hidden':'')+'>'+Object.keys(RULE_LABELS).map(k=>'<label><input type="checkbox" data-rule="'+k+'" '+(R[k]?'checked':'')+'> '+RULE_LABELS[k]+'</label>').join('')+'<div class="small">A score victory at turn 300 always applies. Diplomacy (D) is always on; the two switches above only control its victories.</div></div>';
 h+='<h4>2 · Difficulty</h4>'+G.DIFFICULTY.map((d,i)=>'<label class="diff"><input type="radio" name="diff" value="'+i+'" '+(i===dsel?'checked':'')+'> <b>'+d.name+'</b> <span class="small">'+d.desc+'</span></label>').join('');
 h+='<h4>3 · Map</h4><p>Size: <select id="msz"><option value="40x26">small</option><option value="48x32" selected>normal</option><option value="64x40">large</option></select> Type: <select id="mtype"><option value="">continent</option><option value="islands">islands</option></select> Rivals: <select id="nAI"><option>1</option><option selected>2</option><option>3</option></select> Seed: <input id="seedIn" size="10" placeholder="random"> <label><input type="checkbox" id="apCb" '+(ap?'checked':'')+'> <b>Autoplay (watch AI play all factions)</b></label></p>';
 h+='<h4>4 · Faction <span class="small">(click to start)</span></h4>'+G.FACTIONS.map(F=>'<div class="tech avail" data-fk="'+F.key+'" style="border-color:'+F.color+'"><b style="color:'+F.color+'">'+F.name+'</b> – '+F.leader+'<div class="small">'+F.pers+' · '+F.bonus+'</div></div>').join('')+'<button data-back="1">◀ Menu</button>';
 modal(h);if(L.w)$('msz').value=L.w+'x'+L.h;if(L.numAI)$('nAI').value=String(L.numAI);if(L.map)$('mtype').value=L.map;
 $('mbox').onchange=e=>{if(e.target.name==='rmode')$('rulesBox').hidden=e.target.value==='std';};
 $('mbox').onclick=e=>{if(e.target.closest('[data-back]')){menu();return;}const d=e.target.closest('[data-fk]');if(!d)return;
  const custom=document.querySelector('input[name=rmode]:checked').value==='custom';const rules=Object.assign({},G.DEFAULT_RULES);if(custom)document.querySelectorAll('[data-rule]').forEach(cb=>rules[cb.dataset.rule]=cb.checked);
  const [w,hh]=$('msz').value.split('x').map(Number);const st={playerKey:d.dataset.fk,numAI:+$('nAI').value,w,h:hh,difficulty:+document.querySelector('input[name=diff]:checked').value,rules,map:$('mtype').value||undefined,autoplay:$('apCb').checked,seed:parseInt($('seedIn').value)||((Math.random()*1e9)|0)};
  try{const sv=Object.assign({},st);delete sv.seed;localStorage.setItem('c4x_last',JSON.stringify(sv));}catch(x){}launch(st);};}
function launch(st){$('mbox').onclick=null;$('mbox').onchange=null;closeModal();uilog('newGame',{settings:st});
 start(G.newGame({seed:st.seed,playerKey:st.playerKey,numAI:st.numAI,w:st.w,h:st.h,map:st.map,difficulty:st.difficulty,rules:st.rules,allAI:!!st.autoplay,autoplay:!!st.autoplay}));if(st.autoplay){uilog('autoplayStart',{});setSpeed(1);}}
const newGameDlg=menu;
const BATCH={running:false,cancel:false};
function batchDlg(){const L=lastSettings()||{};const R=Object.assign({},G.DEFAULT_RULES,L.rules||{});
 modal('<h2>Batch run</h2><p class="small">Plays N complete AI-only games as fast as possible, then downloads one compact col-feedback.json with per-game summaries (seeds included for exact replay).</p>'+
 '<p>Games: <input id="bN" type="number" value="10" min="1" max="200" style="width:60px"> Factions: <select id="bF"><option>2</option><option>3</option><option selected>4</option></select> Difficulty: <select id="bD">'+G.DIFFICULTY.map((d,i)=>'<option value="'+i+'"'+(i===2?' selected':'')+'>'+d.name+'</option>').join('')+'</select> Map: <select id="bM"><option value="40x26">small</option><option value="48x32" selected>normal</option><option value="64x40">large</option></select></p>'+
 '<p>Seeds: <label><input type="radio" name="bS" value="rand" checked> random</label> <label><input type="radio" name="bS" value="fixed"> fixed, starting at <input id="bSeed" size="8" value="1"></label></p>'+
 '<details><summary>Rules</summary><div class="rules">'+Object.keys(RULE_LABELS).map(k=>'<label><input type="checkbox" data-brule="'+k+'" '+(R[k]?'checked':'')+'> '+RULE_LABELS[k]+'</label>').join('')+'</div></details>'+
 '<p><button id="bGo" class="end">Run batch</button> <button data-back="1">◀ Menu</button></p><div id="bProg"></div><div id="bRes"></div>');
 $('mbox').onclick=e=>{if(e.target.closest('[data-back]')){if(BATCH.running)BATCH.cancel=true;menu();return;}if(e.target.id==='bGo')runBatch();if(e.target.id==='bCancel'){BATCH.cancel=true;}};}
function runBatch(){if(BATCH.running)return;const n=Math.max(1,Math.min(200,+$('bN').value||10)),F=+$('bF').value,D=+$('bD').value,[w,h]=$('bM').value.split('x').map(Number);
 const rules=Object.assign({},G.DEFAULT_RULES);document.querySelectorAll('[data-brule]').forEach(cb=>rules[cb.dataset.brule]=cb.checked);
 const fixed=document.querySelector('input[name=bS]:checked').value==='fixed',seed0=parseInt($('bSeed').value)||1;
 const settings={games:n,factions:F,difficulty:D,difficultyName:G.DIFFICULTY[D].name,w,h,rules,seeds:fixed?'fixed from '+seed0:'random'};
 uilog('batchStart',settings);BATCH.running=true;BATCH.cancel=false;$('bGo').disabled=true;const res=[];const t0=Date.now();let i=0,G1=null;
 const keys=G.FACTIONS.map(f=>f.key);
 $('bProg').innerHTML='<div class="pbar"><div id="pbFill"></div></div><div id="pbTxt"></div><button id="bCancel">Cancel</button>';
 function newOne(){const seed=fixed?seed0+i:((Math.random()*1e9)|0);const fk=G.fairLineup(i,F);G1=G.newGame({seed,allAI:true,numAI:F-1,playerKey:fk[0],factionKeys:fk,w,h,difficulty:D,rules,maxTurns:300});G1.errors=[];}
 newOne();
 function step(){if(BATCH.cancel){finish(true);return;}const end=Date.now()+40;
  try{while(Date.now()<end){G.act(G1,{type:'endTurn',f:-1});if(G1.winner!=null){res.push(G.gameSummary(G1));i++;if(i>=n){finish(false);return;}newOne();}}}catch(e){G1.errors.push({msg:String(e&&e.message||e),stack:e&&e.stack});res.push(G.gameSummary(G1));i++;err('batch game '+i+': '+e.message,e.stack);if(i>=n){finish(false);return;}newOne();}
  const pct=((i+Math.min(1,G1.turn/300))/n*100);$('pbFill').style.width=pct.toFixed(1)+'%';$('pbTxt').textContent='Game '+(i+1)+'/'+n+' · turn '+G1.turn+' · '+((Date.now()-t0)/1000).toFixed(0)+' s';setTimeout(step,0);}
 function finish(cancelled){BATCH.running=false;$('bGo').disabled=false;$('bProg').innerHTML=cancelled?'<p>Cancelled after '+res.length+' games.</p>':'<p>Done: '+res.length+' games in '+((Date.now()-t0)/1000).toFixed(1)+' s.</p>';
  const agg={winners:{},winTypes:{},avgTurns:0};for(const r of res){agg.winners[r.winnerName||'none']=(agg.winners[r.winnerName||'none']||0)+1;agg.winTypes[r.winType]=(agg.winTypes[r.winType]||0)+1;agg.avgTurns+=r.turns/(res.length||1);}agg.avgTurns=Math.round(agg.avgTurns);
  let h='<h3>Results</h3><p class="small">Winners: '+Object.entries(agg.winners).map(([k,v])=>k+' '+v).join(', ')+' · win types: '+Object.entries(agg.winTypes).map(([k,v])=>k+' '+v).join(', ')+' · average length '+agg.avgTurns+' turns</p><table class="st"><tr><th>#</th><th>Seed</th><th>Winner</th><th>Type</th><th>Turns</th><th>Final (cities/pop/score)</th></tr>'+
   res.map((r,k)=>'<tr><td>'+(k+1)+'</td><td>'+r.seed+'</td><td>'+(r.winnerName||'–')+'</td><td>'+r.winType+'</td><td>'+r.turns+'</td><td style="text-align:left">'+r.final.map(x=>'<span style="color:'+G.FACTIONS.find(F=>F.name===x.name).color+'">'+x.name.split(' ')[0]+' '+x.cities+'/'+x.pop+'/'+x.score+'</span>').join(' · ')+'</td></tr>').join('')+'</table>';
  $('bRes').innerHTML=h;uilog('batchDone',{games:res.length,cancelled,winners:agg.winners});
  const C=window.COLLOG||{};const out={format:'colony4x-batch',version:G.VERSION,exportedAt:new Date().toISOString(),cancelled,settings,aggregate:agg,games:res,session:{userAgent:C.userAgent,pageLoad:C.pageLoad,errors:C.errors}};
  if(res.length)exportLog('batch',out);}
 setTimeout(step,0);}

function start(s){clearTimeout(AP.timer);AP.timer=null;AP.speed=0;S=s;S.errors=S.errors||[];if(S.human==null)S.human=S.factions.findIndex(f=>!f.ai);ME=S.human;selU=null;selC=null;selTile=-1;lastLogShown=S.log.length;$('feed').innerHTML='';
 feed('Game started – '+(ME>=0?S.factions[ME].name:'autoplay')+', seed '+S.seed+'. Press ? for help.');
 const u=S.units.find(u=>u.f===(ME>=0?ME:0));if(u)setTimeout(()=>scrollTo(u.at),0);nextUnit(true);afterAction();
 if(S.turn===1&&!S._t1Saved){S._t1Saved=true;setTimeout(()=>{if(LIVE)liveSave('turn-1-start');else if($('autoDl').checked)exportLog('turn-1-start');},600);}
 if(ME>=0&&!S.factions[ME].research&&!G.rule(S,'blindResearch'))setTimeout(()=>{if($('modal').hidden)research();},50);}
$('bEnd').onclick=endTurn;$('bExport').onclick=()=>exportLog('manual');$('bHelp').onclick=help;$('bResearch').onclick=research;$('bNew').onclick=newGameDlg;$('bStats').onclick=statsDlg;$('bCtl').onclick=ctlBtn;$('bPolicy').onclick=policyDlg;if($('bDiplo'))$('bDiplo').onclick=diploDlg;if($('bView'))$('bView').onclick=()=>setView(!UG);
for(let k=0;k<SPEEDS.length;k++)$('sp'+k).onclick=()=>setSpeed(k);
$('revealCb').onchange=e=>{reveal=e.target.checked;afterAction();};$('followCb').onchange=e=>{follow=e.target.checked;uilog('follow',{on:follow});};
$('labs').oninput=e=>{if(ME>=0)do_({type:'setLabs',v:e.target.value/100},true);};
$('bSave').onclick=()=>{try{localStorage.setItem('colony4x_save',JSON.stringify(G.buildLog(S,'save')));feed('Game saved to browser storage.');toast('Game saved');}catch(e){toast('Save failed: '+e.message,'bad');}};
$('bLoad').onclick=()=>{const s=localStorage.getItem('colony4x_save')||localStorage.getItem('colony4x_autosave');if(!s)return toast('No save found','bad');start(G.loadFromLog(JSON.parse(s)));feed('Loaded save (turn '+S.turn+').');};
$('bLoadLog').onclick=()=>$('fileLog').click();
$('fileLog').onchange=e=>{const f=e.target.files[0];if(!f)return;f.text().then(t=>{const L=JSON.parse(t);if(L.format!=='colony4x-log'||!L.snapshot)return toast('Not a Colony4X game log','bad');start(G.loadFromLog(L));feed('State loaded from log '+f.name+' (turn '+S.turn+')');e.target.value='';});};
window.__c4x={get S(){return S},get ME(){return ME},get view(){return UG?'underground':'surface'},setView,setSpeed,takeControl,clickTile,sel(id){selU=S.units.find(u=>u.id===id)||null;selC=null;afterAction();}};
// boot: resume autosave if present
function placeholder(){const g=G.newGame({});g._t1Saved=true;g._placeholder=true;start(g);newGameDlg();}
try{const a=localStorage.getItem('colony4x_autosave');if(a){const L=JSON.parse(a);if(L.version===G.VERSION&&L.snapshot&&L.snapshot.winner==null){start(G.loadFromLog(L));feed('Resumed autosave. Click New for a fresh game.');if(ME<0)setSpeed(0);}else placeholder();}else placeholder();}catch(e){placeholder();}
})();
