/* Colony4X core rules engine - pure logic, no DOM. Runs in browser and node. */
(function(root){
'use strict';
const DOMINION_SHARE=0.5,DOMINION_TURNS=10,ECON_TARGET=3000;
const DIFFICULTY=[
 {name:'Cadet',mor:0.6,ai:0.7,hu:1.15,nat:0.6,desc:'Learning level: rivals build and research 30% slower, you get +15% minerals and labs, fewer Spore Beasts. Citizens are patient (low unrest pressure).'},
 {name:'Homesteader',mor:0.8,ai:0.85,hu:1.05,nat:0.8,desc:'Relaxed: rivals 15% slower, you +5%. Mild unrest pressure.'},
 {name:'Steward',mor:1,ai:1,hu:1,nat:1,desc:'Even footing: everyone plays by the same numbers.'},
 {name:'Commander',mor:1.2,ai:1.15,hu:1,nat:1.1,desc:'Rivals get +15% minerals and labs. Your citizens are more demanding (+20% unrest pressure).'},
 {name:'Archon',mor:1.4,ai:1.3,hu:0.95,nat:1.25,desc:'Rivals +30%, you -5%, more Spore Beasts. Your citizens are restless (+40% unrest pressure).'},
 {name:'Paragon',mor:1.6,ai:1.5,hu:0.9,nat:1.5,desc:'Brutal: rivals +50%, you -10%, natives swarm. Your citizens are hard to please (+60% unrest pressure).'}];
const DEFAULT_RULES={conquest:true,ascension:true,economic:true,dominion:true,fullMap:false,accelerated:false,slowResearch:false,blindResearch:false,aggressive:false,events:true,diplomatic:true,cooperative:true};
const POLICIES={
 econ:{label:'Economy',def:'balanced',opts:{
  balanced:{name:'Balanced Ledger',desc:'No modifiers.'},
  open:{name:'Open Exchange',desc:'+20% energy, −10% minerals; Reputation gains +25%.',en:1.2,min:0.9,rep:1.25},
  directed:{name:'Directed Output',desc:'+15% minerals, −15% energy.',min:1.15,en:0.85},
  symbiotic:{name:'Symbiotic Charter',desc:'+1 nutrient per city, −10% minerals; the fungus-minded like you more.',food:1,min:0.9,fungRel:5}}},
 focus:{label:'Focus',def:'balanced',opts:{
  balanced:{name:'Civic Balance',desc:'No modifiers.'},
  inquiry:{name:'Inquiry Mandate',desc:'+20% labs, −10% minerals.',labs:1.2,min:0.9},
  vigilance:{name:'Vigilance Doctrine',desc:'+20% attack, −15% labs; war weariness −25%.',wwMul:0.75,att:1.2,labs:0.85},
  prosperity:{name:'Prosperity Pact',desc:'+1 nutrient per city, −10% labs; +1 morale.',food:1,labs:0.9,mor:1}}},
 society:{label:'Society',def:'civic',opts:{
  civic:{name:'Civic Assembly',desc:'Citizens feel heard: +1 morale in every city.',mor:1},
  merit:{name:'Merit Councils',desc:'Research costs −12%; cities grow 10% slower.',tech:0.88,growth:1.1},
  frontier:{name:'Frontier Charter',desc:'Colonists cost −30%, cities grow 10% faster; +1 credit upkeep per 4 cities, −5% labs, −1 morale.',mor:-1,col:0.7,growth:0.9,upkeep:0.25,labs:0.95},
  martial:{name:'Martial Levy',desc:'Military units cost −10%; garrisons keep order (+1 morale per military unit in a city, max 2), war weariness halved; Reputation gains −25%, switching causes double unrest.',law:1,wwMul:0.5,unit:0.9,rep:0.75,unrest:2}}},
 env:{label:'Environment',def:'managed',opts:{
  managed:{name:'Managed Land',desc:'No modifiers.'},
  extractive:{name:'Extractive Drive',desc:'+12% minerals, −1 morale; more Spore Beasts spawn and fungus-minded factions resent you.',mor:-1,min:1.12,beast:1.5,fungRel:-12},
  harmony:{name:'Fungal Harmony',desc:'Move freely through fungus, beasts often leave you alone, fungus-minded like you, nearby fungus soothes citizens; −10% minerals.',fsoothe:1,fmove:1,calm:1,fungRel:10,min:0.9},
  reclaim:{name:'Reclamation Corps',desc:'Terraforming 35% faster, +1 energy per 3 cities; −5% energy elsewhere, fungus-minded resent you a little.',terra:0.65,enCity:1/3,en:0.95,fungRel:-5}}}};
const POLICY_AXES=['econ','focus','society','env'];

/* ---------- morale & unrest (v0.8) ---------- */
const MOOD_NAMES={content:'Content',restless:'Restless',rioting:'Rioting'};
function pressure(S,fid){return isHumanLike(S,fid)?(diff(S).mor||1):1;}
function morale(S,c){const fid=c.f,f=fac(S,fid),pm=policyMods(S,fid),P=[];let pos=0,neg=0;const add=(k,v)=>{if(!v)return;v=Math.round(v*100)/100;P.push([k,v]);if(v>0)pos+=v;else neg-=v;};
 add('base',3);add('policy',pm.mor);
 let ent=0;for(const k of c.fac)if(FAC[k]&&FAC[k].ent)ent+=FAC[k].ent;add('entertainment',ent);
 if(c.fac.indexOf('dome')>=0)add('dome',1);
 add('size',-Math.max(0,c.pop-5)*0.4);
 const nc=S.cities.filter(x=>x.f===fid).length;add('empire',-Math.max(0,nc-6)*0.25);
 if(!c.ug){let nf=0;for(const i of nbrs(S,c.at,2))if(S.tiles[i].f)nf++;if(pm.fsoothe||f.pers==='eco')add('fungus',Math.min(1,nf/8));else add('fungus',-Math.min(2,nf/5));}
 add('war',-Math.min(3,(f.ww||0)/3*pm.wwMul));
 if(pm.law){let g=0;for(const u of S.units)if(u.at===c.at&&u.f===fid&&!UNITS[u.type].civ&&!isShip(u))g++;add('garrison',Math.min(2,g));}
 if(f.unrest>0)add('policySwitch',-2);
 let ev=0;if(c.mev)for(const e of c.mev)if(e.u>=S.turn)ev+=e.v;add('events',ev);
 const pr=pressure(S,fid),v=Math.round((pos-neg*pr)*10)/10;
 return{v,mood:v>=0?'content':v>-3?'restless':'rioting',parts:P,pressure:pr};}
function moodEvent(S,c,v,turns,why){(c.mev=c.mev||[]).push({v,u:S.turn+turns,why});if(c.mev.length>6)c.mev.shift();}
function riot(S,c){const fid=c.f,s=st(S,fid);s.riots=(s.riots||0)+1;const r=rand(S);let kind='idle',detail='';
 if(r>=0.55&&r<0.85){const sel=c.fac.filter(k=>!FAC[k].project&&!FAC[k].ent);if(sel.length){const k=sel[ri(S,sel.length)];c.fac.splice(c.fac.indexOf(k),1);kind='sold';detail=FAC[k].name;s.riotSold=(s.riotSold||0)+1;}}
 else if(r>=0.85&&!c.ug){const cand=nbrs(S,c.at).filter(i=>S.tiles[i].land&&!cityAt(S,i)&&!S.units.some(u=>u.at===i));if(cand.length){const at=cand[ri(S,cand.length)];makeUnit(S,-1,'rebel',at);kind='rebels';detail='at '+at;s.rebels=(s.rebels||0)+1;}}
 if(kind==='idle'){const n=Math.min(2,c.worked.length);c.worked.splice(c.worked.length-n,n);detail=n+' tiles idle';s.riotIdle=(s.riotIdle||0)+1;}
 logEv(S,'riot',{f:fid,city:c.name,kind,detail,v:c.mor});return kind;}
function cityMorale(S,c){const m=morale(S,c),prev=c.mood||'content';c.mor=m.v;c.mood=m.mood;if(m.mood!==prev){const worst=m.parts.filter(x=>x[1]<0).sort((a,b)=>a[1]-b[1])[0];logEv(S,'moraleShift',{f:c.f,city:c.name,from:prev,to:m.mood,v:m.v,why:worst?worst[0]:'',ai:!!fac(S,c.f).ai});const s=st(S,c.f);s.moraleShifts=(s.moraleShifts||0)+1;}
 if(c.mev)c.mev=c.mev.filter(e=>e.u>=S.turn);if(m.mood!=='content'){const s=st(S,c.f);s.unhappyTurns=(s.unhappyTurns||0)+1;}return m;}
function polOf(S,fid,ax){const p=fac(S,fid).policy||{};return p[ax]||POLICIES[ax].def;}
function policyMods(S,fid){const f=fac(S,fid),m={en:1,min:1,labs:1,att:1,food:0,tech:1,growth:1,col:1,unit:1,sup:0,upkeep:0,rep:1,fungRel:0,beast:1,fmove:0,calm:0,terra:1,enCity:0,unrest:1,mor:0,law:0,wwMul:1,fsoothe:0};
 for(const ax of POLICY_AXES){const o=POLICIES[ax].opts[polOf(S,fid,ax)];if(!o)continue;for(const k of ['en','min','labs','att','tech','growth','col','unit','rep','beast','terra','unrest','wwMul'])if(o[k]!=null)m[k]*=o[k];for(const k of ['food','sup','upkeep','fungRel','fmove','calm','enCity','mor','law','fsoothe'])if(o[k])m[k]+=o[k];}
 if(f.unrest>0){m.min*=0.85;m.labs*=0.85;m.unrestNow=f.unrest;}return m;}
function switchCost(S,fid){if(S.turn<20)return 0;const nc=S.cities.filter(c=>c.f===fid).length;return 20+3*nc;}
function setPolicy(S,fid,ax,v,why){const f=fac(S,fid),A=POLICIES[ax];if(!A||!A.opts[v])return'Unknown policy';const cur=polOf(S,fid,ax);if(cur===v)return'Already in force';const cost=switchCost(S,fid);if(f.credits<cost)return'Changing policy costs '+cost+' credits';
 f.credits-=cost;f.policy=Object.assign({},f.policy||{});f.policy[ax]=v;let un=0;if(S.turn>=20){const m=Math.max(A.opts[cur].unrest||1,A.opts[v].unrest||1);un=Math.round(3*m);f.unrest=Math.max(f.unrest||0,un);}
 f.polT=f.polT||{};f.polT[ax]=S.turn;const s=st(S,fid);s.policyChanges=(s.policyChanges||0)+1;
 logEv(S,'policyChanged',{f:fid,axis:ax,from:cur,to:v,name:A.opts[v].name,cost,unrest:un,why:why||'player'});return null;}
const AI_POLICY={militant:{econ:'directed',focus:'vigilance',society:'martial',env:'managed'},scholarly:{econ:'open',focus:'inquiry',society:'merit',env:'managed'},eco:{econ:'symbiotic',focus:'prosperity',society:'frontier',env:'harmony'},expansionist:{econ:'open',focus:'prosperity',society:'frontier',env:'reclaim'}};
function rule(S,k){const r=S.opts.rules||DEFAULT_RULES;return k in r?!!r[k]:DEFAULT_RULES[k];}
function diff(S){return DIFFICULTY[S.opts.difficulty==null?2:S.opts.difficulty]||DIFFICULTY[2];}
function bigScale(W,H){return 1+(Math.max(1,W*H/1536)-1)*0.55;}
function domShare(S){return S.turn>200?Math.max(0.4,DOMINION_SHARE-(S.turn-200)*0.002):DOMINION_SHARE;}
function econTarget(S){return Math.round(ECON_TARGET*(1+(Math.max(1,S.W*S.H/1536)-1)*0.25)/100)*100;}
function graceTurn(S){const small=Math.max(0,Math.round((48*32-S.W*S.H)/60));return 50-(S.opts.difficulty==null?2:S.opts.difficulty)*3+small;}
/* fair batch line-ups: cycle every faction subset and rotate start slots so each faction appears equally often */
function fairLineup(i,n){const keys=FACTIONS.map(f=>f.key),combos=[];(function rec(st,a){if(a.length===n){combos.push(a);return;}for(let k=st;k<keys.length;k++)rec(k+1,a.concat([keys[k]]));})(0,[]);const c=combos[i%combos.length],r=Math.floor(i/combos.length)%n;return c.slice(r).concat(c.slice(0,r));}
function isHumanLike(S,fid){return !fac(S,fid).ai||(S.opts.simHuman===fid);}
function mulFor(S,fid){const d=diff(S);return isHumanLike(S,fid)?d.hu:d.ai;}
const EVENTS=[
 {k:'windfall',name:'Mineral windfall',run:(S,f,c)=>{c.prod+=25;return c.name+' strikes a rich vein: +25 production';}},
 {k:'pod',name:'Supply pod',run:(S,f,c)=>{f.credits+=40;moodEvent(S,c,1,6,'supply pod');return 'An orbital supply pod lands near '+c.name+': +40 credits';}},
 {k:'flare',name:'Solar flare',run:(S,f,c)=>{const l=Math.min(f.credits,25);f.credits-=l;return 'A solar flare fries grid relays: -'+l+' credits';}},
 {k:'harvest',name:'Bumper harvest',run:(S,f,c)=>{c.food=foodBox(S,c)-1;moodEvent(S,c,1,8,'harvest');return c.name+' enjoys a bumper harvest';}},
 {k:'bloom',name:'Fungal bloom',run:(S,f,c)=>{moodEvent(S,c,f.pers==='eco'||policyMods(S,f.id).fsoothe?1:-1,8,'bloom');let n=0;for(const i of nbrs(S,c.at,3)){const t=S.tiles[i];if(t.land&&!t.f&&!t.imp&&!cityAt(S,i)&&rand(S)<0.3){t.f=true;n++;}}return 'Fungus blooms around '+c.name+' ('+n+' tiles)';}},
 {k:'surge',name:'Spore surge',run:(S,f,c)=>{const cand=nbrs(S,c.at,4).filter(i=>S.tiles[i].land&&dist(S,i,c.at)>=3&&!S.units.some(u=>u.at===i)&&!cityAt(S,i));if(!cand.length)return null;makeUnit(S,-1,'beast',cand[ri(S,cand.length)]);return 'A Spore Beast surges out of the wilds near '+c.name;}}];
function randomEvents(S){if(!rule(S,'events')||S.turn<graceTurn(S))return;for(const f of S.factions){if(!f.alive)continue;if(rand(S)>=0.035)continue;const cs=S.cities.filter(c=>c.f===f.id&&!c.ug);if(!cs.length)continue;const c=cs[ri(S,cs.length)];const E=EVENTS[ri(S,EVENTS.length)];const msg=E.run(S,f,c);if(msg)logEv(S,'randomEvent',{f:f.id,event:E.name,city:c.name,at:c.at,msg});}}
const VERSION='0.8';
const TECHS={
 soil:{name:'Soil Lattice Genetics',pre:[],desc:'Unlocks Hydroponic Vats.'},
 deep:{name:'Deep Core Sampling',pre:[],desc:'Unlocks Fabricator.'},
 photon:{name:'Photonic Weave',pre:[],desc:'Terraformers can build Solar Collectors.'},
 kinetic:{name:'Kinetic Arms',pre:[],desc:'Unlocks Lancer (attack 4).'},
 signal:{name:'Signal Theory',pre:[],desc:'+10% research. Unlocks Dreamweave Theatre (+3 morale).'},
 lattice:{name:'Lattice Armor',pre:['deep'],desc:'Unlocks Warden (defence 3).'},
 field:{name:'Field Projection',pre:['lattice','photon'],desc:'Unlocks Perimeter Shield (city defence x2).'},
 neural:{name:'Neural Archive',pre:['signal'],desc:'Unlocks Data Spire (+50% labs).'},
 tidal:{name:'Tidal Harvest',pre:['soil'],desc:'Sea tiles +1 nutrients. Unlocks Sea Colonist (found cities on the ocean).'},
 myco:{name:'Mycelial Accord',pre:['soil','signal'],desc:'Fungus tiles yield 1/1/2 and cost normal movement.'},
 habitat:{name:'Habitat Engineering',pre:['soil','deep'],desc:'Unlocks Habitat Dome (pop cap 8 -> 14).'},
 plasma:{name:'Plasma Lance',pre:['kinetic','photon'],desc:'Unlocks Striker (attack 6).'},
 gravitic:{name:'Gravitic Drives',pre:['plasma','field'],desc:'Unlocks Skimmer (attack 5, 3 moves).'},
 quantum:{name:'Quantum Cognition',pre:['neural','photon'],desc:'+25% research.'},
 synth:{name:'Synthetic Sentience',pre:['quantum','habitat'],desc:'+2 minerals in every city.'},
 sapper:{name:'Seismic Sapping',pre:['boring','plasma'],desc:'Your units can assault Underground Bases from the surface (no x1.5 warren defence against you) and flood any tunnel.'},
 boring:{name:'Lithic Boring',pre:['deep'],desc:'Unlocks the Burrower: founds Underground Bases (Warrens) on rocky or high ground and digs tunnels.'},
 naval:{name:'Hydrodynamic Hulls',pre:['tidal'],desc:'Unlocks Coastal Docks, Scout Skiff, Troop Transport, Fisheries and Tidal Collectors. With Docks, Sea Colonists sail and found up to 3 tiles from land.'},
 ordnance:{name:'Naval Ordnance',pre:['naval','kinetic'],desc:'Unlocks the Frigate (attack 3, bombards coastal cities and warren entrances).'},
 dread:{name:'Armoured Hulls',pre:['ordnance','plasma'],desc:'Unlocks the Assault Cruiser (attack 6, defence 5, 4 moves, bombards).'},
 ascend:{name:'Ascendant Convergence',pre:['synth','myco'],desc:'Unlocks the Resonance Beacon (stage 1 of the ascension victory).'}
};
const UNITS={
 colonist:{name:'Colonist',cost:30,a:0,d:1,mv:1,civ:1,found:1,ch:'C',desc:'Founds a new city (B). Costs 1 pop.'},
 seacolony:{name:'Sea Colonist',cost:40,a:0,d:1,mv:1,civ:1,found:1,sea:1,ch:'\u2248',tech:'tidal',desc:'Founds a sea city on an adjacent coastal ocean tile (B). Costs 1 pop.'},
 burrower:{name:'Burrower',cost:35,a:0,d:1,mv:1,civ:1,found:1,ug:1,ch:'U',tech:'boring',desc:'B: found an Underground Base (Warren) on rocky or high ground (costs 1 pop). J: dig a tunnel on this tile.'},
 terraformer:{name:'Terraformer',cost:20,a:0,d:1,mv:1,civ:1,ch:'T',desc:'Builds farms, mines, solar, roads; clears fungus.'},
 scout:{name:'Scout',cost:15,a:1,d:1,mv:2,ch:'S'},
 trooper:{name:'Trooper',cost:25,a:2,d:2,mv:1,ch:'I'},
 warden:{name:'Warden',cost:30,a:1,d:3,mv:1,ch:'W',tech:'lattice'},
 lancer:{name:'Lancer',cost:35,a:4,d:2,mv:1,ch:'L',tech:'kinetic'},
 striker:{name:'Striker',cost:50,a:6,d:3,mv:1,ch:'X',tech:'plasma'},
 skimmer:{name:'Skimmer',cost:55,a:5,d:3,mv:3,ch:'K',tech:'gravitic'},
 skiff:{name:'Scout Skiff',cost:20,a:1,d:1,mv:3,ship:1,ch:'s',tech:'naval',desc:'Fast sea scout. Built in cities with Coastal Docks.'},
 transport:{name:'Troop Transport',cost:35,a:0,d:1,mv:3,ship:1,cap:3,civ:1,ch:'t',tech:'naval',desc:'Carries 3 land units. Move a land unit onto it (or E in port) to board; move off onto a shore tile to land. Sinks with its cargo.'},
 frigate:{name:'Frigate',cost:45,a:3,d:3,mv:3,ship:1,bomb:1,ch:'f',tech:'ordnance',desc:'Warship. O: bombard an adjacent enemy coastal city or warren entrance.'},
 cruiser:{name:'Assault Cruiser',cost:75,a:6,d:5,mv:4,ship:1,bomb:1,ch:'A',tech:'dread',desc:'Heavy warship. O: bombard an adjacent enemy coastal city or warren entrance.'},
 beast:{name:'Spore Beast',cost:0,a:2,d:2,mv:1,ch:'\u03c8',native:1},
 rebel:{name:'Insurgents',cost:0,a:2,d:1,mv:1,ch:'!',native:1}
};
const FAC={
 scrub:{name:'CO2 Scrubbers',cost:40,maint:1,tech:'boring',desc:'Underground bases only: air reserve +2 and it drains at half speed when cut off (fresh air is still needed eventually).'},
 hydro:{name:'Hydroponic Vats',cost:40,maint:1,tech:'soil',desc:'+3 nutrients'},
 fab:{name:'Fabricator',cost:50,maint:1,tech:'deep',desc:'+25% minerals'},
 spire:{name:'Data Spire',cost:50,maint:1,tech:'neural',desc:'+50% labs'},
 shield:{name:'Perimeter Shield',cost:45,maint:1,tech:'field',desc:'City defence x2'},
 dome:{name:'Habitat Dome',cost:60,maint:2,tech:'habitat',desc:'Pop cap 14'},
 docks:{name:'Coastal Docks',cost:35,maint:1,tech:'naval',coast:1,desc:'Coastal or sea cities: build ships here, ships repair fully in port; Sea Colonists may sail and found up to 3 tiles from land.'},
 fishery:{name:'Fisheries',cost:35,maint:1,tech:'naval',coast:1,desc:'+1 nutrients from every worked ocean tile.'},
 tidalc:{name:'Tidal Collectors',cost:40,maint:1,tech:'naval',coast:1,desc:'+1 energy from every worked ocean tile.'},
 rec:{name:'Recreation Commons',cost:35,maint:1,ent:2,desc:'Parks, games and gathering halls: +2 morale.'},
 theatre:{name:'Dreamweave Theatre',cost:60,maint:2,tech:'signal',ent:3,desc:'Immersive shared dreams: +3 morale.'},
 beacon:{name:'Resonance Beacon',cost:300,maint:2,tech:'ascend',project:1,desc:'Stage 1 project (one per faction; Lumen builds projects 35% faster): +25% labs; required for the Ascension Array'},
 array:{name:'Ascension Array',cost:900,maint:0,tech:'ascend',project:1,desc:'Stage 2 project: needs the Beacon, 5+ cities and 35+ total pop. Announced to everyone when started; once built it must charge for 12 turns without its city being captured.'}
};
const TERRA={farm:{name:'Farm',turns:3},mine:{name:'Mine',turns:5},solar:{name:'Solar Collector',turns:4,tech:'photon'},road:{name:'Road',turns:2},tunnel:{name:'Tunnel',turns:2,tech:'boring'},clear:{name:'Clear fungus',turns:3}};
const FACTIONS=[
 {key:'meridian',name:'Iron Meridian',leader:'Marshal Okonkwo-Hale',color:'#e0553a',pers:'militant',bonus:'+12% attack (+25% from turn 100), captured cities pay tribute'},
 {key:'lumen',name:'Lumen Collective',leader:'Provost Ilse Varga',color:'#4aa3ff',pers:'scholarly',bonus:'+45% research, sturdier capital, extra starting trooper'},
 {key:'verdant',name:'Verdant Covenant',leader:'Warden Tamsin Reyes',color:'#5fd35f',pers:'eco',bonus:'Fungus tiles yield 1/1/1 even before Mycelial Accord; Spore Beasts occasionally ignore you'},
 {key:'drift',name:'Free Drift Syndicate',leader:'Broker Anselm Kade',color:'#e6c34a',pers:'expansionist',bonus:'Cities grow 15% faster; +20 starting credits'}
];
const NAMES={
 meridian:{land:['Anvil Ridge','Bastion Hale','Forgecrest','Iron Watch','Rampart Nine','Sentinel Rock','Hammerfall','Citadel Gray','Breakline','Garrison Deep','Bulwark','Ironmoor','Steelhaven','Vanguard Post','Crucible','Shieldwall','Redoubt','Ember Barracks','Talon Point','Ordnance Flats','Keepstone','Cinderhold','Salvo Ridge','Gauntlet','Lancer Field','Drill Yard','Warden Spire','Bracer Hill','Flintmark','Muster Plain','Ironbark','Cobalt Gate','Holdfast','Arsenal Rise','Granite Line','Barricade','Cannon Hollow','Siegeworks','Stalwart','Last Bastion'],
  sea:['Ironkeel','Breakwater Fort','Harbor Bastion','Tidewall','Seagate Nine','Saltforge','Anchor Hold','Riptide Station','Coral Rampart','Deepwatch','Gunwale','Stormmoor']},
 lumen:{land:['Prism Hall','Lyceum One','Lantern Quay','Axiom Fields','Halo Archive','Index','Candela','Theorem Rise','Clearview','Spectra','Margin Notes','Cogito','Lumen Prime','Parallax','Proof Hill','Quillmere','Refraction','Scholar Gate','Tessellate','Vellum','Wavefront','Zenith Lab','Brightglass','Orrery','Corpus','Equinox Study','Aperture','Glimmerden','Reckoning','Postulate','Concord Library','Lucent Bay','Paradigm','Stillpoint','First Lemma','Focal Point','Hypothesis','Whitestone Hall','Observatory Ridge','Last Light'],
  sea:['Tidal Lens','Refractor Isle','Pelagic Study','Brine Archive','Lumen Shoal','Reflection Deep','Saline Prism','Wave Theory','Abyss Lab','Coral Index','Glass Atoll','Undertow Lyceum']},
 verdant:{land:['Mossheart','Rootfall','Fernhollow','Sporewell','Greenmantle','Thicket Rest','Lichenreach','Bloomvale','Mycel Grove','Seedcradle','Willowmere','Bramblewood','Canopy','Dewfall','Groundsong','Hearthroot','Ivycross','Kindred Glade','Leafhome','Marrow Moss','Nettlebrook','Oakshade','Pollen Fields','Quietroot','Rainwreath','Sapling','Tanglewood','Understory','Verdance','Wildbloom','Yarrowmeet','Barkcircle','Cedarkeep','Driftmoss','Elderwild','Fungal Choir','Gladesend','Humus Deep','Kelpwater','Gentle Return'],
  sea:['Kelpcradle','Reefsong','Tidemoss','Saltbloom','Coral Garden','Seagrass Rest','Brine Grove','Driftweed','Anemone','Pearlroot','Wavefern','Lagoon Heart']},
 drift:{land:['Freeport Dust','Coin Hollow','Ledger Rock','Tradewind','Bargain Flats','Caravan Rest','Dividend','Exchange Point','Fairmarket','Gilded Mile','Haggle Cross','Interest Ridge','Jobbers Gap','Kiosk Town','Lucky Strike','Merchant Spur','Netprofit','Outfitter','Payday','Quota','Rally Market','Surplus','Tariff Gate','Underwriter','Venture Camp','Waybill','Yieldmark','Brokers Rest','Crossroads Bazaar','Depot Seven','Escrow','Futures','Goldrush','Hawker Hill','Bounty Flats','Last Chance','Margin Call','New Prospect','Openhand','Profit Rise'],
  sea:['Freeport Tide','Cargo Reef','Dockside','Bounty Bay','Wharf Nine','Salvage Point','Smuggler Cove','Tollwater','Brine Market','Pier Prosperity','Seabond','Harbor Ledger']}
};
const CITY_NAMES=['Firstlight','Hollow Reach','Cinder Gate','Saltmere','Quietwater','Brightfall','Ember Rise','Glassmoor','Dunmarrow','Halcyon','Thornvale','Lowharbor','Skyrest','Ironroot','Mistral','Ashgrove','Coldspring','Northwake','Redfen','Sablecrest','Tidewell','Umberly','Verity','Wanderhold'];

function rand(S){let t=(S.rs=(S.rs+0x6D2B79F5)|0);t=Math.imul(t^(t>>>15),1|t);t=(t+Math.imul(t^(t>>>7),61|t))^t;return((t^(t>>>14))>>>0)/4294967296;}
function ri(S,n){return Math.floor(rand(S)*n);}
const X=(S,i)=>i%S.W, Y=(S,i)=>Math.floor(i/S.W);
function dist(S,a,b){return Math.max(Math.abs(X(S,a)-X(S,b)),Math.abs(Y(S,a)-Y(S,b)));}
function nbrs(S,i,r){r=r||1;const out=[],x=X(S,i),y=Y(S,i);for(let dy=-r;dy<=r;dy++)for(let dx=-r;dx<=r;dx++){if(!dx&&!dy)continue;const a=x+dx,b=y+dy;if(a<0||b<0||a>=S.W||b>=S.H)continue;out.push(b*S.W+a);}return out;}
function logEv(S,type,data){const e=Object.assign({t:S.turn,type},data||{});S.log.push(e);if(S.log.length>20000)S.log.splice(0,5000);return e;}
const fac=(S,id)=>S.factions[id];
const has=(S,fid,t)=>fid>=0&&S.factions[fid].techs.indexOf(t)>=0;

/* ---------- map ---------- */
function smooth(S,a,n){for(let k=0;k<n;k++){const b=a.slice();for(let i=0;i<a.length;i++){let s=a[i],c=1;for(const j of nbrs(S,i)){s+=a[j];c++;}b[i]=s/c;}a=b;}return a;}
function norm(a){let mn=Infinity,mx=-Infinity;for(const v of a){if(v<mn)mn=v;if(v>mx)mx=v;}return a.map(v=>(v-mn)/((mx-mn)||1));}
function field(S,n){const a=[];for(let i=0;i<S.W*S.H;i++)a.push(rand(S));return norm(smooth(S,a,n));}
function genMap(S){
 const N=S.W*S.H;let e=field(S,4);
 e=e.map((v,i)=>{const dx=Math.min(X(S,i),S.W-1-X(S,i))/(S.W/2),dy=Math.min(Y(S,i),S.H-1-Y(S,i))/(S.H/2);const edge=Math.min(dx,dy);return v-(edge<0.25?(0.25-edge)*2:0);});
 if(S.opts&&S.opts.map==='islands'){const cy=S.H*(0.42+0.16*rand(S)),vx=[0,1].map(()=>[0.27,0.5,0.73].map(b=>S.W*(b+(rand(S)-0.5)*0.1))),hy=[0,1].map(k=>S.H*(k?0.75:0.25)+(rand(S)-0.5)*3);
  e=e.map((v,i)=>{const x=X(S,i),y=Y(S,i),row=y>cy?1:0;let d=Math.abs(y-cy);d=Math.abs(y-cy-1.5*Math.sin(x*0.35+hy[0]));vx[row].forEach((vxx,k)=>{d=Math.min(d,Math.abs(x-vxx-1.6*Math.sin(y*0.45+k*2+hy[1])));});return d<1.7?v-0.8:v;});}
 const sorted=e.slice().sort((a,b)=>a-b),thr=sorted[Math.floor(N*(S.opts&&S.opts.map==='islands'?0.55:0.5))],top=sorted[N-1];
 const m=field(S,3),r=field(S,2);
 for(let i=0;i<N;i++){const land=e[i]>thr;S.tiles.push({land,e:land?+((e[i]-thr)/(top-thr||1)).toFixed(2):0,m:m[i]<0.35?0:m[i]<0.68?1:2,r:r[i]<0.4?0:r[i]<0.75?1:2,f:false,imp:'',road:false});}
 const land=[];for(let i=0;i<N;i++)if(S.tiles[i].land)land.push(i);
 const seeds=Math.max(3,Math.floor(land.length/55));
 for(let s=0;s<seeds;s++){let c=land[ri(S,land.length)];for(let k=0;k<10;k++){S.tiles[c].f=true;const nb=nbrs(S,c).filter(j=>S.tiles[j].land);if(!nb.length)break;c=nb[ri(S,nb.length)];}}
}
const TCACHE=(typeof WeakMap!=='undefined')?new WeakMap():null;
function seaHeld(S,tr){const m=new Uint8Array(S.W*S.H);for(const c of S.cities)if(c.sea)for(const i of nbrs(S,c.at,2))if(!S.tiles[i].land&&tr[i]===c.f)m[i]=1;return m;}
function territory(S){let sig=S.cities.length;for(const c of S.cities)sig=(Math.imul(sig,31)+c.id*7+c.f*131+c.at*3+(c.pop>=5?99991:0))|0;const e=TCACHE&&TCACHE.get(S);if(e&&e.sig===sig)return e.t;
 const N=S.W*S.H,t=new Int8Array(N).fill(-1),d=new Int8Array(N).fill(99),age=new Int32Array(N);
 for(const c of S.cities){const R=c.ug?2:c.pop>=5?4:3;for(const i of [c.at].concat(nbrs(S,c.at,R))){const dd=dist(S,i,c.at);if(dd<d[i]||(dd===d[i]&&c.id<age[i])){d[i]=dd;t[i]=c.f;age[i]=c.id;}}}
 if(TCACHE)TCACHE.set(S,{sig,t});return t;}
function suggestName(S,fid,sea){const used=new Set(S.cities.map(c=>c.name).concat(S.usedNames||[]));const N=NAMES[fac(S,fid).key]||{land:CITY_NAMES,sea:CITY_NAMES};const lists=sea?[N.sea,N.land]:[N.land];for(const L of lists)for(const n of L)if(!used.has(n))return n;
 const base=(sea?N.sea:N.land);for(let r=2;r<20;r++)for(const n of base){const m='New '+n+(r>2?' '+r:'');if(!used.has(m))return m;}return'Colony '+(S.cities.length+1);}
function cleanName(n){return String(n||'').replace(/[<>&"]/g,'').trim().slice(0,24);}
function foundSite(S,u){if(!UNITS[u.type].sea)return u.at;if(!S.tiles[u.at].land&&!cityAt(S,u.at))return u.at;/* ug & land founders found in place */let best=-1,bs=-1e9;for(const n of nbrs(S,u.at)){if(S.tiles[n].land||cityAt(S,n))continue;const s=siteScore(S,n,u.f,true);if(s>bs){bs=s;best=n;}}return best;}
function canFound(S,u,at){if(!UNITS[u.type].found)return'Only colonists can found cities';if(at==null)at=foundSite(S,u);if(at<0)return'No coastal ocean tile next to this unit';const t=S.tiles[at];
 if(UNITS[u.type].ug){if(!t.land)return'Must be on land';if(!(t.r===2||t.e>0.6))return'Underground bases need rocky or high ground';}
 else if(UNITS[u.type].sea){if(t.land)return'Sea colonists found on ocean tiles';if(at!==u.at&&dist(S,at,u.at)!==1)return'Must be adjacent';{const mx=seaReach(S,u.f),ld=mapInfo(S).ld[at];if(ld>mx)return mx===1?'Too far from land – Coastal Docks let Sea Colonists found up to 3 tiles out':'Too far from land (max 3 tiles)';}}else if(!t.land)return'Must be on land';
 if(S.cities.some(c=>dist(S,c.at,at)<3))return'Too close to another city (min distance 3)';
 const tr=territory(S)[at];if(tr>=0&&tr!==u.f)return'Inside '+S.factions[tr].name+' territory';return null;}
function cityAt(S,i){for(const c of S.cities)if(c.at===i)return c;return null;}
function unitsAt(S,i){return S.units.filter(u=>u.at===i);}
function placeStarts(S){
 const land=[];for(let i=0;i<S.tiles.length;i++){const t=S.tiles[i];if(t.land&&!t.f&&X(S,i)>1&&Y(S,i)>1&&X(S,i)<S.W-2&&Y(S,i)<S.H-2&&nbrs(S,i).filter(j=>S.tiles[j].land).length>=6)land.push(i);}
 const chosen=[];
 for(const f of S.factions){let best=-1,bs=-1;for(let k=0;k<300;k++){const c=land[ri(S,land.length)];let md=chosen.length?Math.min(...chosen.map(o=>dist(S,o,c))):99;let sc=Math.min(md,20)*10+nbrs(S,c,2).filter(j=>S.tiles[j].land).length;if(S.opts.map==='islands'){const M=mapInfo(S);if(M.size[M.lm[c]]<40)sc-=400;else if(!chosen.some(o=>M.lm[o]===M.lm[c]))sc+=300;}if(sc>bs){bs=sc;best=c;}}
  chosen.push(best);f.start=best;for(const t of ['colonist','colonist','terraformer','scout','trooper'].concat(f.pers==='scholarly'?['trooper']:[]))makeUnit(S,f.id,t,best);}
}
function makeUnit(S,fid,type,at){const u={id:S.nextId++,f:fid,type,at,hp:10,mp:UNITS[type].mv*3,work:null,fort:false,goto:-1,tgt:-1,skip:false};S.units.push(u);return u;}

/* ---------- yields ---------- */
function yields(S,i,fid,ug){
 const t=S.tiles[i];let n,mi,en;
 if(ug)return t.land?[0,1+t.r+(t.r===2?1:0),t.tun!=null&&t.tun>=0?1:0]:[0,0,0];
 if(!t.land){n=1+(has(S,fid,'tidal')?1:0);mi=0;en=1;}
 else if(t.f){if(has(S,fid,'myco')){n=1;mi=1;en=2;}else if(fid>=0&&fac(S,fid).pers==='eco'){n=1;mi=1;en=1;}else{n=0;mi=0;en=0;}}
 else{n=t.m-(t.r===2?1:0);mi=t.r>=1?1:0;en=t.e>0.6?1:0;
  if(t.imp==='farm')n+=1;if(t.imp==='mine')mi+=(t.r>=1?2:1);if(t.imp==='solar')en+=2;if(n<0)n=0;}
 return [n,mi,en];
}
function popCapUG(c){return c.fac.indexOf('dome')>=0?10:6;}
function cityTiles(S,c){return [c.at].concat(nbrs(S,c.at,2));}
function assignWork(S,c){
 const taken=new Set();for(const o of S.cities)if(o!==c&&!!o.ug===!!c.ug)for(const w of o.worked)taken.add(w);
 const cand=nbrs(S,c.at,2).filter(i=>!taken.has(i)&&!cityAt(S,i)&&!S.units.some(u=>u.at===i&&u.f!==c.f));
 const sc=cand.map(i=>{const y=yields(S,i,c.f,c.ug);return{i,y}});
 c.worked=[];let food=yields(S,c.at,c.f)[0]+1;
 for(let p=0;p<c.pop&&sc.length;p++){const need=food-2*c.pop<2;sc.sort((a,b)=>val(b.y)-val(a.y)||a.i-b.i);function val(y){return y[0]*(need?3:1.6)+y[1]*2+y[2]*1.4;}const pick=sc.shift();c.worked.push(pick.i);food+=pick.y[0];}
}
function cityYield(S,c){
 let y=yields(S,c.at,c.f);y=[Math.max(2,y[0])+1,Math.max(1,y[1]),Math.max(1,y[2])+2];
 const fi=c.fac.indexOf('fishery')>=0,ti=c.fac.indexOf('tidalc')>=0;
 for(const w of c.worked){const v=yields(S,w,c.f,c.ug);y[0]+=v[0];y[1]+=v[1];y[2]+=v[2];if(!c.ug&&!S.tiles[w].land){if(fi)y[0]++;if(ti)y[2]++;}}
 if(c.fac.indexOf('hydro')>=0)y[0]+=3;
 if(has(S,c.f,'synth'))y[1]+=2;
 if(c.fac.indexOf('fab')>=0)y[1]=Math.floor(y[1]*1.25);
 return y;
}
function foodBox(S,c){return Math.round((c.pop+1)*7*(fac(S,c.f).pers==='expansionist'?0.85:1)*(c.f>=0?policyMods(S,c.f).growth:1));}
function popCap(c){if(c.ug)return popCapUG(c);return c.fac.indexOf('dome')>=0?14:8;}
function techCost(S,fid){const nc=S.cities.filter(c=>c.f===fid).length;return Math.round((20+fac(S,fid).techs.length*17)*(1+0.04*Math.max(0,nc-4))*(rule(S,'slowResearch')?1.5:1)*policyMods(S,fid).tech);}
function availTechs(S,fid){const f=fac(S,fid);return Object.keys(TECHS).filter(k=>f.techs.indexOf(k)<0&&TECHS[k].pre.every(p=>f.techs.indexOf(p)>=0));}
function canBuild(S,fid,item){if(UNITS[item]){const u=UNITS[item];return !u.native&&(!u.tech||has(S,fid,u.tech));}const F=FAC[item];if(!F||(F.tech&&!has(S,fid,F.tech)))return false;if(F.project&&!rule(S,'ascension'))return false;
 if(F.project){if(S.cities.some(c=>c.f===fid&&c.fac.indexOf(item)>=0))return false;if(item==='array'){if(!S.cities.some(c=>c.f===fid&&c.fac.indexOf('beacon')>=0))return false;const cs=S.cities.filter(c=>c.f===fid);const big=S.W*S.H>1800;if(cs.length<(big?6:5)||cs.reduce((a,c)=>a+c.pop,0)<(big?42:35))return false;}}return true;}
function buildable(S,c){return Object.keys(UNITS).filter(k=>canBuild(S,c.f,k)&&!(UNITS[k].ship&&c.fac.indexOf('docks')<0)).concat(Object.keys(FAC).filter(k=>canBuild(S,c.f,k)&&c.fac.indexOf(k)<0&&!c.queue.includes(k)&&!(FAC[k].project&&c.ug)&&!(k==='scrub'&&!c.ug)&&!(FAC[k].coast&&!coastal(S,c))&&!(FAC[k].project&&S.cities.some(o=>o.f===c.f&&o.queue.includes(k)))));}
let _mapScale=1,_S=null;function itemCost(item,c){const d=UNITS[item]||FAC[item];let v=d.project?Math.round(d.cost*_mapScale):d.cost;if(c&&_S&&c.f>=0&&UNITS[item]){const m=policyMods(_S,c.f);if(UNITS[item].found)v=Math.round(v*m.col);else if(!UNITS[item].civ)v=Math.round(v*m.unit);}return v;}
function itemName(item){return(UNITS[item]||FAC[item]).name;}

/* ---------- cities ---------- */
function foundCity(S,u,name){
 const at=foundSite(S,u);const err=canFound(S,u,at);if(err)return err;const t=S.tiles[at];
 name=cleanName(name)||suggestName(S,u.f,!t.land);if(S.cities.some(c=>c.name===name))name=name+' '+(S.cities.length+1);
 (S.usedNames=S.usedNames||[]).push(name);
 const c={id:S.nextId++,f:u.f,name,at,pop:1,food:0,prod:0,queue:[],fac:[],worked:[],founded:S.turn,sea:!t.land,ug:!!UNITS[u.type].ug,capital:!S.cities.some(o=>o.f===u.f)&&!st(S,u.f).founded};
 if(c.ug){t.tun=u.f;st(S,u.f).warrens=(st(S,u.f).warrens||0)+1;}else{t.f=false;t.road=true;}S.cities.push(c);removeUnit(S,u);assignWork(S,c);st(S,u.f).founded++;
 logEv(S,'cityFounded',{f:u.f,city:name,at:c.at,sea:!t.land,ug:c.ug});return null;
}
function foundAt(S,u,at){const e=canFound(S,u,at);if(e)return e;const t=S.tiles[at];const name=suggestName(S,u.f,true);(S.usedNames=S.usedNames||[]).push(name);const c={id:S.nextId++,f:u.f,name,at,pop:1,food:0,prod:0,queue:[],fac:[],worked:[],founded:S.turn,sea:!t.land};t.f=false;t.road=true;S.cities.push(c);removeUnit(S,u);assignWork(S,c);st(S,u.f).founded++;logEv(S,'cityFounded',{f:u.f,city:name,at,sea:!t.land});return null;}
function st(S,fid){const f=fac(S,fid);return f.stats||(f.stats={built:0,lost:0,kills:0,founded:0});}
function removeUnit(S,u){const k=S.units.indexOf(u);if(k>=0)S.units.splice(k,1);}

/* ---------- movement & combat ---------- */
function moveCost(S,u,to){const t=S.tiles[to];if(t.road&&S.tiles[u.at].road)return 1;if(t.f&&!(u.f<0||has(S,u.f,'myco')||fac(S,u.f).pers==='eco'||policyMods(S,u.f).fmove))return 6;return 3;}
function enemyAt(S,i,fid){if(S.units.some(u=>u.at===i&&u.f!==fid&&atWar(S,fid,u.f)))return true;const c=cityAt(S,i);return!!(c&&c.f!==fid&&atWar(S,fid,c.f));}
function treatyAt(S,i,fid){for(const u of S.units)if(u.at===i&&u.f!==fid&&!atWar(S,fid,u.f))return u.f;const c=cityAt(S,i);return c&&c.f!==fid&&!atWar(S,fid,c.f)?c.f:null;}
function defStrength(S,u,att){const t=S.tiles[u.at],c=cityAt(S,u.at);let d=UNITS[u.type].d;if(UNITS[u.type].ship){if(c)d*=0.6;else d*=nbrs(S,u.at).some(n=>S.tiles[n].land)?1.25:0.9;}if(c){d*=1.25;if(c.ug&&!(att&&has(S,att.f,'sapper')))d*=1.5;if(S.turn-c.founded<15)d*=1.5;if(S.turn<100&&c.f===u.f&&S.cities.filter(o=>o.f===c.f).length===1)d*=1.75;if(c.capital&&c.f===u.f)d*=(fac(S,u.f).pers==='scholarly'?1.8:1.5);if(c.fac.indexOf('shield')>=0&&att.f>=0)d*=2;}if(t.r===2)d*=1.25;if(u.fort)d*=1.25;if(t.f&&u.f<0)d*=1.25;return d*(0.5+u.hp/20);}
function attStrength(S,u){let a=UNITS[u.type].a;if(u.on!=null)a*=0.7;if(u.f>=0)a*=policyMods(S,u.f).att;if(u.f>=0&&fac(S,u.f).pers==='militant')a*=(S.turn>=100?1.25:1.12);return a*(0.5+u.hp/20);}
function bestDefender(S,i,att){let best=null,bv=-1;for(const u of S.units)if(u.at===i&&u.f!==att.f&&atWar(S,att.f,u.f)&&!(u.on!=null&&!S.tiles[i].land&&!cityAt(S,i))){const v=defStrength(S,u,att);if(v>bv){bv=v;best=u;}}return best;}
function combat(S,att,def){
 const A=attStrength(S,att),D=defStrength(S,def,att);const p=A/(A+D);
 while(att.hp>0&&def.hp>0){if(rand(S)<p)def.hp-=1+ri(S,3);else att.hp-=1+ri(S,3);}
 const win=att.hp>0;const loser=win?def:att;
 logEv(S,'combat',{f:att.f,att:UNITS[att.type].name,attF:att.f,def:UNITS[def.type].name,defF:def.f,at:def.at,odds:+p.toFixed(2),winner:win?'attacker':'defender'});
 if(loser.f>=0){st(S,loser.f).lost++;if(loser===att&&def.f>=0)st(S,loser.f).lostAtt=(st(S,loser.f).lostAtt||0)+1;}const wn=win?att:def;if(wn.f>=0)st(S,wn.f).kills++;
 if(isShip(loser))sinkShip(S,loser,wn.f);removeUnit(S,loser);if(win)att.hp=Math.max(1,att.hp);else def.hp=Math.max(1,def.hp);return win;
}
function step(S,u,to){ // returns string error or null
 if(u.mp<=0)return'No moves left';if(dist(S,u.at,to)!==1)return'Not adjacent';const t=S.tiles[to],UT=UNITS[u.type],tc0=cityAt(S,to),from0=u.at;
 if(UT.ship){if(t.land&&!tc0)return'Ships cannot go ashore';if(tc0&&tc0.f!==u.f){if(tc0.f<0||atWar(S,u.f,tc0.f))return'Ships cannot storm a city – bombard it (O)';if(!portFor(S,to,u.f))return'Not your port';}}
 else if(!t.land&&!tc0){const tr=u.f>=0?transportAt(S,to,u.f):null;
  if(u.on!=null&&!(u.type==='seacolony'&&hasDocks(S,u.f)))return'Already aboard – move onto a shore tile to land';
  if(tr&&u.on==null){board(S,u,tr);return null;}
  if(S.units.some(x=>x.at===to&&x.f!==u.f&&(u.f<0||atWar(S,u.f,x.f))))return'Land units cannot attack ships at sea';
  if(!(u.type==='seacolony'&&hasDocks(S,u.f)))return'Cannot enter sea (needs a Troop Transport'+(u.type==='seacolony'?' or Coastal Docks':'')+')';}
 if(u.f<0){const wc=cityAt(S,to);if(wc&&wc.ug)return'Beasts cannot reach underground bases';}
 {const tf=treatyAt(S,to,u.f);if(tf!=null)return REL_NAMES[relOf(S,u.f,tf)]+' with '+fac(S,tf).name+': declare war first (D)';}
 if(u.f>=0&&(t.land||tc0)){const ow=territory(S)[to];if(ow!=null&&ow>=0&&!passOK(S,u.f,ow)&&territory(S)[u.at]!==ow)return'Closed borders: '+fac(S,ow).name+' territory (needs open borders)';}
 u.fort=false;u.work=null;
 if(enemyAt(S,to,u.f)){
  if(UNITS[u.type].a<=0)return'Non-combat unit cannot attack';
  {const tc=cityAt(S,to);if(tc&&tc.ug&&tc.f!==u.f&&!(S.tiles[u.at].tun!=null&&S.tiles[u.at].tun>=0)&&UNITS[u.type].a<4&&!has(S,u.f,'sapper'))return'Underground base: attack from a tunnel tile or with an attack-4+ unit';}
  const d=bestDefender(S,to,u);
  if(d){const win=combat(S,u,d);u.mp=0;if(!win)return null;if(bestDefender(S,to,u))return null;}
  const c=cityAt(S,to);
  if(c&&c.f!==u.f){
   if(u.f<0){if(c.pop>1)c.pop--;c.food=0;c.prod=Math.floor(c.prod/2);logEv(S,'cityRavaged',{city:c.name,f:c.f,at:c.at});u.mp=0;return null;}
   const old=c.f;c.pop--;if(c.pop<1){destroyCity(S,c);}else{c.f=u.f;c.queue=[];c.prod=0;if(fac(S,u.f).pers==='militant'){fac(S,u.f).credits+=10*(c.pop+1);}if(c.capital){c.capital=false;}moodEvent(S,c,-3,15,'occupation');c.mood='content';logEv(S,'cityCaptured',{f:u.f,city:c.name,from:old,at:c.at});fixCapital(S,old);}
  }
  if(!d||!bestDefender(S,to,u)){u.at=to;u.mp=0;afterMove(S,u,from0,to);}
  return null;
 }
 const from=S.tiles[u.at];let cost=moveCost(S,u,to);if(from.tun===u.f&&t.tun===u.f&&!from.fl&&!t.fl&&(u.tn||0)<8){cost=0;u.tn=(u.tn||0)+1;}
 u.mp=Math.max(0,u.mp-cost);u.at=to;afterMove(S,u,from0,to);
 if(u.f>=0&&t.tun!=null&&t.tun>=0&&t.tun!==u.f&&atWar(S,u.f,t.tun)&&!cityAt(S,to)){const old=t.tun;t.tun=u.f;st(S,u.f).breaches=(st(S,u.f).breaches||0)+1;logEv(S,'tunnelBreached',{f:u.f,from:old,at:to});}
 return null;
}
function destroyCity(S,c){S.cities.splice(S.cities.indexOf(c),1);logEv(S,'cityDestroyed',{city:c.name,f:c.f});fixCapital(S,c.f);}
function fixCapital(S,fid){if(fid<0)return;const cs=S.cities.filter(c=>c.f===fid);if(!cs.length||cs.some(c=>c.capital))return;const n=cs.slice().sort((a,b)=>(b.ug?1:0)-(a.ug?1:0)||b.pop-a.pop||a.id-b.id)[0];n.capital=true;st(S,fid).capMoved=(st(S,fid).capMoved||0)+1;if(n.ug)st(S,fid).ugCapital=(st(S,fid).ugCapital||0)+1;logEv(S,'capitalMoved',{f:fid,city:n.name,ug:!!n.ug,at:n.at});}
function occMask(S,fid){const m=new Uint8Array(S.W*S.H);for(const u of S.units)if(u.f!==fid)m[u.at]|=1;for(const c of S.cities){if(c.f!==fid)m[c.at]|=1;m[c.at]|=2;if(fid>=0&&(c.f===fid||(c.f>=0&&S.dip&&relOf(S,fid,c.f)==='alliance'))&&coastal(S,c))m[c.at]|=8;}
 if(fid>=0&&S.dip){const tr=territory(S),cl=S.factions.map(o=>o.id!==fid&&!passOK(S,fid,o.id));if(cl.some(x=>x))for(let i=0;i<tr.length;i++)if(tr[i]>=0&&cl[tr[i]])m[i]|=4;}return m;}
const _bc=new WeakMap();
function bfs(S,start,fid,maxD,ignoreEnemy,mode){mode=mode||0; // memoised within a turn while nothing that blocks paths has changed (log length = version)
 let m=_bc.get(S);const ver=S.turn*1e7+S.log.length*8+(fid+1);if(!m||m.v!==ver){m={v:ver,c:new Map()};_bc.set(S,m);}const k=(start*256+maxD*2+(ignoreEnemy?1:0))*3+mode;let r=m.c.get(k);if(!r){r=bfs0(S,start,fid,maxD,ignoreEnemy,mode);m.c.set(k,r);}return r;}
function bfs0(S,start,fid,maxD,ignoreEnemy,mode){
 const W=S.W,H=S.H,N=W*H,dist=new Int16Array(N).fill(-1),prev=new Int32Array(N).fill(-1),occ=occMask(S,fid),q=new Int32Array(N);let qh=0,qt=0;q[qt++]=start;dist[start]=0;
 while(qh<qt){const c=q[qh++];if(dist[c]>=maxD)continue;if(c!==start&&!ignoreEnemy&&(occ[c]&1))continue;const cx=c%W,cy=(c-cx)/W;
  for(let dy=-1;dy<=1;dy++){const y=cy+dy;if(y<0||y>=H)continue;for(let dx=-1;dx<=1;dx++){if(!dx&&!dy)continue;const x=cx+dx;if(x<0||x>=W)continue;const n=y*W+x;
   if(dist[n]>=0)continue;const L=S.tiles[n].land;if(mode===1?!((!L&&!(occ[n]&2))||(occ[n]&8)):mode===2?false:!(L||(occ[n]&2)))continue;if(!ignoreEnemy&&(occ[n]&4)&&(mode===0||L))continue;dist[n]=dist[c]+1;prev[n]=c;q[qt++]=n;}}}
 return{dist,prev,occ};
}
function firstStep(B,start,to){let c=to;if(B.dist[to]<0)return -1;while(B.prev[c]!==start&&B.prev[c]>=0)c=B.prev[c];return c;}
function moveToward(S,u,to,maxD,B0){if(u.at===to||u.mp<=0)return true;const B=B0||bfs(S,u.at,u.f,maxD||40,false,isShip(u)?1:(u.type==='seacolony'&&hasDocks(S,u.f))?2:0);if(B.dist[to]<0)return false;const path=[];let c=to;while(c!==u.at&&c>=0){path.push(c);c=B.prev[c];}path.reverse();
 for(const s of path){if(u.mp<=0)break;if(enemyAt(S,s,u.f)&&s!==to)return false;const e=step(S,u,s);if(e)return false;if(S.units.indexOf(u)<0)return false;if(u.at!==s)return true;}return true;}

const _rev=new WeakMap();
function marchTo(S,u,to){ // long march using one shared reverse BFS per faction/turn/target (fast for big armies)
 if(u.at===to||u.mp<=0)return;if(isShip(u)||u.on!=null){moveToward(S,u,to,60);return;}let m=_rev.get(S);if(!m||m.t!==S.turn){m={t:S.turn,c:new Map()};_rev.set(S,m);}const k=u.f+':'+to;let B=m.c.get(k);if(!B){B=bfs(S,to,u.f,60);m.c.set(k,B);}
 if(B.dist[u.at]<0){moveToward(S,u,to,60);return;}let c=B.prev[u.at];
 while(c>=0&&u.mp>0){if(enemyAt(S,c,u.f)&&c!==to)return;const at=u.at;const e=step(S,u,c);if(e||S.units.indexOf(u)<0||u.at===at)return;if(c===to)return;c=B.prev[c];}}
/* ---------- visibility ---------- */
function updateSeen(S,fid){const f=fac(S,fid);for(const u of S.units)if(u.f===fid){f.seen[u.at]=1;for(const n of nbrs(S,u.at,UNITS[u.type].mv>1?3:2))f.seen[n]=1;}for(const c of S.cities)if(c.f===fid)for(const n of nbrs(S,c.at,3))f.seen[n]=1;}

/* ---------- player actions (logged; replayable) ---------- */
function act(S,a){_S=S;
 const r=doAct(S,a);if(r.ok){S.actions.push(a);if(a.type!=='endTurn'){const d=Object.assign({},a);delete d.type;d.f=a.f;d.result=r.msg||'ok';logEv(S,'player:'+a.type,d);}}
 else logEv(S,'player:rejected',{f:a.f,action:a,reason:r.msg});
 return r;
}
function doAct(S,a){
 if(S.winner!=null&&['endTurn','control','handBack','rename','setLabs'].indexOf(a.type)<0)return{ok:false,msg:'Game over'};
 const fid=a.f==null?0:a.f;const f=fac(S,fid);
 const u=a.u!=null?S.units.find(x=>x.id===a.u):null;const c=a.c!=null?S.cities.find(x=>x.id===a.c):null;
 if(a.u!=null&&(!u||u.f!==fid))return{ok:false,msg:'No such unit'};
 if(a.c!=null&&(!c||c.f!==fid))return{ok:false,msg:'No such city'};
 switch(a.type){
 case'move':{const e=step(S,u,a.to);u.goto=-1;updateSeen(S,fid);return e?{ok:false,msg:e}:{ok:true};}
 case'goto':{if(!S.tiles[a.to].land&&!cityAt(S,a.to)&&!isShip(u)&&!(u.type==='seacolony'&&hasDocks(S,fid)))return{ok:false,msg:'Cannot go to sea'};if(isShip(u)&&S.tiles[a.to].land&&!portFor(S,a.to,fid))return{ok:false,msg:'Ships can only go to sea or into your ports'};u.goto=a.to;u.work=null;u.fort=false;moveToward(S,u,a.to);if(S.units.indexOf(u)>=0&&u.at===a.to)u.goto=-1;updateSeen(S,fid);return{ok:true};}
 case'found':{const e=foundCity(S,u,a.name);updateSeen(S,fid);return e?{ok:false,msg:e}:{ok:true};}
 case'terra':{const T=TERRA[a.kind],t=S.tiles[u.at];if(a.kind==='tunnel'){if(u.type!=='burrower')return{ok:false,msg:'Only Burrowers dig tunnels'};if(!has(S,fid,'boring'))return{ok:false,msg:'Requires Lithic Boring'};if(!t.land)return{ok:false,msg:'Cannot tunnel under the sea'};if(t.tun===fid&&!t.fl)return{ok:false,msg:'Tunnel already here'};if(cityAt(S,u.at)&&!cityAt(S,u.at).ug)return{ok:false,msg:'Cannot tunnel under a surface city'};u.work={kind:'tunnel',left:t.fl?2:(t.r===2||t.col)?3:2};u.mp=0;return{ok:true,msg:(t.fl?'Pumping out tunnel':'Tunnel started')+' ('+u.work.left+' turns)'};}
  if(u.type!=='terraformer')return{ok:false,msg:u.type==='burrower'?'Burrowers only dig tunnels (J) and found Warrens (B)':'Only terraformers'};if(!T)return{ok:false,msg:'Unknown'};if(T.tech&&!has(S,fid,T.tech))return{ok:false,msg:'Requires '+TECHS[T.tech].name};
  if(a.kind==='clear'&&!t.f)return{ok:false,msg:'No fungus here'};if(a.kind!=='clear'&&a.kind!=='road'&&t.f)return{ok:false,msg:'Clear fungus first (X)'};if(a.kind==='road'&&t.road)return{ok:false,msg:'Road already here'};if(t.imp===a.kind)return{ok:false,msg:'Already built'};if(cityAt(S,u.at)&&a.kind!=='road')return{ok:false,msg:'Not on a city tile'};
  const tl=Math.max(1,Math.round(T.turns*policyMods(S,fid).terra));u.work={kind:a.kind,left:tl};u.mp=0;return{ok:true,msg:T.name+' started ('+tl+' turns)'};}
 case'rename':{const n=cleanName(a.name);if(!n)return{ok:false,msg:'Empty name'};const old=c.name;c.name=n;return{ok:true,msg:old+' renamed to '+n};}
 case'control':{const tf=S.factions[a.target];if(!tf||!tf.alive)return{ok:false,msg:'No such faction'};S.factions.forEach(x=>x.ai=x.id!==a.target);S.human=a.target;return{ok:true,msg:'Now controlling '+tf.name};}
 case'handBack':S.factions.forEach(x=>x.ai=true);S.human=-1;return{ok:true,msg:'All factions AI-controlled'};
 case'setPolicy':{const e=setPolicy(S,fid,a.axis,a.value,'player');if(e)return{ok:false,msg:e};const A=POLICIES[a.axis];return{ok:true,msg:A.label+': '+A.opts[a.value].name+(f.unrest>0&&S.turn>=20?' – brief unrest ('+f.unrest+' turns)':'')};}
 case'propose':{if(!S.factions[a.to])return{ok:false,msg:'No such faction'};const r=propose(S,fid,a.to,{kind:a.kind,res:a.res,amt:a.amt,price:a.price,buy:a.buy});return r.ok?{ok:true,msg:r.msg}:r;}
 case'answer':return answerOffer(S,fid,a.id,!!a.accept);
 case'declareWar':{const r=declareWar(S,fid,a.to,'player');return r?{ok:false,msg:r}:{ok:true,msg:'War declared on '+fac(S,a.to).name}; }
 case'skip':u.skip=true;return{ok:true};
 case'bombard':{const r=bombard(S,u,a.at);return r?{ok:false,msg:r}:{ok:true,msg:'Bombardment: '+(S.log[S.log.length-1].hits)+' of 3 volleys hit'};}
 case'board':{if(isShip(u))return{ok:false,msg:'Ships do not board'};if(u.on!=null)return{ok:false,msg:'Already aboard'};const tr=transportAt(S,u.at,fid);if(!tr)return{ok:false,msg:'No Troop Transport with room here'};board(S,u,tr);return{ok:true,msg:UNITS[u.type].name+' boarded the Troop Transport'};}
 case'unboard':{if(u.on==null)return{ok:false,msg:'Not aboard'};if(!S.tiles[u.at].land&&!cityAt(S,u.at))return{ok:false,msg:'At sea – move onto a shore tile to land'};u.on=null;return{ok:true,msg:'Left the transport'};}
 case'collapse':{const r=collapseTunnel(S,fid,a.at);return r?{ok:false,msg:r}:{ok:true,msg:'Tunnel collapsed'};}
 case'flood':{if(!u)return{ok:false,msg:'Select a unit'};const r=floodTunnel(S,u,a.at);return r?{ok:false,msg:r}:{ok:true,msg:'Tunnel flooded'};}
 case'fortify':u.fort=true;u.skip=true;u.goto=-1;return{ok:true};
 case'disband':if(isShip(u)){const sea=!S.tiles[u.at].land&&!cityAt(S,u.at);for(const x of cargoOf(S,u)){if(sea)removeUnit(S,x);else x.on=null;}}removeUnit(S,u);return{ok:true};
 case'setResearch':if(rule(S,'blindResearch'))return{ok:false,msg:'Blind research is on – your scientists choose'};if(availTechs(S,fid).indexOf(a.tech)<0)return{ok:false,msg:'Not available'};f.research=a.tech;return{ok:true};
 case'setLabs':f.labs=Math.max(0,Math.min(1,+a.v));return{ok:true};
 case'queue':if(buildable(S,c).indexOf(a.item)<0)return{ok:false,msg:'Cannot build'};if(c.queue.length>=6)return{ok:false,msg:'Queue full'};c.queue.push(a.item);return{ok:true};
 case'unqueue':if(a.i<0||a.i>=c.queue.length)return{ok:false,msg:'Bad index'};if(a.i===0)c.prod=Math.min(c.prod,Math.floor(c.prod/2));c.queue.splice(a.i,1);return{ok:true};
 case'buy':{if(!c.queue.length)return{ok:false,msg:'Nothing queued'};const cost=buyCost(c);if(f.credits<cost)return{ok:false,msg:'Need '+cost+' credits'};f.credits-=cost;c.prod=itemCost(c.queue[0],c);return{ok:true,msg:'Bought for '+cost};}
 case'endTurn':endTurn(S);return{ok:true};
 }
 return{ok:false,msg:'Unknown action'};
}
function buyCost(c){const left=itemCost(c.queue[0],c)-c.prod;return Math.max(0,left*2+(c.prod===0?left:0));}

/* ---------- AI ---------- */
const PRIO={militant:['kinetic','deep','lattice','boring','photon','plasma','soil','tidal','naval','ordnance','sapper','field','gravitic','dread','signal','habitat','neural','quantum','myco','synth','ascend'],
 scholarly:['signal','neural','soil','photon','quantum','deep','habitat','boring','tidal','naval','myco','synth','ascend','lattice','field','kinetic','ordnance','plasma','sapper','gravitic','dread'],
 eco:['soil','signal','myco','photon','tidal','naval','deep','habitat','kinetic','ordnance','boring','neural','quantum','synth','ascend','lattice','field','plasma','sapper','gravitic','dread'],
 expansionist:['soil','deep','photon','tidal','naval','habitat','boring','signal','neural','kinetic','ordnance','lattice','myco','quantum','synth','ascend','field','plasma','sapper','gravitic','dread']};
function bestUnit(S,fid,kind){const ks=Object.keys(UNITS).filter(k=>canBuild(S,fid,k)&&!UNITS[k].civ&&!UNITS[k].ship&&k!=='scout');ks.sort((a,b)=>kind==='def'?UNITS[b].d-UNITS[a].d||UNITS[a].cost-UNITS[b].cost:UNITS[b].a-UNITS[a].a||UNITS[b].mv-UNITS[a].mv);return ks[0];}
function aiCity(S,c){
 if(c.queue.length)return;const f=fac(S,c.f),fid=c.f;
 const my=S.units.filter(u=>u.f===fid),cities=S.cities.filter(x=>x.f===fid);
 const garrison=my.filter(u=>u.at===c.at&&!UNITS[u.type].civ&&!UNITS[u.type].ship).length;
 const target={expansionist:8,militant:6,eco:6,scholarly:6}[f.pers];
 const pick=it=>{c.queue.push(it);};const plan=f.plan||'econ';
 if(garrison>=1&&S.turn>=10){const m=c.mor==null?morale(S,c).v:c.mor;if(m<=-3){const e=['rec','theatre'].find(k=>canBuild(S,fid,k)&&c.fac.indexOf(k)<0);if(e){logEv(S,'aiCalm',{f:fid,city:c.name,item:FAC[e].name,v:m});return pick(e);}if(polOf(S,fid,'society')==='martial'&&garrison<2&&m<0)return pick(bestUnit(S,fid,'def'));}}
 if(plan!=='strike'&&canBuild(S,fid,'seacolony')&&c.pop>=3&&!my.some(u=>u.type==='seacolony')&&nbrs(S,c.at).some(n=>!S.tiles[n].land)&&rand(S)<0.2)return pick('seacolony');
 if(garrison>=1&&plan!=='expand'){const nav=aiNaval(S,c,my,cities,plan);if(nav)return pick(nav);}
 {const wars=cities.filter(x=>x.ug).length,bur=my.filter(u=>u.type==='burrower').length;const tun=S.tiles.reduce((n,t)=>n+(t.tun===fid?1:0),0);if(canBuild(S,fid,'burrower')&&!c.ug&&garrison>=1){
  if(cities.length<=2&&!wars&&!bur&&c.pop>=2&&S.turn>60&&rand(S)<0.6)return pick('burrower');
  if(c.pop>=3&&bur<1&&cities.length>=2&&(wars<2||(wars<3&&f.pers==='militant'))&&rand(S)<0.45)return pick('burrower');
  if(wars>=1&&bur<1&&tun<wars*6&&c.pop>=3&&rand(S)<0.35)return pick('burrower');
  if(f.pers==='militant'&&(plan==='strike'||plan==='military')&&f.warTarget!=null&&bur<2&&c.pop>=3&&rand(S)<0.4)return pick('burrower');}}
 if(plan==='expand'&&c.pop>=2&&cities.length<target+3&&my.filter(u=>UNITS[u.type].found).length<Math.max(1,Math.ceil(cities.length/2)))return pick('colonist');
 if(plan==='military'||plan==='strike'){if(garrison<1)return pick(bestUnit(S,fid,'def'));return pick(bestUnit(S,fid,'att'));}
 if(garrison<1)return pick(bestUnit(S,fid,'def'));
 if(cities.length<target&&c.pop>=2&&my.filter(u=>u.type==='colonist').length<Math.ceil(cities.length/2))return pick('colonist');
 if(my.filter(u=>u.type==='terraformer').length<cities.length)return pick('terraformer');
 if(canBuild(S,fid,'seacolony')&&c.pop>=3&&cities.length<target+2&&!my.some(u=>u.type==='seacolony')&&nbrs(S,c.at).some(n=>!S.tiles[n].land)&&rand(S)<0.35)return pick('seacolony');
 if(garrison>=1&&S.turn>=10){const m=c.mor==null?morale(S,c).v:c.mor;if(m<0||(m<1&&c.pop>=6)){const e=['rec','theatre'].find(k=>canBuild(S,fid,k)&&c.fac.indexOf(k)<0);if(e){logEv(S,'aiCalm',{f:fid,city:c.name,item:FAC[e].name,v:m});return pick(e);}if(polOf(S,fid,'society')==='martial'&&garrison<2&&m<0)return pick(bestUnit(S,fid,'def'));}}
 const facs=(c.ug?['scrub','hydro','spire','fab','dome','shield']:['spire','hydro','fab','dome','shield']).filter(k=>canBuild(S,fid,k)&&c.fac.indexOf(k)<0&&(k!=='scrub'||c.ug)&&(k!=='dome'||c.pop>=6)&&(k!=='hydro'||c.pop>=3));
 if(f.pers==='scholarly'&&facs.length)return pick(facs[0]);
 const mil=my.filter(u=>!UNITS[u.type].civ).length;
 if(f.pers==='militant'&&mil<cities.length*3)return pick(bestUnit(S,fid,'att'));
 if(garrison<2&&(S.turn>25||(f.pers==='scholarly'&&S.turn>12)))return pick(bestUnit(S,fid,'def'));
 if(facs.length)return pick(facs[0]);
 if(mil<cities.length*2)return pick(bestUnit(S,fid,'att'));
 if(cities.length<target+3&&c.pop>=3)return pick('colonist');
 pick(bestUnit(S,fid,rand(S)<0.5?'att':'def'));
}
function aiRush(S,u){const fid=u.f;let E=null,ed=99;for(const c of S.cities)if(c.f===fac(S,fid).warTarget){const d=dist(S,c.at,u.at);if(d<ed){ed=d;E=c;}}if(!E||ed>16)return false;
 let T=-1,td=99;for(let i=0;i<S.tiles.length;i++){if(S.tiles[i].tun!==fid&&!(S.cities.some(c=>c.at===i&&c.f===fid)))continue;const d=dist(S,i,E.at);if(d<td){td=d;T=i;}}if(T<0||td<=1||td>14)return false;
 const B=bfs(S,T,fid,16,true);if(B.dist[E.at]<0)return false;let c=B.prev[E.at];let job=-1;const path=[];while(c>=0&&c!==T){path.push(c);c=B.prev[c];}
 for(let k=path.length-1;k>=0;k--){const i=path[k];if(S.tiles[i].tun!==fid&&S.tiles[i].land&&!cityAt(S,i)&&!(B.occ[i]&1)){job=i;break;}}if(job<0)return false;
 u.tgt=job;if(u.at!==job)moveToward(S,u,job,20);if(S.units.indexOf(u)>=0&&u.at===job&&u.mp>0&&S.tiles[job].tun!==fid){u.work={kind:'tunnel',left:S.tiles[job].r===2?3:2,rush:1};u.mp=0;}return true;}
/* ---------- underground supply (air / food / power) ---------- */
function isTunT(t){return t.tun!=null&&t.tun>=0;}
function hostileNear(S,i,fid){for(const u of S.units)if(u.f>=0&&u.f!==fid&&atWar(S,fid,u.f)&&UNITS[u.type].a>0&&dist(S,u.at,i)<=1)return u;return null;}
function supplyMap(S,fid){ // 1 = tunnel/warren tile connected to a held surface entrance
 const N=S.W*S.H,m=new Uint8Array(N),q=[];const surf=S.cities.filter(c=>c.f===fid&&!c.ug);
 const host=new Uint8Array(N);for(const u of S.units)if(u.f>=0&&u.f!==fid&&UNITS[u.type].a>0){host[u.at]=1;for(const n of nbrs(S,u.at))host[n]=1;}
 for(let i=0;i<N;i++){const t=S.tiles[i];if(t.tun!==fid||t.fl)continue;const c=cityAt(S,i);const ent=(c&&c.f===fid)||surf.some(o=>dist(S,o.at,i)<=1);if(ent&&!host[i]){m[i]=1;q.push(i);}}
 while(q.length){const i=q.pop();for(const n of nbrs(S,i)){const t=S.tiles[n];if(!m[n]&&t.tun===fid&&!t.fl){m[n]=1;q.push(n);}}}
 return m;}
function resCaps(c){return{air:3+(c.fac.indexOf('scrub')>=0?2:0),food:c.fac.indexOf('hydro')>=0?16:8,pow:6};}
function supplyTurn(S){const maps={},noHeal=new Set();
 for(const f of S.factions){if(!f.alive)continue;if(!S.cities.some(c=>c.f===f.id&&c.ug)&&!S.tiles.some(t=>t.tun===f.id))continue;maps[f.id]=supplyMap(S,f.id);}
 for(const c of S.cities.filter(c=>c.ug)){const m=maps[c.f];const cap=resCaps(c);if(!c.res)c.res={air:cap.air,food:cap.food,pow:cap.pow};const R=c.res;
  if(m&&m[c.at]){for(const k of ['air','food','pow'])R[k]=Math.min(cap[k],R[k]+2);if(c.cut){c.cut=0;logEv(S,'supplyRestored',{f:c.f,city:c.name,at:c.at});}if(R.air>1&&R.food>1&&R.pow>1)c.low=0;c.airOut=0;continue;}
  if(!c.cut){c.cut=1;const b=hostileNear(S,c.at,c.f);st(S,c.f).cutOff=(st(S,c.f).cutOff||0)+1;if(b)st(S,b.f).sieges=(st(S,b.f).sieges||0)+1;logEv(S,'supplyCut',{f:c.f,city:c.name,at:c.at,by:b?b.f:null});}
  R.air=Math.max(0,R.air-(c.fac.indexOf('scrub')>=0?(S.turn%2):1));R.food=Math.max(0,R.food-(c.fac.indexOf('hydro')>=0?(S.turn%2):1));R.pow=Math.max(0,R.pow-1);
  if(!c.low&&(R.air<=1||R.food<=1||R.pow<=1)){c.low=1;logEv(S,'reservesLow',{f:c.f,city:c.name,at:c.at,air:R.air,food:R.food,pow:R.pow});}
  if(R.air===0){c.airOut=(c.airOut||0)+1;if(c.pop>1&&c.airOut<2)c.pop--;for(const u of S.units.slice())if(u.at===c.at&&u.f===c.f){u.hp-=2;noHeal.add(u.id);if(u.hp<=0){removeUnit(S,u);st(S,c.f).lost++;}}}
  else if(R.food===0&&S.turn%2===0&&c.pop>1)c.pop--;
  if(c.pop<1||c.airOut>=2){const b=hostileNear(S,c.at,c.f),old=c.f;
   if(b&&c.pop>=1){S.units=S.units.filter(u=>!(u.at===c.at&&u.f===old));c.f=b.f;c.capital=false;c.queue=[];c.prod=0;c.cut=0;c.low=0;c.airOut=0;c.res={air:cap.air,food:cap.food,pow:cap.pow};st(S,b.f).surrenders=(st(S,b.f).surrenders||0)+1;logEv(S,'warrenSurrendered',{f:old,to:b.f,city:c.name,at:c.at});fixCapital(S,old);}
   else{S.units=S.units.filter(u=>!(u.at===c.at&&u.f===old));logEv(S,'warrenSurrendered',{f:old,to:null,city:c.name,at:c.at});destroyCity(S,c);}}}
 // units standing in cut-off tunnels: no healing and slow suffocation (never below 1 HP)
 for(const u of S.units){if(u.f<0)continue;const t=S.tiles[u.at];if(t.tun!==u.f)continue;const c=cityAt(S,u.at);if(c&&!c.ug)continue;const m=maps[u.f];if(m&&!m[u.at]){noHeal.add(u.id);if(!(c&&c.ug))u.hp=Math.max(1,u.hp-1);}}
 return noHeal;}
function collapseTunnel(S,fid,at){const t=S.tiles[at];if(!t||t.tun!==fid)return'Not your tunnel';if(cityAt(S,at))return'Cannot collapse a base or city tile';
 if(S.units.some(u=>u.at===at&&u.f===fid))return'Your own units are in that tunnel';
 if(!S.units.some(u=>u.f===fid&&dist(S,u.at,at)<=2)&&!S.cities.some(c=>c.f===fid&&dist(S,c.at,at)<=3))return'No engineers nearby (need a unit within 2 tiles or a base within 3)';
 t.tun=null;t.fl=0;t.col=1;let hit=0;for(const u of S.units.slice())if(u.at===at){u.hp-=5;hit++;if(u.hp<=0){removeUnit(S,u);if(u.f>=0)st(S,u.f).lost++;st(S,fid).kills++;}}
 st(S,fid).collapses=(st(S,fid).collapses||0)+1;logEv(S,'tunnelCollapsed',{f:fid,at,hit});return null;}
function canFlood(S,fid,at){const t=S.tiles[at];return t&&isTunT(t)&&!t.fl&&!cityAt(S,at)&&(nbrs(S,at).some(n=>!S.tiles[n].land)||has(S,fid,'sapper'));}
function floodTunnel(S,u,at){if(at==null){at=isTunT(S.tiles[u.at])&&canFlood(S,u.f,u.at)?u.at:nbrs(S,u.at).find(n=>canFlood(S,u.f,n)&&S.tiles[n].tun!==u.f);if(at==null)at=nbrs(S,u.at).find(n=>canFlood(S,u.f,n));if(at==null)return'No floodable tunnel here (needs water next to it or Seismic Sapping)';}
 if(u.mp<=0)return'No moves left';if(dist(S,u.at,at)>1)return'Too far';const t=S.tiles[at];if(!isTunT(t))return'No tunnel there';if(t.fl)return'Already flooded';if(cityAt(S,at))return'Cannot flood a base';
 if(!canFlood(S,u.f,at))return'Needs water next to the tunnel, or Seismic Sapping';
 const owner=t.tun;t.fl=1;u.mp=0;for(const x of S.units.slice())if(x.at===at&&x!==u){x.hp-=3;if(x.hp<=0){removeUnit(S,x);if(x.f>=0)st(S,x.f).lost++;}}
 st(S,u.f).floods=(st(S,u.f).floods||0)+1;logEv(S,'tunnelFlooded',{f:u.f,owner,at});return null;}
function aiCollapse(S,fid){ // seal breaches next to our warrens: at most one collapse per turn
 for(const w of S.cities)if(w.f===fid&&w.ug)for(const i of nbrs(S,w.at,2)){const t=S.tiles[i];if(t.tun!==fid||cityAt(S,i)||S.units.some(u=>u.at===i&&u.f===fid))continue;
  if(nbrs(S,i).some(n=>S.units.some(u=>u.at===n&&u.f>=0&&u.f!==fid&&UNITS[u.type].a>0)&&S.tiles[n].tun!=null&&S.tiles[n].tun!==fid&&S.tiles[n].tun>=0)||S.units.some(u=>u.at===i&&u.f>=0&&u.f!==fid)){if(!collapseTunnel(S,fid,i))return;}}}
function siteScore(S,i,fid,sea){const T0=S.tiles[i];if(sea?(T0.land||mapInfo(S).ld[i]>seaReach(S,fid)):(!T0.land||T0.f))return -1;if(S.cities.some(c=>dist(S,c.at,i)<3))return -1;const tr=territory(S)[i];if(tr>=0&&tr!==fid)return -1;let s=0;for(const n of nbrs(S,i,2)){const y=yields(S,n,fid);s+=y[0]*1.5+y[1]+y[2];}if(S.tiles[i].r===2)s-=2;if(nbrs(S,i).some(n=>!S.tiles[n].land))s+=2;return s;}
function aiUnit(S,u){
 const fid=u.f,f=fac(S,fid),T=UNITS[u.type];if(S.units.indexOf(u)<0||u.mp<=0)return;
 if(T.ship){aiShip(S,u);return;}if(u.on!=null)return;
 if(u.type==='colonist'){
  const B=bfs(S,u.at,fid,10);
  if(u.tgt<0||siteScore(S,u.tgt,fid)<0){let best=-1,bs=0;for(let i=0;i<B.dist.length;i++){if(B.dist[i]<0)continue;const s=siteScore(S,i,fid)-B.dist[i]*1.2;if(s>bs){bs=s;best=i;}}u.tgt=best;}
  if(u.tgt<0){if(siteScore(S,u.at,fid)>=0){foundCity(S,u);return;}if((hasDocks(S,fid)||S.units.some(x=>x.f===fid&&x.type==='transport'))&&(u.wantShip||S.units.filter(x=>x.f===fid&&x.wantShip).length<3))waitForShip(S,u);return;}u.wantShip=false;
  if(u.at===u.tgt){foundCity(S,u);return;}moveToward(S,u,u.tgt,12);if(S.units.indexOf(u)>=0&&u.at===u.tgt&&u.mp>0)foundCity(S,u);return;
 }
 if(u.type==='seacolony'&&hasDocks(S,fid)){const B=bfs(S,u.at,fid,14,false,2);
  if(u.tgt<0||seaSiteScore(S,u.tgt,fid)<0||B.dist[u.tgt]<0){let best=-1,bs=0;for(let i=0;i<B.dist.length;i++){if(B.dist[i]<0||S.tiles[i].land)continue;const s=seaSiteScore(S,i,fid)-B.dist[i]*1.0;if(s>bs){bs=s;best=i;}}u.tgt=best;}
  if(u.tgt<0)return;if(u.at!==u.tgt)moveToward(S,u,u.tgt,14,B);if(S.units.indexOf(u)>=0&&u.at===u.tgt&&!S.tiles[u.at].land&&u.mp>0){if(foundCity(S,u))u.tgt=-1;}return;}
 if(u.type==='seacolony'){
  const B=bfs(S,u.at,fid,12);
  if(u.tgt<0||siteScore(S,u.tgt,fid,true)<0){let best=-1,bs=0;for(let i=0;i<B.dist.length;i++){if(S.tiles[i].land)continue;const ld=nbrs(S,i).filter(n=>B.dist[n]>=0).map(n=>B.dist[n]);if(!ld.length)continue;const s=siteScore(S,i,fid,true)-Math.min(...ld)*1.2;if(s>bs){bs=s;best=i;}}u.tgt=best;}
  if(u.tgt<0)return;
  if(dist(S,u.at,u.tgt)>1){const land=nbrs(S,u.tgt).filter(n=>B.dist[n]>=0).sort((a,b)=>B.dist[a]-B.dist[b])[0];if(land==null){u.tgt=-1;return;}moveToward(S,u,land,12);}
  if(S.units.indexOf(u)>=0&&dist(S,u.at,u.tgt)===1&&u.mp>0)foundAt(S,u,u.tgt);
  return;
 }
 if(u.type==='burrower'){
  if(u.work)return;const mine=S.cities.filter(c=>c.f===fid),wars=mine.filter(c=>c.ug);
  const okSite=i=>{const t=S.tiles[i];return t.land&&(t.r===2||t.e>0.6)&&!canFound(S,u,i)&&!S.units.some(o=>o!==u&&o.f===fid&&o.type==='burrower'&&o.tgt===i);};
  if(f.pers==='militant'&&(f.plan==='strike'||f.plan==='military')&&f.warTarget!=null&&wars.length>=1&&aiRush(S,u))return;
  if(wars.length<2){const B=bfs(S,u.at,fid,10);
   if(u.tgt<0||!okSite(u.tgt)||u.tgt>=1e6){let best=-1,bs=-1e9;for(let i=0;i<B.dist.length;i++){if(B.dist[i]<0||!okSite(i))continue;let sc=0;for(const n of nbrs(S,i,2))if(S.tiles[n].land)sc+=1+S.tiles[n].r;sc-=B.dist[i]*1.5;if(sc>bs){bs=sc;best=i;}}u.tgt=best;}
   if(u.tgt>=0){if(u.at!==u.tgt)moveToward(S,u,u.tgt,12);if(S.units.indexOf(u)>=0&&u.at===u.tgt&&u.mp>0)foundCity(S,u);return;}}
  // dig: connect each warren to nearest own surface city
  if(!wars.length)return;let job=-1;
  for(const w of wars){let near=null,nd=99;for(const c of mine)if(!c.ug){const d=dist(S,c.at,w.at);if(d<nd){nd=d;near=c;}}if(!near||nd>14)continue;
   const B=bfs(S,w.at,fid,16,true);if(B.dist[near.at]<0)continue;let c=near.at;const path=[];while(c>=0&&c!==w.at){path.push(c);c=B.prev[c];}
   for(let k=path.length-1;k>=0;k--){const i=path[k];if(S.tiles[i].tun!==fid&&S.tiles[i].land&&!S.units.some(o=>o!==u&&o.f===fid&&o.type==='burrower'&&o.tgt===i)){job=i;break;}}if(job>=0)break;}
  if(job<0){u.fort=true;return;}u.tgt=job;if(u.at!==job)moveToward(S,u,job,20);
  if(S.units.indexOf(u)>=0&&u.at===job&&S.tiles[job].tun!==fid){u.work={kind:'tunnel',left:S.tiles[job].r===2?3:2};u.mp=0;}
  return;
 }
 if(u.type==='terraformer'){
  if(u.work)return;
  const mine=S.cities.filter(c=>c.f===fid);if(!mine.length)return;
  const job=i=>{const t=S.tiles[i];if(!t.land||cityAt(S,i))return null;if(t.f)return'clear';if(t.imp)return(!t.road&&mine.some(c=>dist(S,c.at,i)<=1))?'road':null;if(t.r>=1&&t.m===0)return'mine';if(t.m>=1&&t.r<2)return'farm';if(has(S,fid,'photon'))return'solar';if(t.r>=1)return'mine';return null;};
  if(u.tgt<0||!job(u.tgt)||S.units.some(o=>o!==u&&o.f===fid&&o.tgt===u.tgt)){
   const B=bfs(S,u.at,fid,14);let best=-1,bd=99;
   for(const c of mine)for(const i of cityTiles(S,c)){if(B.dist[i]<0||!job(i))continue;if(S.units.some(o=>o!==u&&o.f===fid&&o.type==='terraformer'&&o.tgt===i))continue;const w=c.worked.indexOf(i)>=0?0:3;if(B.dist[i]+w<bd){bd=B.dist[i]+w;best=i;}}
   u.tgt=best;}
  if(u.tgt<0)return;
  if(u.at!==u.tgt)moveToward(S,u,u.tgt,14);
  if(S.units.indexOf(u)>=0&&u.at===u.tgt){const k=job(u.at);if(k){u.work={kind:k,left:Math.max(1,Math.round(TERRA[k].turns*policyMods(S,fid).terra))};u.mp=0;}}
  return;
 }
 // military
 const c=cityAt(S,u.at);
 if(c&&c.f===fid&&S.units.filter(o=>o.at===u.at&&o.f===fid&&!UNITS[o.type].civ).sort((a,b)=>UNITS[b.type].d-UNITS[a.type].d||a.id-b.id)[0]===u){
  // garrison: strike adjacent weak enemies only
  for(const n of nbrs(S,u.at)){const d=bestDefender(S,n,u);if(d&&cityAt(S,n)&&!atWar(S,fid,cityAt(S,n).f))continue;if(d&&T.a>0&&attStrength(S,u)>defStrength(S,d,u)*1.3){step(S,u,n);return;}}
  u.fort=true;return;
 }
 if(T.a>0&&f.warTarget!=null&&S.turn>=graceTurn(S)){ // siege enemy warrens: cut entrances, flood tunnels
  let W=null,wd=99;for(const o of S.cities)if(o.ug&&o.f===f.warTarget){const d=dist(S,o.at,u.at);if(d<wd){wd=d;W=o;}}
  if(W&&wd<=12){
   const fl=nbrs(S,u.at).find(n=>S.tiles[n].tun===W.f&&canFlood(S,fid,n)&&dist(S,n,W.at)<=3);if(fl!=null&&u.mp>0&&rand(S)<0.5){floodTunnel(S,u,fl);return;}
   if(wd===1){const canHit=has(S,fid,'sapper')||T.a>=4||isTunT(S.tiles[u.at]);const d0=bestDefender(S,W.at,u);if(canHit&&(!d0||attStrength(S,u)>defStrength(S,d0,u)*1.1)){step(S,u,W.at);return;}u.fort=true;return;}
   if(u.id%3===0){let tg=-1,td=99;for(const n of nbrs(S,W.at)){if(!S.tiles[n].land||cityAt(S,n)||S.units.some(x=>x.at===n&&x.f!==fid))continue;const d=dist(S,n,u.at);if(d<td){td=d;tg=n;}}if(tg>=0){moveToward(S,u,tg,16);return;}}}}
 const aggressive=(S.turn>=graceTurn(S)||rule(S,'aggressive'))&&(rule(S,'aggressive')||f.pers==='militant'||S.turn>40)||u.type==='scout'||f.plan==='strike'||f.plan==='military';
 const B=bfs(S,u.at,fid,u.type==='scout'?8:16);let best=-1,bs=-1e9;
 const cmap=new Map();for(const c of S.cities)if(!cmap.has(c.at))cmap.set(c.at,c);const em=new Map();for(const x of S.units)if(x.f!==fid){const a=em.get(x.at);if(a)a.push(x);else em.set(x.at,[x]);}
 const myC=S.cities.filter(o=>o.f===fid),gt=graceTurn(S),agR=rule(S,'aggressive'),aS=attStrength(S,u);
 for(let i=0;i<B.dist.length;i++){if(B.dist[i]<0)continue;if(!(B.occ[i]&1))continue;
  const ec=cmap.get(i)||null;{const ow=ec?ec.f:(em.get(i)||[{f:fid}])[0].f;if(ow===fid||!atWar(S,fid,ow))continue;}
  if(ec&&ec.ug&&UNITS[u.type].a<4&&!has(S,fid,'sapper')&&!nbrs(S,i).some(n=>S.tiles[n].tun!=null&&S.tiles[n].tun>=0))continue;
  if(ec&&S.turn<gt&&!agR)continue;if(ec&&S.turn<Math.round(gt*0.6))continue;
  if(!aggressive&&!myC.some(o=>dist(S,o.at,i)<=4))continue;
  const arr=em.get(i);let d=null,dv=-1;if(arr)for(const x of arr){const v=defStrength(S,x,u);if(v>dv){dv=v;d=x;}}
  let s=(ec?15:5)-B.dist[i]*1.5;if(f.warTarget!=null&&(ec?ec.f:(arr?arr[0]:{}).f)===f.warTarget)s+=12;if(f.warCity===i)s+=30;if(d){s+=(aS-dv)*4;if(u.type==='scout'&&d.f>=0)s-=20;}if(s>bs){bs=s;best=i;}}
 if(best>=0&&bs>-15&&T.a>0){moveToward(S,u,best,16,u.type==='scout'?null:B);return;}
 if((f.plan==='strike'||f.plan==='military')&&f.warTarget!=null&&T.a>0&&(f.pers==='militant'||f.pers==='expansionist')){const M=mapInfo(S),ec=S.cities.filter(c=>c.f===f.warTarget);if(ec.length&&ec.every(c=>M.lm[c.at]!==M.lm[u.at])&&(u.wantShip||S.units.filter(x=>x.f===fid&&x.wantShip&&!UNITS[x.type].civ).length<3)&&(hasDocks(S,fid)||S.units.some(x=>x.f===fid&&x.type==='transport'))){if(waitForShip(S,u))return;}else u.wantShip=false;}
 if(f.plan==='strike'&&f.warTarget!=null&&T.a>0){let tc=f.warCity>=0?f.warCity:-1;if(tc<0){let bd=1e9;for(const c of S.cities)if(c.f===f.warTarget){const d=dist(S,c.at,u.at);if(d<bd){bd=d;tc=c.at;}}}if(tc>=0){marchTo(S,u,tc);return;}}
 if(u.type==='scout'||(!aggressive&&ri(S,3)===0)){ // explore
  if(u.tgt<0||u.at===u.tgt||f.seen[u.tgt]){let c2=-1;for(let k=0;k<30;k++){const i=ri(S,S.tiles.length);if(S.tiles[i].land&&!f.seen[i]){c2=i;break;}}if(c2<0)c2=ri(S,S.tiles.length);u.tgt=S.tiles[c2].land?c2:-1;}
  if(u.tgt>=0)moveToward(S,u,u.tgt,40);return;
 }
 // reinforce weakest own city
 const mine=S.cities.filter(o=>o.f===fid);if(!mine.length)return;
 const gc=new Map();for(const x of S.units)if(x.f===fid&&!UNITS[x.type].civ)gc.set(x.at,(gc.get(x.at)||0)+1);
 let wc=null,wv=1e9;for(const o of mine){const v=(gc.get(o.at)||0)*10+dist(S,o.at,u.at);if(v<wv){wv=v;wc=o;}}
 if(wc&&wc.at!==u.at)moveToward(S,u,wc.at,30);else u.fort=true;
}
/* ---------- strategic planner: depth-3 minimax with alpha-beta over an abstract economy model ---------- */
const PLANS=['expand','econ','military','project','strike'];
function milPower(S,fid){let m=0;for(const u of S.units)if(u.f===fid&&!UNITS[u.type].civ)m+=(UNITS[u.type].a+UNITS[u.type].d)*u.hp/10;return m;}
function victoryProgress(S,fid){const f=fac(S,fid),cs=S.cities.filter(c=>c.f===fid);let p=f.techs.length/Object.keys(TECHS).length*0.35;
 if(cs.some(c=>c.fac.indexOf('beacon')>=0))p+=0.15;const ac=cs.find(c=>c.queue[0]==='array');if(ac)p+=0.3*Math.min(1,ac.prod/FAC.array.cost);
 if(S.ascension&&S.ascension.f===fid)p=0.8+0.2*(1-S.ascension.left/(S.ascension.total||12));p=Math.max(p,S.dip&&rule(S,'economic')?f.credits/econTarget(S)*0.95:0,S.dip?S.dip.dipTurns[fid]/DIPLO.DIP_TURNS*0.6:0,S.dip&&S.dip.coopTurns?S.dip.coopTurns/DIPLO.COOP_TURNS*0.6:0,(f.domTurns||0)/DOMINION_TURNS*0.9,(f.landShare||0)/domShare(S)*0.5);return Math.min(1,p);}
function absState(S,fid){const f=fac(S,fid),cs=S.cities.filter(c=>c.f===fid);let prod=0,en=0,pop=0;for(const c of cs){const y=cityYield(S,c);prod+=y[1];en+=y[2];pop+=c.pop;}
 return{cities:cs.length,pop,prod,labs:en*f.labs+1,mil:milPower(S,fid),tech:f.techs.length,prog:victoryProgress(S,fid),cr:f.credits};}
function absApply(a,b,plan){const s=Object.assign({},a),o=Object.assign({},b),nT=Object.keys(TECHS).length,eff=1/(1+Math.max(0,s.cities-5)*0.06);
 s.tech=Math.min(nT,s.tech+s.labs*10*eff/(20+17*s.tech));
 if(plan==='expand'){s.cities+=s.cities<14?1.4:0.4;s.pop+=3;s.prod*=1.06;}
 else if(plan==='econ'){s.prod*=1.12;s.labs*=1.2;s.pop+=2;}
 else if(plan==='military'){s.mil+=s.prod*10/30*3.2;}
 else if(plan==='project'){if(s.tech>=nT-0.5)s.prog=Math.min(1,s.prog+(s.prod*10+s.cr*0.5)/(FAC.beacon.cost+FAC.array.cost)*0.55*(s.cities>=5?1:0.3));else s.tech=Math.min(nT,s.tech+s.labs*4/(20+17*s.tech));s.cr*=0.5;}
 else if(plan==='strike'){if(s.mil>o.mil*1.15){const k=Math.min(o.cities,1+Math.floor(s.mil/(o.mil+1)/3));o.cities-=k;s.cities+=k*0.6;o.prog*=0.5;o.prod*=0.8;s.mil*=0.7;o.mil*=0.55;}else{s.mil*=0.6;o.mil*=0.85;}}
 s.prog=Math.max(s.prog,Math.min(0.35,s.tech/nT*0.35));return[s,o];}
function absEval(me,op){let v=me.prog*120+me.cities*3+me.tech*2+me.mil*0.35+me.pop*0.3-(op.prog*130+op.cities*2.5+op.tech*1.5+op.mil*0.3);
 if(op.prog>=0.8&&me.prog<op.prog)v-=150;if(me.cities<=0)v-=500;return v;}
function minimax(me,op,depth,maxTurn,alpha,beta,ctr){ctr.n++;if(depth===0)return{v:absEval(me,op)};let best=null;
 for(const p of PLANS){let nm,no;if(maxTurn){[nm,no]=absApply(me,op,p);}else{[no,nm]=absApply(op,me,p);}
  const r=minimax(nm,no,depth-1,!maxTurn,alpha,beta,ctr);
  if(maxTurn){if(!best||r.v>best.v)best={v:r.v,p};alpha=Math.max(alpha,r.v);}else{if(!best||r.v<best.v)best={v:r.v,p};beta=Math.min(beta,r.v);}
  if(beta<=alpha)break;}
 return best;}
function planFaction(S,fid){const f=fac(S,fid);const rivals=S.factions.filter(x=>x.alive&&x.id!==fid);if(!rivals.length)return;
 // most threatening rival = highest victory progress, then score
 let opp=rivals[0],ov=-1;for(const r of rivals){const v=victoryProgress(S,r.id)*100+score(S,r.id)*0.2;if(v>ov){ov=v;opp=r;}}
 const me=absState(S,fid),op=absState(S,opp.id),ctr={n:0};
 const res=minimax(me,op,3,true,-Infinity,Infinity,ctr);let plan=res.p;
 // personality tie-in: early game expansion floor
 if(S.turn<25&&me.cities<4&&plan!=='strike')plan='expand';
 if(plan==='strike'&&S.turn<graceTurn(S)&&!S.ascension)plan='military';
 if(S.ascension&&S.ascension.f!==fid&&me.mil>0)plan='strike';
 if(plan==='strike'&&!atWar(S,fid,opp.id)){if(aiWantsBreak(S,fid,opp.id))declareWar(S,fid,opp.id,'strike planned');else{const ws=rivals.filter(x=>atWar(S,fid,x.id));let o2=null,v2=-1;for(const r of ws){const v=victoryProgress(S,r.id)*100+score(S,r.id)*0.2;if(v>v2){v2=v;o2=r;}}if(o2)opp=o2;else plan='military';}}
 if(plan==='strike'){f.warTarget=opp.id;const ac=S.ascension&&S.ascension.f===opp.id?S.cities.find(c=>c.id===S.ascension.city):S.cities.find(c=>c.f===opp.id&&c.queue[0]==='array')||null;f.warCity=ac?ac.at:-1;}else{f.warTarget=null;f.warCity=-1;}
 if(plan!==f.plan)logEv(S,'aiPlan',{f:fid,plan,prev:f.plan||null,vs:opp.id,value:Math.round(res.v),nodes:ctr.n});
 f.plan=plan;}
function aiPolicyWant(S,fid){const f=fac(S,fid),p=f.pers,w=Object.assign({},AI_POLICY[p]),why={};const cs=S.cities.filter(c=>c.f===fid),nc=cs.length;
 const sc=S.factions.filter(x=>x.alive).map(x=>score(S,x.id)),me=score(S,fid),top=Math.max(...sc),behind=S.turn>=60&&me<top*0.7;
 const tr=territory(S);let land=0,mine=0;for(let i=0;i<tr.length;i++)if(S.tiles[i].land){land++;if(tr[i]===fid)mine++;}const dom=land?mine/land:0;
 const threat=S.units.some(u=>u.f>=0&&u.f!==fid&&atWar(S,fid,u.f)&&!UNITS[u.type].civ&&UNITS[u.type].a>0&&cs.some(c=>dist(S,c.at,u.at)<=3));
 const freeSites=S.turn%5===0||f._fs==null?(f._fs=nc<{expansionist:12,militant:9,eco:9,scholarly:9}[p]?1:0):f._fs;
 // situation overrides
 if(has(S,fid,'ascend')&&rule(S,'ascension')!==false&&cs.some(c=>c.fac.indexOf('beacon')>=0||c.queue.includes('beacon')||c.queue.includes('array'))){w.econ='directed';why.econ='ascension project';if(p!=='militant'){w.focus='inquiry';}}
 if(rule(S,'economic')&&f.credits>=econTarget(S)*0.5&&p!=='militant'){w.econ='open';why.econ='economic victory in reach';}
 if(rule(S,'dominion')&&dom>=domShare(S)*0.75){w.society=p==='militant'?'martial':'frontier';why.society='dominion in reach';}
 if(threat&&p!=='scholarly'){w.focus='vigilance';why.focus='enemy at the gates';}
 if(behind&&!threat){if(freeSites&&p!=='scholarly'){w.society='frontier';why.society='behind: expand';}else if(p!=='militant'){w.focus='prosperity';why.focus='behind: grow';}}
 if(!freeSites&&w.society==='frontier'&&!why.society){w.society=p==='expansionist'?'civic':'merit';why.society='no room left to settle';}
 if(p==='eco'&&S.turn>=80&&!why.society&&!freeSites)w.society='merit';
 {const un=cs.filter(c=>c.mood&&c.mood!=='content').length,ri=cs.filter(c=>c.mood==='rioting').length;if(nc&&(un/nc>=0.34||ri>=2)){if(p==='militant'||(f.ww||0)>=6){w.society='martial';why.society='unrest: harden (martial law)';}else{w.society='civic';why.society='unrest: calm (civic voice)';}}}
 return{w,why};}
function aiPolicy(S,fid){const f=fac(S,fid);if(S.turn<15)return;
 if(!f.policy){f.policy=Object.assign({},AI_POLICY[f.pers]);for(const ax of POLICY_AXES){if(f.policy[ax]!==POLICIES[ax].def)logEv(S,'policyChanged',{f:fid,axis:ax,from:POLICIES[ax].def,to:f.policy[ax],name:POLICIES[ax].opts[f.policy[ax]].name,cost:0,unrest:0,why:'initial ('+f.pers+')'});}st(S,fid).policyChanges=(st(S,fid).policyChanges||0);return;}
 if(S.turn<40||(S.turn+fid*3)%10!==0||(f.unrest||0)>0)return;
 const {w,why}=aiPolicyWant(S,fid);f.polT=f.polT||{};
 for(const ax of POLICY_AXES){const cur=polOf(S,fid,ax);if(w[ax]===cur)continue;if(S.turn-(f.polT[ax]||0)<(why[ax]?25:45))continue;if(f.credits<switchCost(S,fid)+40)return;
  setPolicy(S,fid,ax,w[ax],why[ax]||'back to '+f.pers+' default');return;}}
function runAI(S,fid){aiDiplomacy(S,fid);planFaction(S,fid);aiPolicy(S,fid);
 const f=fac(S,fid);
 if(!f.research){const av=availTechs(S,fid);if(av.length){const sea=needSea(S,fid)?['soil','tidal','naval','ordnance'].filter(k=>av.indexOf(k)>=0):[];f.research=sea[0]||PRIO[f.pers].find(k=>av.indexOf(k)>=0)||av[0];if(sea.length)logEv(S,'aiNavalResearch',{f:fid,tech:TECHS[sea[0]].name});}}
 f.labs=f.pers==='scholarly'?0.7:f.pers==='militant'?0.4:0.5;
 const myc=S.cities.filter(c=>c.f===fid);
 const mys=myc.filter(c=>!c.ug);for(const it of ['beacon','array'])if(canBuild(S,fid,it)&&!myc.some(c=>c.queue.includes(it))&&mys.length){let best=mys[0],bv=-1;for(const c of mys){const v=cityYield(S,c)[1];if(v>bv){bv=v;best=c;}}if(best.queue.length&&UNITS[best.queue[0]])best.prod=Math.floor(best.prod/2);best.queue.unshift(it);logEv(S,'aiProject',{f:fid,item:FAC[it].name,city:best.name});}
 const pc=myc.find(c=>c.queue[0]==='beacon'||c.queue[0]==='array');
 if(pc&&!(rule(S,'economic')&&f.pers==='expansionist')&&(f.plan==='project'||f.credits>200)){const spend=Math.max(0,f.credits-40);const need=itemCost(pc.queue[0])-pc.prod;const add=Math.min(Math.floor(spend/2),need);if(add>0){pc.prod+=add;f.credits-=add*2;}}
 const hoard=rule(S,'economic')&&(f.pers==='expansionist'||f.credits>econTarget(S)*0.5);
 if(f.credits>160&&!pc&&!hoard){const c=myc.filter(c=>c.queue.length&&!FAC[c.queue[0]]||(c.queue.length&&!FAC[c.queue[0]].project)).sort((a,b)=>buyCost(a)-buyCost(b))[0];if(c&&buyCost(c)>0&&buyCost(c)<f.credits-60){f.credits-=buyCost(c);c.prod=itemCost(c.queue[0],c);}}
 for(const c of S.cities.filter(c=>c.f===fid)){aiCity(S,c);if(c.queue.length&&['docks','transport'].includes(c.queue[0])&&needSea(S,fid)&&buyCost(c)>0&&f.credits>buyCost(c)+30){f.credits-=buyCost(c);c.prod=itemCost(c.queue[0],c);}if(c.queue.length&&f.credits>buyCost(c)+40&&buyCost(c)>0&&(UNITS[c.queue[0]]&&!S.units.some(u=>u.at===c.at&&u.f===fid&&!UNITS[u.type].civ))){f.credits-=buyCost(c);c.prod=itemCost(c.queue[0],c);}}
 aiCollapse(S,fid);
 const my=S.units.filter(u=>u.f===fid).sort((a,b)=>a.id-b.id);for(const u of my)aiUnit(S,u);
 updateSeen(S,fid);
}
function runNatives(S){
 const bs=S.units.filter(u=>u.f<0);
 for(const u of bs){if(S.units.indexOf(u)<0)continue;const B=bfs(S,u.at,-1,6);let best=-1,bd=99;
  for(let i=0;i<B.dist.length;i++){if(B.dist[i]<=0)continue;const tu=S.units.find(o=>o.at===i&&o.f>=0),tc0=cityAt(S,i),tc=tc0&&!tc0.ug?tc0:null;if(tc0&&tc0.ug)continue;const owner=tu?tu.f:tc?tc.f:null;if(owner==null||(fac(S,owner).pers==='eco'&&(i+S.turn)%4===0)||(policyMods(S,owner).calm&&(i+S.turn)%2===0))continue;if(B.dist[i]<bd){bd=B.dist[i];best=i;}}
  if(best>=0)moveToward(S,u,best,6);else{const nb=nbrs(S,u.at).filter(j=>S.tiles[j].land&&!enemyAt(S,j,-1));if(nb.length)step(S,u,nb[ri(S,nb.length)]);}
 }
 // fungus spread & spawning
 const fung=[];for(let i=0;i<S.tiles.length;i++)if(S.tiles[i].f)fung.push(i);
 for(let k=0;k<3&&fung.length;k++){if(rand(S)<0.45){const s=fung[ri(S,fung.length)];const nb=nbrs(S,s).filter(j=>S.tiles[j].land&&!S.tiles[j].f&&!S.tiles[j].imp&&!cityAt(S,j));if(nb.length){const j=nb[ri(S,nb.length)];S.tiles[j].f=true;}}}
 const cap=1+Math.floor(S.turn/14*diff(S).nat);
 if(fung.length&&bs.length<cap&&rand(S)<Math.min(0.6,fung.length/120*diff(S).nat*Math.max(1,...S.factions.filter(f=>f.alive).map(f=>policyMods(S,f.id).beast)))){const s=fung[ri(S,fung.length)];if(!S.cities.some(c=>dist(S,c.at,s)<=3)&&!S.units.some(u=>u.at===s)){makeUnit(S,-1,'beast',s);logEv(S,'nativeSpawn',{at:s});}}
}

/* ---------- diplomacy (v0.5): relations, deals, Reputation ---------- */
const DIPLO={CEASE_TURNS:15,DIP_TURNS:15,COOP_TURNS:15,DIP_REP:60,COOP_SHARE:0.6,MIN_TURN:120,REP0:50,LOCK:30,BREAK:{ceasefire:15,peace:25,alliance:35},TRADE_TURNS:10};
const REL_NAMES={war:'War',ceasefire:'Ceasefire',peace:'Peace',alliance:'Alliance'};
const DEAL_NAMES={ceasefire:'Ceasefire',peace:'Peace treaty',alliance:'Alliance',openBorders:'Open borders',trade:'Resource trade'};
function dip(S){if(!S.dip){const m=()=>S.factions.map(()=>S.factions.map(()=>0));S.dip={rel:S.factions.map(()=>S.factions.map(()=>'war')),since:m(),ob:m(),contact:m(),rep:S.factions.map(()=>DIPLO.REP0),lock:S.factions.map(()=>0),offers:[],deals:[],contracts:[],pending:[],nextId:1,dipTurns:S.factions.map(()=>0),coopTurns:0};}return S.dip;}
function relOf(S,a,b){if(a===b)return'self';if(a<0||b<0)return'war';return dip(S).rel[a][b];}
function atWar(S,a,b){return a!==b&&(a<0||b<0||dip(S).rel[a][b]==='war');}
function passOK(S,fid,owner){if(owner==null||owner<0||fid<0||owner===fid)return true;const D=dip(S),r=D.rel[fid][owner];return r==='war'||r==='alliance'||!!D.ob[fid][owner];}
function repLabel(r){return r>=80?'Exemplary':r>=60?'Trusted':r>=40?'Fair':r>=20?'Doubtful':'Treacherous';}
function repAdd(S,fid,d,why){const D=dip(S);if(d>0)d=Math.round(d*policyMods(S,fid).rep*10)/10;const old=D.rep[fid];D.rep[fid]=Math.max(0,Math.min(100,Math.round((old+d)*10)/10));if(D.rep[fid]!==old)logEv(S,'reputation',{f:fid,d,rep:D.rep[fid],why});}
function locked(S,fid){return dip(S).lock[fid]>S.turn;}
function pactCount(S,fid){let n=0;for(const o of S.factions)if(o.alive&&o.id!==fid){const r=dip(S).rel[fid][o.id];if(r==='peace'||r==='alliance')n++;}return n;}
function expel(S,a,b){const tr=territory(S);let n=0;const home=S.cities.filter(c=>c.f===a&&!c.ug);if(!home.length)return;
 for(const u of S.units)if(u.f===a&&tr[u.at]===b&&!passOK(S,a,b)&&!isShip(u)&&u.on==null&&S.tiles[u.at].land){let best=home[0],bd=1e9;for(const c of home){const d=dist(S,c.at,u.at);if(d<bd){bd=d;best=c;}}u.at=best.at;u.goto=-1;u.tgt=-1;u.work=null;n++;}
 if(n)logEv(S,'unitsWithdrawn',{f:a,from:b,n});}
function setRel(S,a,b,r,why){const D=dip(S),prev=D.rel[a][b];D.rel[a][b]=D.rel[b][a]=r;D.since[a][b]=D.since[b][a]=S.turn;if(r==='war'||r==='ceasefire')D.ob[a][b]=D.ob[b][a]=0;
 if(r==='war')D.contracts=D.contracts.filter(c=>!((c.seller===a&&c.buyer===b)||(c.seller===b&&c.buyer===a)));
 logEv(S,'relation',{a,b,rel:r,prev,why});if(r!=='war'){expel(S,a,b);expel(S,b,a);}}
function declareWar(S,a,b,why){const D=dip(S);if(a===b||!S.factions[b]||!S.factions[b].alive)return'No such faction';const prev=D.rel[a][b];if(prev==='war')return'Already at war';
 if(DIPLO.BREAK[prev]){repAdd(S,a,-DIPLO.BREAK[prev],'broke '+prev+' with '+S.factions[b].name);D.lock[a]=S.turn+DIPLO.LOCK;st(S,a).betrayals=(st(S,a).betrayals||0)+1;logEv(S,'betrayal',{f:a,vs:b,treaty:prev,why:why||'',rep:D.rep[a],lockUntil:D.lock[a]});}
 setRel(S,a,b,'war',why||'declared');return null;}
function dealText(S,o){const n=o.kind==='trade'?(o.amt+' '+o.res+'/turn for '+DIPLO.TRADE_TURNS+' turns ↔ '+o.price+' credits'):DEAL_NAMES[o.kind];return n;}
function validDeal(S,o){const D=dip(S),a=o.from,b=o.to;if(a===b||!S.factions[b]||!S.factions[b].alive||!S.factions[a]||!S.factions[a].alive)return'No such faction';if(!D.contact[a][b])return'No contact with '+S.factions[b].name+' yet';
 const r=D.rel[a][b],since=S.turn-D.since[a][b];
 switch(o.kind){case'ceasefire':return r==='war'?null:'Not at war';
 case'peace':return r==='ceasefire'?(since>=3?null:'Ceasefire must hold 3 turns first'):'Needs a ceasefire first';
 case'alliance':return r==='peace'?(since>=8?null:'Peace must hold 8 turns first'):'Needs a peace treaty first';
 case'openBorders':return r==='peace'?(D.ob[a][b]?'Borders already open':null):(r==='alliance'?'Allies already share passage':'Needs a peace treaty first');
 case'trade':{if(r==='war')return'Cannot trade while at war';if(['energy','minerals'].indexOf(o.res)<0)return'Trade energy or minerals';if(!(o.amt>=1&&o.amt<=6))return'Amount 1-6 per turn';if(!(o.price>=0&&o.price<=500))return'Bad price';
  if(D.contracts.some(c=>(c.seller===a&&c.buyer===b)||(c.seller===b&&c.buyer===a)))return'A trade contract is already running';const buyer=o.buy?a:b;if(fac(S,buyer).credits<o.price)return S.factions[buyer].name+' lacks '+o.price+' credits';return null;}}
 return'Unknown deal';}
function resValue(S,fid,res){const p=fac(S,fid).pers;return res==='energy'?(p==='scholarly'?2.2:p==='expansionist'?1.3:1.5):(p==='militant'?1.9:1.5);}
function strength(S,a,b){return (milPower(S,a)+5)/(milPower(S,b)+5);}
function fungusFriendly(S,fid){const s=st(S,fid);return (fac(S,fid).pers==='eco'?20:Math.max(-10,10-(s.fungusCleared||0)))+policyMods(S,fid).fungRel;}
// deterministic AI evaluation of an offer made to `me`
function aiConsider(S,me,o){const D=dip(S),other=o.from,p=fac(S,me).pers,rep=D.rep[other],lk=locked(S,other),sr=strength(S,me,other),losing=sr<0.7;let prox=victoryProgress(S,other);if(rule(S,'economic')&&fac(S,other).credits>=econTarget(S)*(p==='eco'?0.55:0.35))prox=Math.max(prox,0.65);
 const ff=p==='eco'?fungusFriendly(S,other):0;
 switch(o.kind){
 case'ceasefire':if(p==='militant')return losing?[1,'outmatched']:[0,'Iron does not bargain while it can fight'];
  if(prox>0.6&&!losing)return[0,'too close to victory'];if(rep<20&&!losing)return[0,'reputation too low'];
  if(p==='scholarly'&&sr>1.8&&fac(S,me).warTarget===other)return[0,'our offensive goes well'];if(p==='expansionist'&&sr>1.5)return[0,'we are winning'];return[1,'ok'];
 case'peace':if(lk&&!losing)return[0,'locked out after betrayal'];if(prox>0.6)return[0,'too close to victory'];if(p==='militant')return(losing&&rep>=30)?[1,'outmatched']:[0,'Iron prefers war'];
  return rep+ff>=(p==='eco'?35:40)?[1,'ok']:[0,'reputation too low'];
 case'alliance':{if(lk)return[0,'locked out after betrayal'];if(prox>0.5)return[0,'too close to victory'];const common=S.factions.some(x=>x.alive&&x.id!==me&&x.id!==other&&D.rel[me][x.id]==='war'&&D.rel[other][x.id]==='war');
  if(S.factions.some(x=>x.alive&&x.id!==me&&x.id!==other&&D.rel[me][x.id]==='alliance'))return[0,'already allied elsewhere'];
  if(p==='militant')return(common&&rep>=65)?[1,'common enemy']:[0,'Iron allies only against a common enemy'];
  if(p==='eco')return rep+ff>=55&&(common||S.turn-D.since[me][other]>=15)?[1,'ok']:[0,'not yet'];
  return common&&rep>=60?[1,'common enemy']:[0,'no common enemy'];}
 case'openBorders':if(lk)return[0,'locked out after betrayal'];if(p==='militant')return[0,'Iron keeps its borders shut'];if(p==='eco')return rep+ff>=45?[1,'ok']:[0,'reputation too low'];
  if(p==='scholarly')return rep>=55?[1,'ok']:[0,'reputation too low'];return rep>=60?[1,'ok']:[0,'reputation too low'];
 case'trade':{if(lk)return[0,'locked out after betrayal'];const iSell=!o.buy?false:true; // o.buy: proposer buys, so I sell
  const tot=o.amt*DIPLO.TRADE_TURNS;
  const rich=x=>fac(S,x).credits>=econTarget(S)*0.4;if(rich(other)||rich(me))return[0,iSell?'will not feed a front-runner':'no need'];
  if(iSell){if(prox>0.6)return[0,'will not feed a front-runner'];const want=tot*1.5*(p==='expansionist'?0.75:p==='militant'?1.15:p==='eco'?0.95:o.res==='energy'?1.3:1.0);return o.price>=Math.round(want)?[1,'fair price']:[0,'price too low (wants '+Math.round(want)+')'];}
  if(rep<40)return[0,'seller untrustworthy'];if(fac(S,me).credits<o.price)return[0,'cannot afford'];const val=tot*resValue(S,me,o.res);return o.price<=val?[1,'good value']:[0,'too expensive'];}}
 return[0,'unknown'];}
function applyDeal(S,o){const D=dip(S),a=o.from,b=o.to;
 if(o.kind==='ceasefire'||o.kind==='peace'||o.kind==='alliance'){const prev=D.rel[a][b];setRel(S,a,b,o.kind,'deal');if(prev==='ceasefire'&&o.kind==='peace'){repAdd(S,a,2,'ceasefire honoured');repAdd(S,b,2,'ceasefire honoured');}
  for(const x of [a,b]){const s=st(S,x);s.treaties=(s.treaties||0)+1;if(o.kind==='alliance')s.alliances=(s.alliances||0)+1;}}
 else if(o.kind==='openBorders'){D.ob[a][b]=D.ob[b][a]=1;logEv(S,'relation',{a,b,rel:D.rel[a][b],openBorders:true,why:'deal'});}
 else if(o.kind==='trade'){const buyer=o.buy?a:b,seller=o.buy?b:a;fac(S,buyer).credits-=o.price;fac(S,seller).credits+=o.price;D.contracts.push({id:o.id,seller,buyer,res:o.res,amt:o.amt,left:DIPLO.TRADE_TURNS,price:o.price});for(const x of [a,b]){const s=st(S,x);s.trades=(s.trades||0)+1;}}
 D.deals.push({t:S.turn,id:o.id,a,b,kind:o.kind,text:dealText(S,o)});if(D.deals.length>120)D.deals.shift();}
function recordOffer(S,o,answer,why){const D=dip(S);o.answer=answer;o.why=why;D.offers.push(Object.assign({},o));if(D.offers.length>200)D.offers.shift();logEv(S,'diploAnswer',{id:o.id,from:o.from,to:o.to,kind:o.kind,answer,why,text:dealText(S,o)});
 const s=st(S,o.from);s.offersMade=(s.offersMade||0)+1;if(answer==='accepted')s.offersAccepted=(s.offersAccepted||0)+1;}
// make an offer; AI targets answer at once, a human target gets it queued
function propose(S,from,to,deal){const D=dip(S);const o=Object.assign({id:D.nextId,t:S.turn,from,to},deal);o.amt=o.amt!=null?+o.amt:undefined;o.price=o.price!=null?+o.price:undefined;o.buy=!!o.buy;
 const e=validDeal(S,o);if(e)return{ok:false,msg:e};D.nextId++;logEv(S,'diploOffer',{id:o.id,from,to,kind:o.kind,res:o.res,amt:o.amt,price:o.price,buy:o.buy,text:dealText(S,o)});
 if(!fac(S,to).ai){D.pending.push(o);return{ok:true,msg:'Offer sent to '+S.factions[to].name,pending:true,o};}
 const [ok,why]=aiConsider(S,to,o);if(ok){applyDeal(S,o);recordOffer(S,o,'accepted',why);return{ok:true,accepted:true,msg:S.factions[to].name+' accepts: '+dealText(S,o),o};}
 recordOffer(S,o,'declined',why);return{ok:true,accepted:false,msg:S.factions[to].name+' declines '+dealText(S,o)+' ('+why+')',o};}
function answerOffer(S,fid,id,accept){const D=dip(S),k=D.pending.findIndex(o=>o.id===id&&o.to===fid);if(k<0)return{ok:false,msg:'No such offer'};const o=D.pending.splice(k,1)[0];
 if(accept){const e=validDeal(S,o);if(e){recordOffer(S,o,'void',e);return{ok:false,msg:'Offer no longer valid: '+e};}applyDeal(S,o);recordOffer(S,o,'accepted','player');return{ok:true,msg:'Accepted: '+dealText(S,o)};}
 recordOffer(S,o,'declined','player');return{ok:true,msg:'Declined: '+dealText(S,o)};}
function aiDiplomacy(S,fid){const D=dip(S),f=fac(S,fid),p=f.pers;
 // deny a front-runner: break peace/ceasefire with a faction close to any victory
 for(const o of S.factions){const j=o.id;if(j===fid||!o.alive||D.rel[fid][j]==='war')continue;const rich=rule(S,'economic')&&o.credits>=econTarget(S)*(D.rel[fid][j]==='alliance'||p==='eco'?0.6:p==='scholarly'?0.55:0.45)&&o.credits>f.credits*2;if(D.rel[fid][j]==='alliance'&&!(victoryProgress(S,j)>=0.85&&p!=='eco')&&!rich)continue;const dt=D.dipTurns[j]/DIPLO.DIP_TURNS,vp=victoryProgress(S,j);if((p!=='eco'&&dt>=(p==='scholarly'?0.9:0.75)&&score(S,j)>score(S,fid)*1.1)||(vp>=(p==='eco'?0.8:p==='scholarly'?0.72:0.62)&&vp>victoryProgress(S,fid)+0.12)||rich){declareWar(S,fid,j,dt>=0.75?'denying diplomatic victory':'stopping a front-runner');break;}}
 if((S.turn+fid)%2)return;let n=0;
 for(const o of S.factions){if(n>=2)break;const j=o.id;if(j===fid||!o.alive||!D.contact[fid][j])continue;if(D.pending.some(x=>x.from===fid&&x.to===j))continue;
  const r=D.rel[fid][j],since=S.turn-D.since[fid][j],sr=strength(S,fid,j),prox=victoryProgress(S,j),rep=D.rep[j];let deal=null;
  if(r==='war'){if(prox>0.6||S.turn<8)continue;const want=p==='eco'?true:p==='scholarly'?!(sr>1.8&&f.warTarget===j):p==='expansionist'?sr<1.3:sr<0.7;if(want&&since>=3&&rep>=(p==='militant'?0:20))deal={kind:'ceasefire'};}
  else if(r==='ceasefire'){if(since>=4&&(p!=='militant'||sr<0.7)&&rep>=40&&prox<0.6)deal={kind:'peace'};}
  else if(r==='peace'){const common=S.factions.some(x=>x.alive&&x.id!==fid&&x.id!==j&&D.rel[fid][x.id]==='war'&&D.rel[j][x.id]==='war');
   if(since>=8&&!locked(S,j)&&prox<0.5&&!S.factions.some(x=>x.alive&&x.id!==fid&&D.rel[fid][x.id]==='alliance')&&((common&&rep>=60&&(p!=='militant'||rep>=65))||(p==='eco'&&rep+fungusFriendly(S,j)>=55&&since>=15)))deal={kind:'alliance'};
   else if(!D.ob[fid][j]&&(p==='eco'||p==='scholarly')&&rep>=50&&since>=2)deal={kind:'openBorders'};}
  if(!deal&&r!=='war'&&!locked(S,j)&&rep>=40&&f.credits<econTarget(S)*0.4&&fac(S,j).credits<econTarget(S)*0.4&&!D.contracts.some(c=>(c.seller===fid&&c.buyer===j)||(c.seller===j&&c.buyer===fid))&&(S.turn+j)%6<2){
   if(p==='scholarly'&&f.credits>=70){const amt=3,price=Math.round(amt*DIPLO.TRADE_TURNS*1.6);if(f.credits>=price+20)deal={kind:'trade',res:'energy',amt,price,buy:true};}
   else if(p==='expansionist'&&fac(S,j).credits>=60&&prox<0.6&&!D.contracts.some(c=>c.seller===fid)){const amt=2,res=fac(S,j).pers==='scholarly'?'energy':'minerals',price=Math.round(amt*DIPLO.TRADE_TURNS*1.15);deal={kind:'trade',res,amt,price,buy:false};}
   else if(p==='militant'&&f.credits>=80&&has(S,fid,'kinetic')){const amt=3,price=Math.round(amt*DIPLO.TRADE_TURNS*1.5);if(f.credits>=price+30)deal={kind:'trade',res:'minerals',amt,price,buy:true};}}
  if(deal){const ak=fid+'-'+j+'-'+deal.kind;D.ask=D.ask||{};if(D.ask[ak]!=null&&S.turn-D.ask[ak]<6)deal=null;else if(!validDeal(S,Object.assign({from:fid,to:j},deal))){D.ask[ak]=S.turn;propose(S,fid,j,deal);n++;}}}}
// does `fid` break its treaty with opp to strike? (deterministic)
function aiWantsBreak(S,fid,opp){const D=dip(S),r=D.rel[fid][opp],p=fac(S,fid).pers,since=S.turn-D.since[fid][opp],prox=victoryProgress(S,opp),sr=strength(S,fid,opp);
 if(r==='war')return true;if(r==='alliance')return prox>0.9&&p==='militant';
 if(prox>0.65)return true;if(p==='militant')return since>=10&&sr>1.4&&S.turn>=graceTurn(S);
 return p==='expansionist'&&r==='ceasefire'&&sr>2&&since>=8;}
function diploTurn(S){const D=dip(S);const fs=S.factions;
 // contact
 for(const a of fs){if(!a.alive)continue;for(const b of fs){if(b.id<=a.id||!b.alive||D.contact[a.id][b.id])continue;let seen=false;
  for(const c of S.cities)if((c.f===b.id&&a.seen[c.at])||(c.f===a.id&&b.seen[c.at])){seen=true;break;}
  if(!seen)for(const u of S.units)if((u.f===b.id&&a.seen[u.at])||(u.f===a.id&&b.seen[u.at])){seen=true;break;}
  if(seen){D.contact[a.id][b.id]=D.contact[b.id][a.id]=1;logEv(S,'contact',{a:a.id,b:b.id});}}}
 // ceasefires lapse
 for(const a of fs)for(const b of fs)if(a.id<b.id&&D.rel[a.id][b.id]==='ceasefire'&&S.turn-D.since[a.id][b.id]>=DIPLO.CEASE_TURNS)setRel(S,a.id,b.id,'war','ceasefire expired');
 // contracts deliver
 for(const c of D.contracts.slice()){const s=fac(S,c.seller),b=fac(S,c.buyer);if(!s.alive||!b.alive){D.contracts.splice(D.contracts.indexOf(c),1);continue;}
  if(c.res==='energy'){const g=Math.min(c.amt,Math.max(0,s.rp));s.rp-=g;b.rp+=c.amt;}else{const sc=S.cities.find(x=>x.f===c.seller&&x.capital)||S.cities.find(x=>x.f===c.seller),bc=S.cities.find(x=>x.f===c.buyer&&x.capital)||S.cities.find(x=>x.f===c.buyer);if(sc)sc.prod=Math.max(0,sc.prod-c.amt);if(bc)bc.prod+=c.amt;}
  if(--c.left<=0){D.contracts.splice(D.contracts.indexOf(c),1);repAdd(S,c.seller,1,'trade contract honoured');logEv(S,'contractDone',{seller:c.seller,buyer:c.buyer,res:c.res});}}
 // pending human offers expire after one turn
 for(const o of D.pending.slice())if(S.turn-o.t>=1){D.pending.splice(D.pending.indexOf(o),1);recordOffer(S,o,'expired','no answer');}
 // honour ticks + stats
 for(const a of fs){if(!a.alive)continue;let kept=0,peace=false,ally=false;for(const b of fs){if(b.id===a.id||!b.alive)continue;const r=D.rel[a.id][b.id];if(r!=='war'){if(S.turn-D.since[a.id][b.id]>=10)kept++;if(r!=='ceasefire')peace=true;if(r==='alliance')ally=true;}}
  const s=st(S,a.id);if(peace)s.peaceTurns=(s.peaceTurns||0)+1;if(ally)s.allyTurns=(s.allyTurns||0)+1;if(S.turn%10===0){if(kept)repAdd(S,a.id,Math.min(2,kept),'treaties kept');if(D.rep[a.id]>75)repAdd(S,a.id,-1,'fading goodwill');}}}
function diploVictory(S){const D=dip(S),alive=S.factions.filter(f=>f.alive);if(S.winner!=null)return;
 if(rule(S,'diplomatic')){const need=Math.max(2,Math.floor(alive.length/2));let best=null;
  for(const f of alive){const top=alive.every(o=>o===f||score(S,o.id)<score(S,f.id));const ok=top&&alive.length>=3&&S.turn>=DIPLO.MIN_TURN&&pactCount(S,f.id)>=need&&D.rep[f.id]>=DIPLO.DIP_REP;const prev=D.dipTurns[f.id];D.dipTurns[f.id]=ok?prev+1:0;if(ok&&prev===0)logEv(S,'diplomacyStarted',{f:f.id,pacts:pactCount(S,f.id),turns:DIPLO.DIP_TURNS});
   if(D.dipTurns[f.id]>=DIPLO.DIP_TURNS&&(!best||score(S,f.id)>score(S,best.id)))best=f;}
  if(best){S.winner=best.id;S.winType='diplomatic';logEv(S,'victory',{f:best.id,kind:'diplomatic victory (council leader with '+pactCount(S,best.id)+' of '+(alive.length-1)+' living rivals at peace or allied for '+DIPLO.DIP_TURNS+' turns)'});return;}}
 if(rule(S,'cooperative')){ // shared win: all survivors allied, or an allied pair jointly holding COOP_SHARE of the land, for COOP_TURNS
  let all=alive.length>=2&&S.turn>=DIPLO.MIN_TURN;for(const a of alive)for(const b of alive)if(a.id<b.id&&D.rel[a.id][b.id]!=='alliance')all=false;
  let pair=null;if(!all&&S.turn>=DIPLO.MIN_TURN){for(const a of alive)for(const b of alive)if(a.id<b.id&&D.rel[a.id][b.id]==='alliance'&&S.turn-D.since[a.id][b.id]>=10&&(a.landShare||0)+(b.landShare||0)>=DIPLO.COOP_SHARE)pair=[a,b];}
  const grp=all?alive:pair;const key=grp?grp.map(f=>f.id).join('-'):'';if(key&&key===D.coopKey)D.coopTurns++;else{D.coopTurns=key?1:0;D.coopKey=key;if(key)logEv(S,'cooperationStarted',{fs:grp.map(f=>f.id),turns:DIPLO.COOP_TURNS,how:all?'all allied':'joint land share'});}
  if(grp&&D.coopTurns>=DIPLO.COOP_TURNS){const lead=grp.slice().sort((a,b)=>score(S,b.id)-score(S,a.id)||a.id-b.id)[0];S.winner=lead.id;S.winners=grp.map(f=>f.id);S.winType='cooperative';logEv(S,'victory',{f:lead.id,winners:S.winners,kind:'cooperative victory (shared by '+grp.map(f=>f.name).join(' & ')+')'});}}}

/* ---------- navies (v0.6) ---------- */
const isShip=u=>!!(u&&UNITS[u.type]&&UNITS[u.type].ship);
function coastal(S,c){return !!c&&!c.ug&&(!!c.sea||nbrs(S,c.at).some(n=>!S.tiles[n].land));}
function hasDocks(S,fid){return fid>=0&&S.cities.some(c=>c.f===fid&&c.fac.indexOf('docks')>=0);}
function portFor(S,i,fid){const c=cityAt(S,i);return !!c&&coastal(S,c)&&(c.f===fid||(fid>=0&&c.f>=0&&S.dip&&relOf(S,fid,c.f)==='alliance'));}
function cargoOf(S,t){return S.units.filter(u=>u.on===t.id);}
function transportAt(S,i,fid){for(const u of S.units)if(u.at===i&&u.f===fid&&UNITS[u.type].cap&&cargoOf(S,u).length<UNITS[u.type].cap)return u;return null;}
const _mi=(typeof WeakMap!=='undefined')?new WeakMap():null;
function mapInfo(S){let m=_mi&&_mi.get(S.tiles);if(m)return m;const N=S.W*S.H,lm=new Int32Array(N).fill(-1),ld=new Int8Array(N).fill(99),size=[];let k=0;
 for(let i=0;i<N;i++)if(S.tiles[i].land&&lm[i]<0){const q=[i];lm[i]=k;let n=0;while(q.length){const c=q.pop();n++;for(const j of nbrs(S,c))if(S.tiles[j].land&&lm[j]<0){lm[j]=k;q.push(j);}}size.push(n);k++;}
 const q=[];for(let i=0;i<N;i++)if(S.tiles[i].land){ld[i]=0;q.push(i);}for(let h=0;h<q.length;h++){const c=q[h];if(ld[c]>=9)continue;for(const j of nbrs(S,c))if(ld[j]>ld[c]+1){ld[j]=ld[c]+1;q.push(j);}}
 m={lm,ld,size,big:size.filter(s=>s>=30).length};if(_mi)_mi.set(S.tiles,m);return m;}
function seaReach(S,fid){return hasDocks(S,fid)?3:1;}
function board(S,u,tr){u.on=tr.id;u.at=tr.at;u.mp=0;u.fort=false;u.work=null;u.goto=-1;u.wantShip=false;logEv(S,'boarded',{f:u.f,unit:UNITS[u.type].name,ship:UNITS[tr.type].name,at:tr.at});}
function afterMove(S,u,from,to){const t=S.tiles[to];
 if(isShip(u)){for(const x of S.units)if(x.on===u.id)x.at=to;return;}
 if(u.on!=null&&(t.land||cityAt(S,to))){const sea=!S.tiles[from].land&&!cityAt(S,from);u.on=null;if(sea){u.mp=0;if(u.f>=0){st(S,u.f).landings=(st(S,u.f).landings||0)+1;}logEv(S,'landing',{f:u.f,unit:UNITS[u.type].name,at:to});}}
 else if(u.on!=null&&!t.land)u.on=null;}
function sinkShip(S,ship,by){const cg=S.units.filter(x=>x.on===ship.id);const atSea=!S.tiles[ship.at].land&&!cityAt(S,ship.at);
 if(atSea){for(const x of cg){removeUnit(S,x);if(x.f>=0)st(S,x.f).lost++;}}else for(const x of cg)x.on=null;
 if(ship.f>=0)st(S,ship.f).shipsLost=(st(S,ship.f).shipsLost||0)+1;if(by!=null&&by>=0)st(S,by).shipsSunk=(st(S,by).shipsSunk||0)+1;
 logEv(S,'shipSunk',{f:ship.f,ship:UNITS[ship.type].name,by:by==null?-1:by,cargo:atSea?cg.length:0,at:ship.at,cargoTypes:atSea?cg.map(x=>UNITS[x.type].name):[]});}
function canBombard(S,u,at){if(!u||!UNITS[u.type].bomb)return'Only Frigates and Assault Cruisers can bombard';if(u.mp<=0)return'No moves left';if(S.tiles[u.at].land||cityAt(S,u.at))return'Must be at sea to bombard';if(at==null||dist(S,u.at,at)!==1)return'Target must be next to the ship (within one tile of shore)';
 const c=cityAt(S,at);if(!c||c.f===u.f)return'No enemy city or warren entrance next to the ship';if(c.f>=0&&!atWar(S,u.f,c.f))return REL_NAMES[relOf(S,u.f,c.f)]+' with '+fac(S,c.f).name+': declare war first (D)';return null;}
function bombardTargets(S,u){return nbrs(S,u.at).filter(i=>!canBombard(S,u,i));}
function bombard(S,u,at){const e=canBombard(S,u,at);if(e)return e;const c=cityAt(S,at);const A=attStrength(S,u)*(c.ug&&!has(S,u.f,'sapper')?0.6:1);const had=!!bestDefender(S,at,u);let hits=0,taken=0;
 for(let k=0;k<3;k++){const tg=bestDefender(S,at,u);const D=tg?defStrength(S,tg,u)*0.7:2;if(rand(S)<A/(A+D)){hits++;if(tg)tg.hp=Math.max(1,tg.hp-(1+ri(S,2)));}else{taken++;u.hp=Math.max(1,u.hp-1);}}
 let popLost=false;if(!had&&hits>0){if(c.pop>2){c.pop--;popLost=true;}c.prod=Math.floor(c.prod/2);}else if(hits>=2)c.prod=Math.max(0,c.prod-hits*3);
 u.mp=0;u.fort=false;st(S,u.f).bombards=(st(S,u.f).bombards||0)+1;logEv(S,'bombard',{f:u.f,ship:UNITS[u.type].name,city:c.name,cf:c.f,at,ug:!!c.ug,hits,taken,popLost});return null;}
function needSea(S,fid){const f=fac(S,fid),M=mapInfo(S);if(M.big<2)return false;if(f._ns&&f._ns.t+8>S.turn)return f._ns.v;const cs=S.cities.filter(c=>c.f===fid&&!c.ug);let v=false;
 if(cs.length){const ms=new Set(cs.map(c=>M.lm[c.at]).filter(x=>x>=0));let free=0;for(let i=0;i<S.tiles.length&&free<2;i+=2)if(ms.has(M.lm[i])&&siteScore(S,i,fid)>=0)free++;
  const foe=S.cities.some(c=>c.f!==fid&&c.f>=0&&!ms.has(M.lm[c.at]));v=free<2||(f.pers==='militant'&&foe&&S.turn>60);}
 f._ns={t:S.turn,v};return v;}
function qCount(S,fid,t){let n=0;for(const c of S.cities)if(c.f===fid)for(const q of c.queue)if(q===t)n++;return n;}
function aiNaval(S,c,my,cities,plan){const f=fac(S,c.f),fid=c.f,p=f.pers;if(c.ug||!coastal(S,c))return null;const M=mapInfo(S),islands=M.big>=2;const hasD=c.fac.indexOf('docks')>=0;
 if((c.sea||p==='eco')&&c.pop>=3){for(const k of ['fishery','tidalc'])if(canBuild(S,fid,k)&&c.fac.indexOf(k)<0&&!c.queue.includes(k)&&rand(S)<(c.sea?0.5:0.25))return k;}
 if(!hasD){if(!canBuild(S,fid,'docks')||c.pop<2||S.turn<30)return null;const nd=cities.filter(o=>o.fac.indexOf('docks')>=0).length+qCount(S,fid,'docks');const nc=cities.filter(o=>coastal(S,o)).length;
  const ns=needSea(S,fid);const want=ns?0.9:{militant:0.4,expansionist:0.4,scholarly:0.2,eco:0.3}[p]*(islands?1.6:1);const cap=nd===0?1:Math.ceil(nc/(p==='scholarly'?6:p==='eco'?3:4));
  if(nd<cap&&rand(S)<want)return'docks';return null;}
 const ships=my.filter(isShip),n=t=>ships.filter(s=>s.type===t).length+qCount(S,fid,t);
 const war=canBuild(S,fid,'cruiser')?'cruiser':canBuild(S,fid,'frigate')?'frigate':null;
 const waiters=my.filter(u=>u.wantShip&&u.on==null).length;
 if(waiters&&n('transport')<Math.ceil(waiters/3))return'transport';
 if(needSea(S,fid)&&c.pop>=3&&cities.length<{expansionist:12,militant:9,eco:9,scholarly:9}[p]&&my.filter(u=>u.type==='colonist').length+qCount(S,fid,'colonist')<2&&rand(S)<0.5)return'colonist';
 if(needSea(S,fid)&&n('transport')<1&&rand(S)<0.6)return'transport';
 if(p==='scholarly'&&n('skiff')<2&&rand(S)<0.35)return'skiff';
 if(p==='expansionist'&&n('transport')<1+Math.floor(cities.length/6)&&rand(S)<0.35)return'transport';
 if(p==='militant'&&islands&&n('transport')<1+(plan==='strike'?1:0)&&rand(S)<0.35)return'transport';
 const ws=ships.filter(s=>UNITS[s.type].bomb).length+qCount(S,fid,'frigate')+qCount(S,fid,'cruiser'),nc=cities.filter(o=>coastal(S,o)).length;
 if(war){if(p==='militant'&&ws<Math.ceil(nc*(islands?0.8:0.5))&&rand(S)<0.35)return war;
  if(p==='eco'&&ws<Math.ceil(nc*0.5)&&rand(S)<0.3)return war;
  if(p==='expansionist'&&ws<Math.ceil(n('transport')/2)&&rand(S)<0.3)return war;
  if(p==='scholarly'&&ws<1&&rand(S)<0.12)return war;}
 if(p!=='scholarly'&&n('skiff')<1&&S.turn<150&&rand(S)<0.15)return'skiff';
 return null;}
function seaSiteScore(S,i,fid){const t=S.tiles[i];if(t.land)return -1;const M=mapInfo(S);if(M.ld[i]>seaReach(S,fid))return -1;if(M.ld[i]>1&&S.cities.filter(c=>c.f===fid&&c.sea&&M.ld[c.at]>1).length>=2)return -1;if(S.cities.some(c=>dist(S,c.at,i)<3))return -1;const tr=territory(S)[i];if(tr>=0&&tr!==fid)return -1;let s=0;for(const n of nbrs(S,i,2)){const y=yields(S,n,fid);s+=y[0]*1.5+y[1]+y[2]+(S.tiles[n].land?0:0.6);}return s;}
function nearPort(S,u){const B=bfs(S,u.at,u.f,30);let b=-1,bd=1e9;for(const c of S.cities)if(c.f===u.f&&coastal(S,c)&&B.dist[c.at]>=0){const v=B.dist[c.at]*2+(c.fac.indexOf('docks')>=0?0:2);if(v<bd){bd=v;b=c.at;}}return b;}
function waitForShip(S,u){const p=nearPort(S,u);if(p<0)return false;u.wantShip=true;if(u.at!==p)moveToward(S,u,p,30);else{u.skip=true;}return true;}
function aiShip(S,u){const fid=u.f,f=fac(S,fid),T=UNITS[u.type];const B=bfs(S,u.at,fid,40,false,1);
 const home=()=>{let b=-1,bd=1e9;for(const c of S.cities)if(c.f===fid&&coastal(S,c)&&B.dist[c.at]>=0){const v=B.dist[c.at]*2+(c.fac.indexOf('docks')>=0?0:3);if(v<bd){bd=v;b=c.at;}}return b;};
 if(T.cap){aiTransport(S,u,B,home);return;}
 if(u.hp<=4){const h=home();if(h>=0&&h!==u.at)moveToward(S,u,h,40,B);else u.fort=true;return;}
 if(T.a>0){let best=-1,bs=-1e9;const aS=attStrength(S,u);
  for(const x of S.units){if(x.f===fid||x.f<0||!isShip(x)||!atWar(S,fid,x.f)||S.tiles[x.at].land||cityAt(S,x.at))continue;const d=B.dist[x.at];if(d<0||d>T.mv*2)continue;const dv=defStrength(S,x,u);const s=(aS-dv)*4-d*2+(UNITS[x.type].cap?8:0);if(s>bs){bs=s;best=x.at;}}
  if(best>=0&&bs>-4){moveToward(S,u,best,40,B);return;}}
 if(T.bomb){const tryB=()=>{if(S.units.indexOf(u)<0||u.mp<=0||u.hp<5)return false;const ts=bombardTargets(S,u);if(!ts.length)return false;bombard(S,u,ts[0]);return true;};if(tryB())return;
  const aggr=f.pers==='militant'||f.pers==='expansionist'||f.plan==='strike'||f.plan==='military';
  if(aggr){let best=-1,bd=1e9;for(const c of S.cities){if(c.f===fid||!atWar(S,fid,c.f))continue;for(const n of nbrs(S,c.at)){if(B.dist[n]<0||S.tiles[n].land||cityAt(S,n))continue;const v=B.dist[n]-(c.f===f.warTarget?8:0)+(c.ug?3:0);if(v<bd&&B.dist[n]<=30){bd=v;best=n;}}}
   if(best>=0){moveToward(S,u,best,40,B);tryB();return;}}
  // guard: Verdant and everyone else keep warships off their own coast
  const mine=S.cities.filter(c=>c.f===fid&&coastal(S,c));if(mine.length){let wc=null,wv=1e9;for(const c of mine){const g=S.units.filter(x=>x.f===fid&&UNITS[x.type].bomb&&dist(S,x.at,c.at)<=2&&x!==u).length;const v=g*20+dist(S,c.at,u.at);if(v<wv){wv=v;wc=c;}}
   const spot=nbrs(S,wc.at).filter(n=>!S.tiles[n].land&&!cityAt(S,n)&&B.dist[n]>=0).sort((a,b)=>B.dist[a]-B.dist[b]||a-b)[0];if(spot!=null&&spot!==u.at){moveToward(S,u,spot,40,B);return;}}
  u.fort=true;return;}
 // skiff: explore unseen water
 if(u.tgt<0||u.at===u.tgt||f.seen[u.tgt]||B.dist[u.tgt]<0){let c2=-1,bd=1e9;for(let i=0;i<B.dist.length;i++){if(B.dist[i]<=0||f.seen[i])continue;const v=B.dist[i]*2+((i*7+u.id)%5);if(v<bd){bd=v;c2=i;}}
  if(c2<0){for(let i=0;i<B.dist.length;i++)if(B.dist[i]>3&&!S.tiles[i].land){const v=(i*31+S.turn*17+u.id)%97;if(v<bd){bd=v;c2=i;}}}u.tgt=c2;}
 if(u.tgt>=0)moveToward(S,u,u.tgt,40,B);}
function loadWaiters(S,u){const cap=UNITS[u.type].cap;let cg=cargoOf(S,u);for(const x of S.units){if(cg.length>=cap)break;if(x.f===u.f&&x.at===u.at&&x.wantShip&&x.on==null&&x!==u&&!isShip(x)){x.on=u.id;x.mp=0;x.wantShip=false;x.skip=false;cg.push(x);u.orig=u.at;logEv(S,'boarded',{f:u.f,unit:UNITS[x.type].name,ship:UNITS[u.type].name,at:u.at});}}return cg;}
function pickDest(S,u,cg){const fid=u.f,f=fac(S,fid),M=mapInfo(S);const om=u.orig!=null?M.lm[u.orig]:-2;
 const civ=cg.some(x=>UNITS[x.type].found);let best=-1,bs=-1e9;
 if(civ){for(let i=0;i<S.tiles.length;i++){const t=S.tiles[i];if(!t.land||t.f||M.lm[i]===om||dist(S,i,u.at)>28)continue;if(!nbrs(S,i,2).some(n=>!S.tiles[n].land))continue;const s=siteScore(S,i,fid);if(s<0)continue;const v=s-dist(S,i,u.at)*0.6;if(v>bs){bs=v;best=i;}}return best;}
 for(const c of S.cities){if(c.f===fid||!atWar(S,fid,c.f)||M.lm[c.at]===om)continue;if(!nbrs(S,c.at,2).some(n=>!S.tiles[n].land))continue;const v=-dist(S,c.at,u.at)+(c.f===f.warTarget?12:0)-c.pop;if(v>bs){bs=v;best=c.at;}}return best;}
function landingSpot(S,u,dest,B){const M=mapInfo(S);let best=-1,bv=1e9;for(let i=0;i<B.dist.length;i++){if(B.dist[i]<0||S.tiles[i].land||cityAt(S,i))continue;if(dist(S,i,dest)>6)continue;
  for(const j of nbrs(S,i)){if(!S.tiles[j].land||M.lm[j]!==M.lm[dest]||cityAt(S,j)||S.units.some(x=>x.at===j&&x.f!==u.f))continue;const v=B.dist[i]+dist(S,j,dest)*2;if(v<bv){bv=v;best=i;}}}return best;}
function unload(S,u,cg,dest){let n=0;for(const x of cg){if(S.units.indexOf(x)<0)continue;x.mp=UNITS[x.type].mv*3;const opts=nbrs(S,u.at).filter(j=>S.tiles[j].land&&!cityAt(S,j)&&!S.units.some(y=>y.at===j&&y.f!==u.f)&&treatyAt(S,j,u.f)==null).sort((a,b)=>dist(S,a,dest)-dist(S,b,dest)||a-b);if(!opts.length)continue;if(!step(S,x,opts[0])&&x.on==null){n++;x.tgt=-1;}}
 if(n){u.dest=-1;u.lt=-1;}return n;}
function aiTransport(S,u,B,home){const fid=u.f,f=fac(S,fid);let cg=loadWaiters(S,u);
 if(cg.length){u.trade=null;const full=cg.length>=UNITS[u.type].cap,wait=(u.waitT||0);
  if(!full&&S.units.some(x=>x.f===fid&&x.wantShip&&x.on==null&&dist(S,x.at,u.at)<=6)&&wait<3&&(S.tiles[u.at].land)){u.waitT=wait+1;return;}u.waitT=0;
  if(u.dest==null||u.dest<0||(u.destT||0)+30<S.turn){u.dest=pickDest(S,u,cg);u.destT=S.turn;u.lt=-1;}
  if(u.dest<0){const h=home();if(h>=0&&h!==u.at)moveToward(S,u,h,40,B);else for(const x of cg)x.on=null;return;}
  const adjOK=()=>nbrs(S,u.at).some(j=>S.tiles[j].land&&mapInfo(S).lm[j]===mapInfo(S).lm[u.dest]&&!cityAt(S,j)&&dist(S,j,u.dest)<=6&&!S.units.some(y=>y.at===j&&y.f!==fid));
  if(!S.tiles[u.at].land&&adjOK()){unload(S,u,cg,u.dest);return;}
  if(u.lt==null||u.lt<0||B.dist[u.lt]<0)u.lt=landingSpot(S,u,u.dest,B);if(u.lt<0){u.dest=-1;return;}
  moveToward(S,u,u.lt,40,B);if(S.units.indexOf(u)>=0&&!S.tiles[u.at].land&&adjOK())unload(S,u,cargoOf(S,u),u.dest);return;}
 const waiters=S.units.filter(x=>x.f===fid&&x.wantShip&&x.on==null);
 if(waiters.length){let best=-1,bd=1e9;for(const x of waiters){const d=B.dist[x.at];if(d>=0&&d<bd){bd=d;best=x.at;}}
  if(best>=0){if(best!==u.at)moveToward(S,u,best,40,B);if(S.units.indexOf(u)>=0)loadWaiters(S,u);return;}}
 if(f.pers==='expansionist'||(f.pers==='militant'&&u.id%3===0)||(f.pers==='scholarly'&&u.id%2===0)){tradeRun(S,u,B,home);return;}
 const h=home();if(h>=0&&h!==u.at)moveToward(S,u,h,40,B);else u.fort=true;}
function tradeRun(S,u,B,home){const fid=u.f,f=fac(S,fid),M=mapInfo(S);
 const valid=tr=>{if(!tr)return false;const c=S.cities.find(x=>x.id===tr.city);if(!c||!coastal(S,c))return false;if(c.f!==fid&&!['peace','alliance'].includes(relOf(S,fid,c.f)))return false;return true;};
 if(!valid(u.trade)){u.trade=null;const h=home();if(h<0){u.fort=true;return;}let best=null,bv=-1e9;
  for(const c of S.cities){if(!coastal(S,c)||c.at===h)continue;const own=c.f===fid;if(own?M.lm[c.at]===M.lm[h]&&!c.sea&&!cityAt(S,h).sea:!['peace','alliance'].includes(relOf(S,fid,c.f)))continue;
   const tile=portFor(S,c.at,fid)?c.at:nbrs(S,c.at).filter(n=>!S.tiles[n].land&&!cityAt(S,n)&&B.dist[n]>=0).sort((a,b)=>B.dist[a]-B.dist[b]||a-b)[0];if(tile==null||B.dist[tile]<0)continue;
   const len=dist(S,h,c.at);if(len<6)continue;const v=Math.min(len,30)-B.dist[tile]*0.3+(own?0:5);if(v>bv){bv=v;best={city:c.id,to:tile,home:h,leg:'out'};}}
  if(!best){if(h!==u.at)moveToward(S,u,h,40,B);else u.fort=true;return;}u.trade=best;}
 const tr=u.trade,goal=tr.leg==='out'?tr.to:tr.home;if(u.at!==goal)moveToward(S,u,goal,40,B);
 if(S.units.indexOf(u)<0||u.at!==goal)return;
 if(tr.leg==='out'){const c=S.cities.find(x=>x.id===tr.city);const g=1+Math.floor(dist(S,tr.home,c.at)/6);f.credits+=g;const s=st(S,fid);s.tradeRuns=(s.tradeRuns||0)+1;s.tradeCredits=(s.tradeCredits||0)+g;let pg=0;if(c.f!==fid){pg=Math.floor(g/2);fac(S,c.f).credits+=pg;}
  logEv(S,'tradeRun',{f:fid,city:c.name,partner:c.f,credits:g,partnerCredits:pg});tr.leg='back';}else tr.leg='out';}
/* ---------- turn processing ---------- */
function processFaction(S,fid){
 const f=fac(S,fid);let energy=0,maint=0;
 {const s=st(S,fid),dl=(s.lostAtt||0)-(f._lostSeen||0);f._lostSeen=s.lostAtt||0;f.ww=Math.round(((f.ww||0)*0.92+dl)*100)/100;}
 for(const c of S.cities.filter(c=>c.f===fid)){
  assignWork(S,c);const mo=S.turn>=10?cityMorale(S,c):{mood:'content'};if(mo.mood==='rioting'&&rand(S)<0.5)riot(S,c);
  const y=cityYield(S,c);const pm=policyMods(S,fid);y[0]+=pm.food;y[1]=Math.round(y[1]*pm.min);y[2]=Math.round(y[2]*pm.en);
  if(mo.mood!=='content')y[1]=Math.round(y[1]*(mo.mood==='rioting'?0.6:0.9));
  {let sur=y[0]-2*c.pop;if(sur>0&&mo.mood!=='content')sur=mo.mood==='rioting'?0:Math.floor(sur*3/4);c.food+=sur;}
  if(c.food>=foodBox(S,c)){if(c.pop<popCap(c)){c.pop++;c.food=0;logEv(S,'cityGrew',{f:fid,city:c.name,pop:c.pop});}else c.food=foodBox(S,c);}
  else if(c.food<0){if(c.pop>1){c.pop--;moodEvent(S,c,-1,5,'famine');logEv(S,'cityStarved',{f:fid,city:c.name,pop:c.pop});}c.food=0;}
  const support=Math.max(0,S.units.filter(u=>u.f===fid&&u.home===c.id).length-2-pm.sup);
  if(!(c.ug&&c.res&&c.res.pow===0))c.prod+=Math.max(0,Math.round(y[1]*mulFor(S,fid)*(f.pers==='scholarly'&&c.queue[0]&&FAC[c.queue[0]]&&FAC[c.queue[0]].project?1.35:1))-support);energy+=y[2];for(const k of c.fac)maint+=FAC[k].maint;
  if(!c.queue.length&&!f.ai){c.queue.push(c.pop>=2&&S.units.filter(u=>u.f===fid&&u.type==='colonist').length===0?'colonist':S.units.some(u=>u.at===c.at&&u.f===fid&&!UNITS[u.type].civ)?'terraformer':'trooper');logEv(S,'autoQueue',{f:fid,city:c.name,item:c.queue[0]});}
  if(c.queue[0]==='array'&&c.prod>0&&!(S.announced||(S.announced={}))[fid]){S.announced[fid]=c.id;logEv(S,'projectAnnounced',{f:fid,city:c.name,at:c.at,item:'Ascension Array'});}
  if(c.queue.length&&c.prod>=itemCost(c.queue[0],c)){const it=c.queue[0];
   if(UNITS[it]&&UNITS[it].found&&c.pop<2){/* wait */}
   else{c.queue.shift();c.prod-=itemCost(it,c);
    if(UNITS[it]){const u=makeUnit(S,fid,it,c.at);u.home=c.id;st(S,fid).built++;if(UNITS[it].found)c.pop--;if(UNITS[it].ship){st(S,fid).shipsBuilt=(st(S,fid).shipsBuilt||0)+1;logEv(S,'shipBuilt',{f:fid,city:c.name,ship:UNITS[it].name,at:c.at});}}
    else{c.fac.push(it);if(it==='array'){const ct=S.W*S.H>1800?15:12;S.ascension={f:fid,city:c.id,left:ct,total:ct};logEv(S,'ascensionStarted',{f:fid,city:c.name,at:c.at,turns:ct});}}
    logEv(S,'built',{f:fid,city:c.name,item:itemName(it)});}
  }
 }
 const ncs=S.cities.filter(c=>c.f===fid).length,ineff=Math.min(0.5,Math.max(0,ncs-5)*0.05);{const pm=policyMods(S,fid);energy+=Math.floor(ncs*pm.enCity);maint+=Math.floor(ncs*pm.upkeep);if(f.unrest>0){f.unrest--;if(!f.unrest)logEv(S,'unrestEnded',{f:fid});}}energy=Math.round(energy*(1-ineff));maint+=Math.max(0,ncs-8);
 const beacon=S.cities.some(c=>c.f===fid&&c.fac.indexOf('beacon')>=0);
 const labsMul=(beacon?1.25:1)*(f.pers==='scholarly'?1.45:1)*(has(S,fid,'signal')?1.1:1)*(has(S,fid,'quantum')?1.25:1);
 let labs=Math.round(energy*f.labs),econ=energy-labs;
 const spires=S.cities.filter(c=>c.f===fid&&c.fac.indexOf('spire')>=0).length,nc=S.cities.filter(c=>c.f===fid).length||1;
 labs=Math.round(labs*labsMul*(1+0.5*spires/nc)*mulFor(S,fid)*policyMods(S,fid).labs);
 f.credits+=econ-maint;if(f.credits<0){// sell a facility
  const c=S.cities.find(c=>c.f===fid&&c.fac.length&&c.fac[c.fac.length-1]!=='array');if(c){const k=c.fac.pop();logEv(S,'facilitySold',{f:fid,city:c.name,item:FAC[k].name});}f.credits=0;}
 if(!f.research){const av=availTechs(S,fid);if(av.length)f.research=(f.ai||rule(S,'blindResearch'))?PRIO[f.pers].find(k=>av.indexOf(k)>=0):av[0];}
 if(f.research){f.rp+=labs;if(f.rp>=techCost(S,fid)){f.rp-=techCost(S,fid);f.techs.push(f.research);logEv(S,'techDiscovered',{f:fid,tech:TECHS[f.research].name});f.research=null;}}
 f.lastIncome={energy,labs,econ,maint,ineff:+ineff.toFixed(2)};
}
function endTurn(S){
 if(S.winner!=null)return;_mapScale=bigScale(S.W,S.H);
 const _t0=Date.now();for(const f of S.factions)if(f.alive&&f.ai)runAI(S,f.id);const aiMs=Date.now()-_t0;
 runNatives(S);
 randomEvents(S);
 for(const f of S.factions)if(f.alive)processFaction(S,f.id);
 diploTurn(S);
 const noHeal=supplyTurn(S);
 for(const u of S.units){
  if(u.work){u.work.left--;if(u.work.left<=0){const t=S.tiles[u.at],k=u.work.kind;if(k==='clear'){t.f=false;if(u.f>=0)st(S,u.f).fungusCleared=(st(S,u.f).fungusCleared||0)+1;}else if(k==='road')t.road=true;else if(k==='tunnel'){const rep=!!(t.fl||t.col);t.tun=u.f;t.fl=0;t.col=0;if(rep)logEv(S,'tunnelRepaired',{f:u.f,at:u.at});if(u.work.rush)st(S,u.f).rushTiles=(st(S,u.f).rushTiles||0)+1;logEv(S,'tunnelDug',{f:u.f,at:u.at,rush:!!u.work.rush});}else{if(!t.f)t.imp=k;}if(u.f>=0&&!fac(S,u.f).ai)logEv(S,'terraformDone',{f:u.f,kind:k,at:u.at});u.work=null;u.tgt=-1;}}
  const c=cityAt(S,u.at);if(u.hp<10&&u.mp===UNITS[u.type].mv*3&&!noHeal.has(u.id))u.hp=Math.min(10,u.hp+(isShip(u)?(c&&c.f===u.f?(c.fac.indexOf('docks')>=0?10:3):0):(c&&c.f===u.f?3:1)));
  u.mp=UNITS[u.type].mv*3;u.skip=u.fort;u.tn=0;
 }
 if(S.ascension&&S.winner==null){const A=S.ascension,c=S.cities.find(x=>x.id===A.city);
  if(!c||c.f!==A.f){if(c){const k=c.fac.indexOf('array');if(k>=0)c.fac.splice(k,1);}logEv(S,'ascensionFailed',{f:A.f,city:c?c.name:'(destroyed)'});S.ascension=null;if(S.announced)delete S.announced[A.f];}
  else if(--A.left<=0){S.winner=A.f;S.winType='ascension';logEv(S,'victory',{f:A.f,kind:'Ascension completed in '+c.name});}}
 if(S.winner==null&&rule(S,'economic')){for(const f of S.factions)if(f.alive&&f.credits>=econTarget(S)){S.winner=f.id;S.winType='economic';logEv(S,'victory',{f:f.id,kind:'economic dominance ('+f.credits+' credits in reserve)'});break;}}
 if(S.winner==null&&rule(S,'dominion')){const tr=territory(S),sh=seaHeld(S,tr);let land=0;const cnt=S.factions.map(()=>0);for(let i=0;i<tr.length;i++)if(S.tiles[i].land||sh[i]){land++;if(tr[i]>=0)cnt[tr[i]]++;}
  for(const f of S.factions){const sh=cnt[f.id]/(land||1);f.landShare=+sh.toFixed(3);f.domTurns=sh>=domShare(S)?(f.domTurns||0)+1:0;if(f.domTurns===1)logEv(S,'dominionStarted',{f:f.id,share:f.landShare,turns:DOMINION_TURNS});if(f.domTurns>=DOMINION_TURNS){S.winner=f.id;S.winType='dominion';logEv(S,'victory',{f:f.id,kind:'planetary dominion ('+Math.round(sh*100)+'% of land for '+DOMINION_TURNS+' turns)'});break;}}}
 if(S.winner==null)diploVictory(S);
 // elimination
 for(const f of S.factions){if(!f.alive)continue;if(!S.cities.some(c=>c.f===f.id)&&!S.units.some(u=>u.f===f.id&&u.type==='colonist')){f.alive=false;S.units=S.units.filter(u=>u.f!==f.id);logEv(S,'eliminated',{f:f.id,name:f.name});}}
 const alive=S.factions.filter(f=>f.alive);
 if(S.winner==null&&(rule(S,'conquest')||alive.length===0)){if(alive.length===1){S.winner=alive[0].id;S.winType='conquest';logEv(S,'victory',{f:alive[0].id,kind:'conquest'});}else if(!alive.length){S.winner=-1;S.winType='extinction';}}
 if(S.winner==null&&S.turn>=(S.opts.maxTurns||300)){const sc=S.factions.map(f=>score(S,f.id));const w=sc.indexOf(Math.max(...sc));S.winner=w;S.winType='score';logEv(S,'victory',{f:w,kind:'highest score at turn limit'});}
 S.turnSummaries.push({t:S.turn,factions:S.factions.map(f=>({f:f.id,alive:f.alive,cities:S.cities.filter(c=>c.f===f.id).length,pop:S.cities.filter(c=>c.f===f.id).reduce((a,c)=>a+c.pop,0),units:S.units.filter(u=>u.f===f.id).length,techs:f.techs.length,credits:f.credits,ug:S.cities.filter(c=>c.f===f.id&&c.ug).length,score:score(S,f.id),rep:dip(S).rep[f.id]})),natives:S.units.filter(u=>u.f<0).length,aiMs,plans:S.factions.map(f=>f.plan||null),hash:hash(S)});
 S.turn++;
 // continue player goto orders
 for(const u of S.units.slice())if(u.goto>=0&&!fac(S,u.f).ai&&S.units.indexOf(u)>=0){moveToward(S,u,u.goto);if(S.units.indexOf(u)>=0&&u.at===u.goto)u.goto=-1;}
 for(const f of S.factions)if(f.alive)updateSeen(S,f.id);
}
function score(S,fid){const cs=S.cities.filter(c=>c.f===fid);return cs.reduce((a,c)=>a+c.pop,0)+cs.length*3+fac(S,fid).techs.length*2+cs.reduce((a,c)=>a+c.fac.length,0);}
function hash(S){const s=JSON.stringify([S.rs,S.units.map(u=>[u.id,u.at,u.hp,u.on==null?-1:u.on]),S.cities.map(c=>[c.id,c.f,c.pop,c.prod]),S.factions.map(f=>[f.credits,f.rp,f.techs.length]),S.dip?S.dip.rel.map(r=>r.join('')).join('|')+S.dip.rep.join(','):'']);let h=2166136261;for(let i=0;i<s.length;i++){h^=s.charCodeAt(i);h=Math.imul(h,16777619);}return(h>>>0).toString(16);}

function newGame(o){
 o=Object.assign({seed:(Date.now()%1000000000)|0,playerKey:'lumen',numAI:2,w:48,h:32,allAI:false,maxTurns:300},o||{});
 const S={version:VERSION,seed:o.seed,rs:o.seed|0,opts:o,turn:1,W:o.w,H:o.h,tiles:[],factions:[],units:[],cities:[],nextId:1,winner:null,winType:null,log:[],actions:[],turnSummaries:[],errors:[]};
 _mapScale=bigScale(S.W,S.H);
 genMap(S);
 const pf=FACTIONS.find(f=>f.key===o.playerKey)||FACTIONS[1];
 const others=FACTIONS.filter(f=>f!==pf);
 let order=[pf].concat(others.slice(0,Math.max(1,Math.min(3,o.numAI))));
 if(Array.isArray(o.factionKeys)&&o.factionKeys.length>=2)order=o.factionKeys.map(k=>FACTIONS.find(f=>f.key===k)).filter(Boolean);
 order.forEach((F,i)=>S.factions.push({id:i,key:F.key,name:F.name,leader:F.leader,color:F.color,pers:F.pers,bonus:F.bonus,ai:i>0||!!o.allAI,alive:true,stats:{built:0,lost:0,kills:0,founded:0},credits:F.pers==='expansionist'?30:10,labs:0.5,techs:[],research:null,rp:0,seen:new Array(S.W*S.H).fill(0)}));
 S.human=o.allAI?-1:0;
 placeStarts(S);
 dip(S);
 if(rule(S,'accelerated'))for(const f of S.factions){for(const t of ['colonist','terraformer','trooper'])makeUnit(S,f.id,t,f.start);f.credits+=60;for(let k=0;k<2;k++){const av=availTechs(S,f.id);const t=PRIO[f.pers].find(x=>av.indexOf(x)>=0);if(t)f.techs.push(t);}}
 if(rule(S,'fullMap'))for(const f of S.factions)f.seen.fill(1);
 for(const f of S.factions)updateSeen(S,f.id);
 logEv(S,'gameStart',{seed:S.seed,version:VERSION,difficulty:diff(S).name,rules:Object.assign({},DEFAULT_RULES,o.rules||{}),factions:S.factions.map(f=>f.name+(f.ai?' (AI, '+f.pers+')':' (player)'))});
 return S;
}
function statsTable(S){return S.factions.map(f=>{const s=f.stats||{};const cs=S.cities.filter(c=>c.f===f.id);return{riots:s.riots||0,riotIdle:s.riotIdle||0,riotSold:s.riotSold||0,rebels:s.rebels||0,moraleShifts:s.moraleShifts||0,unhappyTurns:s.unhappyTurns||0,unhappyNow:cs.filter(c=>c.mood&&c.mood!=='content').length,warWeariness:f.ww||0,policyChanges:s.policyChanges||0,policy:POLICY_AXES.map(ax=>polOf(S,f.id,ax)).join('/'),f:f.id,name:f.name,pers:f.pers,alive:f.alive,ai:f.ai,cities:cs.length,pop:cs.reduce((a,c)=>a+c.pop,0),techs:f.techs.length,units:S.units.filter(u=>u.f===f.id).length,built:s.built||0,lost:s.lost||0,warrens:cs.filter(c=>c.ug).length,warrensFounded:s.warrens||0,tunnels:S.tiles.filter(t=>t.tun===f.id).length,rushTiles:s.rushTiles||0,sieges:s.sieges||0,cutOff:s.cutOff||0,collapses:s.collapses||0,floods:s.floods||0,surrenders:s.surrenders||0,breaches:s.breaches||0,ugCapital:s.ugCapital||0,rep:S.dip?S.dip.rep[f.id]:50,repLabel:repLabel(S.dip?S.dip.rep[f.id]:50),relations:S.dip?S.factions.filter(o=>o.id!==f.id).map(o=>o.name+':'+S.dip.rel[f.id][o.id]+(S.dip.ob[f.id][o.id]?'+ob':'')).join(' '):'',betrayals:s.betrayals||0,treaties:s.treaties||0,alliances:s.alliances||0,trades:s.trades||0,offersMade:s.offersMade||0,offersAccepted:s.offersAccepted||0,peaceTurns:s.peaceTurns||0,allyTurns:s.allyTurns||0,ships:S.units.filter(u=>u.f===f.id&&isShip(u)).length,shipsBuilt:s.shipsBuilt||0,shipsLost:s.shipsLost||0,shipsSunk:s.shipsSunk||0,landings:s.landings||0,bombards:s.bombards||0,tradeRuns:s.tradeRuns||0,tradeCredits:s.tradeCredits||0,seaCities:cs.filter(c=>c.sea).length,docks:cs.filter(c=>c.fac.indexOf('docks')>=0).length,kills:s.kills||0,founded:s.founded||0,score:score(S,f.id)};});}
function gameSummary(S){const ts=S.turnSummaries;const samples=ts.filter(t=>t.t%10===0).map(t=>({t:t.t,f:t.factions.map(x=>[x.cities,x.pop,x.score,x.techs])}));
 const keyTypes=['shipSunk','landing','relation','betrayal','diplomacyStarted','cooperationStarted','warrenSurrendered','supplyCut','tunnelCollapsed','tunnelFlooded','capitalMoved','tunnelBreached','cityCaptured','cityDestroyed','eliminated','projectAnnounced','ascensionStarted','ascensionFailed','dominionStarted','victory','aiProject'];
 const plans={};for(const e of S.log)if(e.type==='aiPlan'){const k=e.f+':'+e.plan;plans[k]=(plans[k]||0)+1;}
 const aiMs=ts.map(t=>t.aiMs||0);
 return{seed:S.seed,version:VERSION,opts:S.opts,factions:S.factions.map(f=>({f:f.id,name:f.name,pers:f.pers})),winner:S.winner,winnerName:S.winner>=0?S.factions[S.winner].name:null,winType:S.winType,turns:S.turn,
  final:statsTable(S),samples,keyEvents:S.log.filter(e=>keyTypes.indexOf(e.type)>=0).slice(0,150),planChanges:plans,aiMsAvg:+(aiMs.reduce((a,b)=>a+b,0)/(aiMs.length||1)).toFixed(1),aiMsMax:Math.max(0,...aiMs),errors:S.errors||[]};}
function snapshot(S){const o=JSON.parse(JSON.stringify(S));o.log=[];o.turnSummaries=[];return o;}
function buildLog(S,reason){
 const hid=S.human==null?0:S.human,p=S.factions[hid>=0?hid:0];const L=[];
 L.push('Colony4X v'+VERSION+' | seed '+S.seed+' | turn '+S.turn+' | export reason: '+reason);
 L.push((hid>=0?'Player: ':'Autoplay (all AI); first faction: ')+p.name+' ('+p.pers+') credits '+p.credits+', techs '+p.techs.length+'/'+Object.keys(TECHS).length+', researching '+(p.research?TECHS[p.research].name:'-')+' ('+p.rp+'/'+techCost(S,p.id)+'), labs '+Math.round(p.labs*100)+'%');
 for(const f of S.factions)L.push(' '+f.name+(f.alive?'':' [ELIMINATED]')+': cities '+S.cities.filter(c=>c.f===f.id).map(c=>c.name+'('+c.pop+')').join(', ')+' | units '+S.units.filter(u=>u.f===f.id).length+' | score '+score(S,f.id));
 L.push('Native beasts: '+S.units.filter(u=>u.f<0).length+', fungus tiles: '+S.tiles.filter(t=>t.f).length);
 {const D=dip(S);const pr=[];for(const a of S.factions)for(const b of S.factions)if(a.id<b.id)pr.push(a.name+'–'+b.name+' '+D.rel[a.id][b.id]+(D.ob[a.id][b.id]?' (open borders)':''));L.push('Diplomacy: '+pr.join('; '));
  L.push('Reputation: '+S.factions.map(f=>f.name+' '+D.rep[f.id]+' '+repLabel(D.rep[f.id])+(locked(S,f.id)?' [locked out until T'+D.lock[f.id]+']':'')).join(', ')+' | offers '+D.offers.length+', deals '+D.deals.length+', contracts '+D.contracts.length+', pending '+D.pending.length);}
 L.push('Policies: '+S.factions.map(f=>f.name+' '+POLICY_AXES.map(ax=>POLICIES[ax].opts[polOf(S,f.id,ax)].name).join('/')+' (changes '+((f.stats||{}).policyChanges||0)+(f.unrest>0?', unrest '+f.unrest:'')+')').join(' | '));
 L.push('Morale: '+S.factions.map(f=>{const cs=S.cities.filter(c=>c.f===f.id),s=f.stats||{};return f.name+' content '+cs.filter(c=>(c.mood||'content')==='content').length+'/restless '+cs.filter(c=>c.mood==='restless').length+'/rioting '+cs.filter(c=>c.mood==='rioting').length+', riots '+(s.riots||0)+', war weariness '+(f.ww||0);}).join(' | ')+' | pressure x'+(diff(S).mor||1));
 L.push('Navies: '+S.factions.map(f=>{const s=f.stats||{};return f.name+' ships '+S.units.filter(u=>u.f===f.id&&isShip(u)).length+' (built '+(s.shipsBuilt||0)+', lost '+(s.shipsLost||0)+', sunk '+(s.shipsSunk||0)+'), landings '+(s.landings||0)+', bombards '+(s.bombards||0)+', trade runs '+(s.tradeRuns||0)+', sea cities '+S.cities.filter(c=>c.f===f.id&&c.sea).length;}).join('; '));
 if(S.winner!=null)L.push('GAME OVER: winner '+(S.winner>=0?S.factions[S.winner].name:'none')+' by '+S.winType+(S.winners?' (shared: '+S.winners.map(i=>S.factions[i].name).join(', ')+')':''));
 L.push('Errors recorded: '+S.errors.length+(S.errors.length?' (last: '+S.errors[S.errors.length-1].msg+')':''));
 L.push('Player actions: '+S.actions.length+'. Recent events:');
 for(const e of S.log.slice(-15)){const d=Object.assign({},e);delete d.t;delete d.type;L.push('  T'+e.t+' '+e.type+' '+JSON.stringify(d));}
 return{format:'colony4x-log',version:VERSION,seed:S.seed,turn:S.turn,reason,exportedAt:new Date().toISOString(),summary:L,opts:S.opts,errors:S.errors,actions:S.actions,turnSummaries:S.turnSummaries,stats:statsTable(S),diplomacy:(function(){const D=dip(S);return{relations:D.rel,openBorders:D.ob,contact:D.contact,reputation:D.rep,lockUntil:D.lock,offers:D.offers,deals:D.deals,contracts:D.contracts,pending:D.pending,dipTurns:D.dipTurns,coopTurns:D.coopTurns,winners:S.winners||null};})(),policies:{axes:POLICY_AXES,current:S.factions.map(f=>({f:f.id,pers:f.pers,policy:Object.fromEntries(POLICY_AXES.map(ax=>[ax,polOf(S,f.id,ax)])),unrest:f.unrest||0,changes:(f.stats||{}).policyChanges||0})),changes:S.log.filter(e=>e.type==='policyChanged')},morale:{pressure:diff(S).mor||1,cities:S.cities.map(c=>{const m=morale(S,c);return{f:c.f,city:c.name,pop:c.pop,v:m.v,mood:m.mood,parts:m.parts};}),warWeariness:S.factions.map(f=>f.ww||0),shifts:S.log.filter(e=>e.type==='moraleShift').length,riots:S.log.filter(e=>e.type==='riot')},naval:{ships:S.units.filter(isShip).map(u=>({id:u.id,f:u.f,type:u.type,at:u.at,hp:u.hp,cargo:cargoOf(S,u).map(x=>x.type)})),docks:S.cities.filter(c=>c.fac.indexOf('docks')>=0).map(c=>({f:c.f,city:c.name})),seaCities:S.cities.filter(c=>c.sea).map(c=>({f:c.f,city:c.name,pop:c.pop})),counts:(function(){const k={};for(const e of S.log)if(['shipBuilt','shipSunk','landing','boarded','bombard','tradeRun'].indexOf(e.type)>=0)k[e.type]=(k[e.type]||0)+1;return k;})()},events:S.log,snapshot:snapshot(S)};
}
function loadFromLog(L){const S=L.snapshot;_mapScale=bigScale(S.W,S.H);S.log=L.events||[];S.turnSummaries=L.turnSummaries||[];S.actions=L.actions||S.actions||[];S.errors=L.errors||[];return S;}
function replay(L,uptoTurn){const S=newGame(Object.assign({},L.opts));for(const a of L.actions){if(uptoTurn&&S.turn>=uptoTurn)break;act(S,a);}return S;}
const G={repAdd,fungusFriendly,moveCost,POLICY_AXES,polOf,switchCost,setPolicy,aiPolicyWant,morale,cityMorale,riot,moodEvent,pressure,MOOD_NAMES,costOf:(S,c,it)=>{_S=S;return itemCost(it,c);},defStrength,attStrength,isShip,coastal,hasDocks,portFor,cargoOf,transportAt,mapInfo,seaReach,canBombard,bombardTargets,bombard,seaSiteScore,seaHeld,aiShip,DIPLO,REL_NAMES,DEAL_NAMES,dip,relOf,atWar,passOK,repLabel,locked,pactCount,declareWar,validDeal,aiConsider,propose,answerOffer,dealText,setRel,diploTurn,victoryProgress,supplyMap,resCaps,collapseTunnel,floodTunnel,canFlood,bigScale,domShare,makeUnit,econTarget,fairLineup,gameSummary,graceTurn,POLICIES,policyMods,DIFFICULTY,DEFAULT_RULES,ECON_TARGET,DOMINION_SHARE,DOMINION_TURNS,rule,territory,suggestName,canFound,foundSite,statsTable,VERSION,TECHS,UNITS,FAC,TERRA,FACTIONS,newGame,act,endTurn,runAI,yields,cityYield,foodBox,popCap,techCost,availTechs,buildable,itemCost,itemName,buyCost,cityAt,unitsAt,nbrs,dist,X,Y,score,hash,buildLog,loadFromLog,replay,bfs,logEv,assignWork,siteScore};
if(typeof module!=='undefined'&&module.exports)module.exports=G;else root.G=G;
})(this);
