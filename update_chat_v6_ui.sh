#!/bin/bash
set -e
cd /home/admin/chatapp

# Backup
cp html/index.html backups/index.html.v6ui-$(date +%s) 2>/dev/null || true

# ============ PATCH 1: Adaugă CSS pentru profil + emoji avansat ============
python3 <<'PYEOF'
f='html/index.html'
s=open(f).read()

# === CSS NOU PENTRU PROFIL ===
profile_css = """
/* ============ PROFILE PAGE ============ */
#profile{display:none;position:fixed;inset:0;background:var(--bg);z-index:100;overflow:auto;animation:slideUp .3s ease}
#profile.on{display:block}
@keyframes slideUp{from{transform:translateY(100%);opacity:0}to{transform:none;opacity:1}}
.profile-header{
  background:var(--me);background-size:300% 300%;animation:gradient 8s ease infinite;
  padding:80px 20px 100px;text-align:center;color:#fff;position:relative;
}
.profile-back{
  position:absolute;top:16px;left:16px;background:rgba(255,255,255,.2);border:0;
  color:#fff;font-size:20px;width:40px;height:40px;border-radius:50%;cursor:pointer;
  backdrop-filter:blur(10px);transition:transform .15s;
}
.profile-back:hover{transform:scale(1.1)}
.profile-avatar{
  width:120px;height:120px;border-radius:50%;background:rgba(255,255,255,.2);
  margin:0 auto 16px;display:flex;align-items:center;justify-content:center;
  font-size:48px;font-weight:700;color:#fff;border:4px solid rgba(255,255,255,.4);
  box-shadow:0 12px 32px rgba(0,0,0,.2);position:relative;overflow:hidden;cursor:pointer;
  background-size:cover;background-position:center;
}
.profile-avatar:hover::after{
  content:'📷';position:absolute;inset:0;background:rgba(0,0,0,.5);
  display:flex;align-items:center;justify-content:center;font-size:32px;
}
.profile-header h2{font-size:26px;font-weight:700;margin:0;text-shadow:0 2px 8px rgba(0,0,0,.2)}
.profile-header .user-status{opacity:.9;margin-top:4px;font-size:15px}
.profile-body{
  max-width:600px;margin:-70px auto 0;padding:0 20px 40px;
}
.profile-stats{
  display:grid;grid-template-columns:repeat(3,1fr);gap:12px;background:var(--card-solid);
  border-radius:20px;padding:20px;box-shadow:var(--shadow-lg);border:1px solid var(--bd);
  margin-bottom:20px;
}
.profile-stats>div{text-align:center}
.profile-stats b{font-size:24px;font-weight:800;background:var(--me);-webkit-background-clip:text;-webkit-text-fill-color:transparent;background-clip:text;display:block}
.profile-stats small{color:var(--mut);font-size:12px;text-transform:uppercase;letter-spacing:.5px}
.profile-section{
  background:var(--card-solid);border-radius:20px;padding:20px;margin-bottom:16px;
  box-shadow:var(--shadow);border:1px solid var(--bd);
}
.profile-section label{
  display:block;font-size:12px;text-transform:uppercase;letter-spacing:.8px;
  color:var(--mut);font-weight:600;margin-bottom:8px;
}
.profile-section input,.profile-section textarea{
  background:var(--bg);border:1px solid var(--bd);padding:12px 14px;
}
.profile-save{
  width:100%;padding:14px;font-size:15px;margin-top:8px;
}

/* ============ EMOJI PICKER AVANSAT ============ */
#emojis{
  display:none;position:absolute;bottom:100%;left:12px;right:12px;
  background:var(--card-solid);border:1px solid var(--bd);border-radius:20px;
  box-shadow:var(--shadow-lg);margin-bottom:8px;z-index:10;
  max-height:400px;flex-direction:column;overflow:hidden;
}
#emojis.on{display:flex;animation:pop .2s}
.emoji-tabs{
  display:flex;gap:2px;padding:10px 10px 0;overflow-x:auto;border-bottom:1px solid var(--bd);
}
.emoji-tabs button{
  background:none;border:0;font-size:20px;padding:8px 12px;cursor:pointer;
  border-radius:10px 10px 0 0;transition:background .15s;flex-shrink:0;
}
.emoji-tabs button:hover{background:var(--other)}
.emoji-tabs button.on{background:var(--ac);color:#fff}
.emoji-search{
  padding:8px 12px;border-bottom:1px solid var(--bd);
}
.emoji-search input{
  padding:8px 12px;font-size:14px;border-radius:10px;background:var(--bg);
}
.emoji-grid{
  display:grid;grid-template-columns:repeat(8,1fr);gap:2px;padding:8px;
  overflow-y:auto;flex:1;min-height:0;
}
.emoji-grid span{
  font-size:22px;cursor:pointer;padding:6px;border-radius:10px;text-align:center;
  transition:all .1s;user-select:none;
}
.emoji-grid span:hover{background:var(--other);transform:scale(1.3)}
.emoji-empty{text-align:center;padding:30px;color:var(--mut);font-size:14px}

/* ============ AUTOCOMPLETE : ============ */
#emojiAuto{
  position:absolute;bottom:100%;left:12px;background:var(--card-solid);
  border:1px solid var(--bd);border-radius:14px;box-shadow:var(--shadow-lg);
  margin-bottom:8px;max-height:220px;overflow-y:auto;display:none;z-index:11;
  min-width:240px;
}
#emojiAuto.on{display:block;animation:pop .15s}
#emojiAuto .row{
  display:flex;gap:12px;align-items:center;padding:8px 14px;cursor:pointer;
  font-size:14px;transition:background .1s;
}
#emojiAuto .row:hover,#emojiAuto .row.sel{background:var(--other)}
#emojiAuto .row .em{font-size:22px}
#emojiAuto .row .nm{color:var(--mut)}

/* Avatar în lista de chat */
.av[style*="url"]{background-size:cover !important;background-position:center !important;color:transparent !important}
#meAv[style*="url"],.profile-avatar[style*="url"]{background-size:cover !important;background-position:center !important;color:transparent !important}
"""

# Inserează CSS-ul înainte de </style>
s=s.replace('</style>', profile_css + '</style>')

# === HTML PROFIL (înainte de </body>) ===
profile_html = """
<div id="profile">
  <div class="profile-header">
    <button class="profile-back" id="profBack">←</button>
    <div class="profile-avatar" id="profAvatar"></div>
    <h2 id="profName">...</h2>
    <div class="user-status" id="profStatus"></div>
  </div>
  <div class="profile-body">
    <div class="profile-stats">
      <div><b id="statMsgs">0</b><small>Mesaje</small></div>
      <div><b id="statGroups">0</b><small>Grupuri</small></div>
      <div><b id="statDays">0</b><small>Zile</small></div>
    </div>
    <div class="profile-section">
      <label>💬 Status</label>
      <input id="editStatus" placeholder="Ce faci acum? (max 60)" maxlength="60">
    </div>
    <div class="profile-section">
      <label>📝 Despre mine</label>
      <textarea id="editBio" placeholder="Scrie ceva despre tine..." maxlength="300" rows="3" style="resize:vertical"></textarea>
    </div>
    <button class="btn profile-save" id="saveProf">💾 Salvează</button>
  </div>
</div>
<input type="file" id="avatarInput" accept="image/*" hidden>
<div id="emojiAuto"></div>
"""

s=s.replace('</body>', profile_html + '\n</body>')

# Înlocuiește vechiul picker de emoji cu cel nou (dacă există)
import re

# Elimină vechiul div #emojis
s=re.sub(r'<div id="emojis"></div>', '<div id="emojis"><div class="emoji-tabs" id="emojiTabs"></div><div class="emoji-search"><input id="emojiSearch" placeholder="🔍 Caută emoji..."></div><div class="emoji-grid" id="emojiGrid"></div></div>', s)

open(f,'w').write(s)
print('✅ CSS + HTML profil adăugate')
PYEOF

# ============ PATCH 2: JavaScript pentru profil + emoji avansat ============
python3 <<'PYEOF'
f='html/index.html'
s=open(f).read()

# Șterge vechiul cod EMOJI (din v5)
old_emoji = s[s.find('// ============ EMOJI ============'):s.find('// ============ UPLOAD ============')]
new_emoji_js = """// ============ EMOJI AVANSAT ============
const EMOJI_DATA = {
  smileys:[['😀','grinning'],['😃','smiley'],['😄','smile'],['😁','grin'],['😆','laughing'],['😅','sweat_smile'],['🤣','rofl'],['😂','joy'],['🙂','slightly_smiling'],['🙃','upside_down'],['😉','wink'],['😊','blush'],['😇','innocent'],['🥰','smiling_hearts'],['😍','heart_eyes'],['🤩','star_struck'],['😘','kissing_heart'],['😗','kissing'],['😚','kissing_closed_eyes'],['😙','kissing_smiling'],['😋','yum'],['😛','stuck_tongue'],['😜','wink_tongue'],['🤪','zany'],['😝','squint_tongue'],['🤑','money_mouth'],['🤗','hugs'],['🤭','hand_over_mouth'],['🤫','shush'],['🤔','thinking'],['🤐','zipper_mouth'],['🤨','raised_eyebrow'],['😐','neutral'],['😑','expressionless'],['😶','no_mouth'],['😏','smirk'],['😒','unamused'],['🙄','roll_eyes'],['😬','grimacing'],['🤥','lying'],['😌','relieved'],['😔','pensive'],['😪','sleepy'],['🤤','drooling'],['😴','sleeping'],['😷','mask'],['🤒','thermometer'],['🤕','bandage'],['🤢','nauseated'],['🤮','vomiting'],['🥵','hot'],['🥶','cold'],['😵','dizzy'],['🤯','exploding_head'],['🤠','cowboy'],['🥳','partying'],['😎','sunglasses'],['🤓','nerd'],['🧐','monocle'],['😕','confused'],['😟','worried'],['🙁','slightly_frowning'],['😮','open_mouth'],['😯','hushed'],['😲','astonished'],['😳','flushed'],['🥺','pleading'],['😦','frowning'],['😧','anguished'],['😨','fearful'],['😰','cold_sweat'],['😥','disappointed_relieved'],['😢','cry'],['😭','sob'],['😱','scream'],['😖','confounded'],['😣','persevere'],['😞','disappointed'],['😓','sweat'],['😩','weary'],['😫','tired'],['🥱','yawn'],['😤','triumph'],['😡','rage'],['😠','angry'],['🤬','cursing'],['😈','smiling_imp'],['👿','imp'],['💀','skull'],['💩','poop'],['👻','ghost'],['👽','alien'],['🤖','robot'],['😺','smiley_cat']],
  gestures:[['👍','thumbsup'],['👎','thumbsdown'],['👏','clap'],['🙌','raised_hands'],['🤝','handshake'],['🙏','pray'],['✌️','victory'],['🤞','crossed_fingers'],['🤟','love_you'],['🤘','metal'],['👌','ok_hand'],['👈','point_left'],['👉','point_right'],['👆','point_up'],['👇','point_down'],['✋','raised_hand'],['🤚','raised_back_hand'],['🖐️','hand_splayed'],['🖖','vulcan'],['☝️','point_up_2'],['👋','wave'],['💪','muscle'],['🦾','mech_arm'],['🖕','middle_finger'],['✊','fist'],['👊','punch'],['🤛','left_fist'],['🤜','right_fist'],['👐','open_hands'],['🤲','palms_up'],['🙋','raising_hand']],
  hearts:[['❤️','heart'],['🧡','orange_heart'],['💛','yellow_heart'],['💚','green_heart'],['💙','blue_heart'],['💜','purple_heart'],['🖤','black_heart'],['🤍','white_heart'],['🤎','brown_heart'],['💔','broken_heart'],['❣️','heart_exclamation'],['💕','two_hearts'],['💞','revolving_hearts'],['💓','heartbeat'],['💗','heartpulse'],['💖','sparkling_heart'],['💘','cupid'],['💝','gift_heart'],['💟','heart_decoration'],['♥️','heart_suit'],['💋','kiss'],['💌','love_letter'],['😻','heart_eyes_cat'],['💐','bouquet'],['🌹','rose'],['🌷','tulip'],['🌸','cherry_blossom'],['💍','ring']],
  animals:[['🐶','dog'],['🐱','cat'],['🐭','mouse'],['🐹','hamster'],['🐰','rabbit'],['🦊','fox'],['🐻','bear'],['🐼','panda'],['🐨','koala'],['🐯','tiger'],['🦁','lion'],['🐮','cow'],['🐷','pig'],['🐸','frog'],['🐵','monkey'],['🙈','see_no_evil'],['🙉','hear_no_evil'],['🙊','speak_no_evil'],['🐔','chicken'],['🐧','penguin'],['🐦','bird'],['🐤','baby_chick'],['🦆','duck'],['🦅','eagle'],['🦉','owl'],['🦇','bat'],['🐺','wolf'],['🐗','boar'],['🐴','horse'],['🦄','unicorn'],['🐝','bee'],['🐛','bug'],['🦋','butterfly'],['🐌','snail'],['🐞','ladybug'],['🐜','ant'],['🦗','cricket'],['🕷️','spider'],['🐢','turtle'],['🐍','snake'],['🦎','lizard'],['🦂','scorpion'],['🦀','crab'],['🐙','octopus'],['🦑','squid'],['🐠','tropical_fish'],['🐟','fish'],['🐡','blowfish'],['🐬','dolphin'],['🐳','whale'],['🦈','shark'],['🐊','crocodile'],['🐅','tiger2'],['🐆','leopard'],['🦓','zebra'],['🦍','gorilla'],['🐘','elephant'],['🦏','rhino'],['🐪','camel'],['🐫','dromedary'],['🦒','giraffe'],['🐃','water_buffalo'],['🐄','cow2'],['🐎','racehorse'],['🐖','pig2'],['🐏','ram'],['🐑','sheep'],['🐐','goat'],['🦌','deer']],
  food:[['🍎','apple'],['🍐','pear'],['🍊','orange'],['🍋','lemon'],['🍌','banana'],['🍉','watermelon'],['🍇','grapes'],['🍓','strawberry'],['🍈','melon'],['🍒','cherries'],['🍑','peach'],['🥭','mango'],['🍍','pineapple'],['🥥','coconut'],['🥝','kiwi'],['🍅','tomato'],['🍆','eggplant'],['🥑','avocado'],['🥦','broccoli'],['🥬','leafy_green'],['🥒','cucumber'],['🌶️','hot_pepper'],['🌽','corn'],['🥕','carrot'],['🧄','garlic'],['🧅','onion'],['🥔','potato'],['🍠','sweet_potato'],['🥐','croissant'],['🥯','bagel'],['🍞','bread'],['🥖','baguette'],['🧀','cheese'],['🥚','egg'],['🍳','fried_egg'],['🥞','pancakes'],['🧇','waffle'],['🥓','bacon'],['🍔','hamburger'],['🍟','fries'],['🍕','pizza'],['🌭','hotdog'],['🥪','sandwich'],['🌮','taco'],['🌯','burrito'],['🥙','stuffed_flatbread'],['🧆','falafel'],['🥘','shallow_pan'],['🍝','spaghetti'],['🍜','ramen'],['🍲','stew'],['🍛','curry'],['🍣','sushi'],['🍱','bento'],['🥟','dumpling'],['🍤','fried_shrimp'],['🍙','rice_ball'],['🍚','rice'],['🍘','rice_cracker'],['🍥','fish_cake'],['🥠','fortune_cookie'],['🍢','oden'],['🍡','dango'],['🍧','shaved_ice'],['🍨','ice_cream'],['🍦','icecream'],['🥧','pie'],['🧁','cupcake'],['🍰','cake'],['🎂','birthday'],['🍮','custard'],['🍭','lollipop'],['🍬','candy'],['🍫','chocolate'],['🍿','popcorn'],['🍩','doughnut'],['🍪','cookie'],['☕','coffee'],['🍵','tea'],['🧃','juice_box'],['🥤','cup_straw'],['🍶','sake'],['🍺','beer'],['🍻','beers'],['🥂','clinking_glasses'],['🍷','wine'],['🥃','tumbler_glass'],['🍸','cocktail'],['🍹','tropical_drink'],['🧉','mate'],['🍾','champagne']],
  activities:[['⚽','soccer'],['🏀','basketball'],['🏈','football'],['⚾','baseball'],['🥎','softball'],['🎾','tennis'],['🏐','volleyball'],['🏉','rugby'],['🥏','frisbee'],['🎱','8ball'],['🪀','yo_yo'],['🏓','ping_pong'],['🏸','badminton'],['🏒','ice_hockey'],['🏑','field_hockey'],['🥍','lacrosse'],['🏏','cricket_game'],['🥅','goal'],['⛳','golf'],['🏹','bow_and_arrow'],['🎣','fishing'],['🥊','boxing_glove'],['🥋','martial_arts'],['🎽','running_shirt'],['🛹','skateboard'],['🛼','roller_skate'],['🛷','sled'],['⛸️','ice_skate'],['🥌','curling_stone'],['🎿','ski'],['⛷️','skier'],['🏂','snowboarder'],['🪂','parachute'],['🏋️','weight_lifter'],['🤼','wrestlers'],['🤸','cartwheel'],['⛹️','basketball_player'],['🤺','fencer'],['🤾','handball'],['🏌️','golfer'],['🏇','horse_racing'],['🧘','yogi'],['🏄','surfer'],['🏊','swimmer'],['🤽','water_polo'],['🚣','rowboat'],['🧗','climber'],['🚵','mountain_bicyclist'],['🚴','bicyclist'],['🏆','trophy'],['🥇','first_place'],['🥈','second_place'],['🥉','third_place'],['🏅','medal'],['🎖️','military_medal'],['🎗️','reminder_ribbon'],['🎫','ticket'],['🎟️','tickets'],['🎪','circus_tent'],['🎭','performing_arts'],['🎨','art'],['🎬','clapper'],['🎤','microphone'],['🎧','headphones'],['🎼','musical_score'],['🎹','musical_keyboard'],['🥁','drum'],['🎷','saxophone'],['🎺','trumpet'],['🎸','guitar'],['🪕','banjo'],['🎻','violin'],['🎲','game_die'],['♟️','chess_pawn'],['🎯','dart'],['🎳','bowling'],['🎮','video_game'],['🎰','slot_machine'],['🧩','puzzle']],
  objects:[['⌚','watch'],['📱','iphone'],['💻','computer'],['⌨️','keyboard'],['🖥️','desktop'],['🖨️','printer'],['🖱️','mouse_three_button'],['🖲️','trackball'],['🕹️','joystick'],['🗜️','compression'],['💽','minidisc'],['💾','floppy_disk'],['💿','cd'],['📀','dvd'],['📼','vhs'],['📷','camera'],['📸','camera_flash'],['📹','video_camera'],['🎥','movie_camera'],['📽️','film_projector'],['🎞️','film_frames'],['📞','telephone_receiver'],['☎️','phone'],['📟','pager'],['📠','fax'],['📺','tv'],['📻','radio'],['🎙️','studio_microphone'],['🎚️','level_slider'],['🎛️','control_knobs'],['🧭','compass'],['⏱️','stopwatch'],['⏲️','timer_clock'],['⏰','alarm_clock'],['🕰️','mantelpiece_clock'],['⌛','hourglass'],['⏳','hourglass_flowing'],['📡','satellite'],['🔋','battery'],['🔌','electric_plug'],['💡','bulb'],['🔦','flashlight'],['🕯️','candle'],['🪔','diya_lamp'],['🧯','fire_extinguisher'],['🛢️','oil_drum'],['💸','money_with_wings'],['💵','dollar'],['💴','yen'],['💶','euro'],['💷','pound'],['💰','moneybag'],['💳','credit_card'],['💎','gem'],['⚖️','balance_scale'],['🧰','toolbox'],['🔧','wrench'],['🔨','hammer'],['⚒️','hammer_and_pick'],['🛠️','hammer_and_wrench'],['⛏️','pick'],['🔩','nut_and_bolt'],['⚙️','gear'],['🧱','brick'],['⛓️','chains'],['🧲','magnet'],['🔫','gun'],['💣','bomb'],['🧨','firecracker'],['🪓','axe'],['🔪','knife'],['🗡️','dagger'],['⚔️','crossed_swords'],['🛡️','shield'],['🚬','smoking'],['⚰️','coffin'],['🪦','headstone'],['⚱️','funeral_urn'],['🏺','amphora'],['🔮','crystal_ball'],['📿','prayer_beads'],['🧿','nazar_amulet'],['💈','barber'],['⚗️','alembic'],['🔭','telescope'],['🔬','microscope'],['🕳️','hole'],['🩹','adhesive_bandage'],['🩺','stethoscope'],['💊','pill'],['💉','syringe'],['🩸','drop_of_blood'],['🧬','dna'],['🦠','microbe'],['🧫','petri_dish'],['🧪','test_tube'],['🌡️','thermometer']],
  symbols:[['❤️','heart_red'],['💯','100'],['✅','check'],['❌','x'],['⚡','zap'],['💥','boom'],['🔥','fire'],['⭐','star'],['🌟','star2'],['✨','sparkles'],['⚡','zap2'],['🎉','tada'],['🎊','confetti'],['🎁','gift'],['🎈','balloon'],['🎂','cake_sym'],['🍾','champagne_sym'],['🚀','rocket'],['🎯','dart_sym'],['🏆','trophy_sym'],['🥇','gold'],['💎','diamond'],['👑','crown'],['💰','money_sym'],['💵','dollar_sym'],['⚙️','gear_sym'],['🔔','bell'],['🔕','no_bell'],['📢','loudspeaker'],['📣','mega'],['💬','speech_balloon'],['💭','thought_balloon'],['🗯️','anger_balloon'],['♨️','hot_springs'],['💤','zzz'],['♠️','spades'],['♥️','hearts_sym'],['♦️','diamonds'],['♣️','clubs'],['🃏','joker'],['🎴','flower_cards'],['🀄','mahjong'],['🕐','clock1'],['⏰','alarm'],['⌚','watch_sym'],['🔒','lock'],['🔓','unlock'],['🔐','closed_lock_key'],['🔑','key'],['🗝️','old_key'],['🔨','hammer_sym'],['⚔️','swords_sym'],['🛡️','shield_sym'],['⚖️','scale'],['🔗','link'],['📎','paperclip'],['📍','round_pushpin'],['📌','pushpin'],['✂️','scissors'],['📏','ruler'],['📐','triangular_ruler'],['🔍','mag'],['🔎','mag_right'],['🔏','lock_with_ink'],['🔐','key_sym'],['♻️','recycle'],['⚠️','warning'],['🚫','no_entry'],['⛔','no_entry_sign'],['📵','no_mobile'],['🔞','underage'],['☢️','radioactive'],['☣️','biohazard'],['⬆️','arrow_up'],['⬇️','arrow_down'],['⬅️','arrow_left'],['➡️','arrow_right'],['↗️','arrow_upper_right'],['↘️','arrow_lower_right'],['↙️','arrow_lower_left'],['↖️','arrow_upper_left'],['↕️','arrow_up_down'],['↔️','left_right_arrow'],['🔄','arrows_counterclockwise'],['🔃','arrows_clockwise'],['🔙','back'],['🔚','end'],['🔛','on'],['🔜','soon'],['🔝','top']]
};

const CATEGORY_ICONS = {smileys:'😀',gestures:'👍',hearts:'❤️',food:'🍕',animals:'🐶',activities:'⚽',objects:'💡',symbols:'⭐'};
let currentCat = 'smileys';
let allEmojis = [];

// Build allEmojis flat list for search
Object.entries(EMOJI_DATA).forEach(([cat,items])=>{
  items.forEach(([em,nm])=>allEmojis.push({em,nm,cat}));
});

function renderEmojiTabs(){
  const tabs=document.querySelector('#emojiTabs');
  tabs.innerHTML='';
  Object.entries(CATEGORY_ICONS).forEach(([cat,icon])=>{
    const b=document.createElement('button');
    b.textContent=icon;b.dataset.cat=cat;
    if(cat===currentCat)b.classList.add('on');
    b.onclick=()=>{currentCat=cat;renderEmojiTabs();renderEmojiGrid()};
    tabs.append(b);
  });
}
function renderEmojiGrid(search=''){
  const g=document.querySelector('#emojiGrid');
  g.innerHTML='';
  let items;
  if(search){
    const q=search.toLowerCase();
    items=allEmojis.filter(e=>e.nm.includes(q)||e.em===q);
  } else {
    items=(EMOJI_DATA[currentCat]||[]).map(([em,nm])=>({em,nm,cat:currentCat}));
  }
  if(!items.length){
    g.innerHTML='<div class="emoji-empty">Niciun emoji găsit</div>';
    return;
  }
  items.forEach(({em,nm})=>{
    const s=document.createElement('span');
    s.textContent=em;s.title=':'+nm+':';
    s.onclick=()=>{
      const t=document.querySelector('#t');
      t.value+=t.value?' '+em:em;
      t.focus();t.dispatchEvent(new Event('input'));
    };
    g.append(s);
  });
}
// init
renderEmojiTabs();
renderEmojiGrid();

document.querySelector('#emojiSearch').oninput=e=>renderEmojiGrid(e.target.value);
document.querySelector('#emojiSearch').onkeydown=e=>{
  if(e.key==='Escape'){e.target.value='';renderEmojiGrid()}
};
document.querySelector('#emoBtn').onclick=e=>{
  e.stopPropagation();
  const p=document.querySelector('#emojis');
  p.classList.toggle('on');
  if(p.classList.contains('on'))document.querySelector('#emojiSearch').focus();
};
document.addEventListener('click',e=>{
  if(!e.target.closest('#emojis')&&e.target.id!=='emoBtn')
    document.querySelector('#emojis').classList.remove('on');
});

// ============ AUTOCOMPLETE : ============
const ta=document.querySelector('#t');
const autoBox=document.querySelector('#emojiAuto');
let autoIdx=0;
let autoMatches=[];

function getAutoQuery(){
  const val=ta.value;
  const pos=ta.selectionStart;
  const before=val.slice(0,pos);
  const m=before.match(/:([a-z0-9_+-]{1,20})$/i);
  return m?m[1]:null;
}
function showAuto(q){
  autoMatches=allEmojis.filter(e=>e.nm.includes(q.toLowerCase())).slice(0,8);
  if(!autoMatches.length){autoBox.classList.remove('on');return}
  autoIdx=0;
  autoBox.innerHTML=autoMatches.map((m,i)=>`<div class="row${i===0?' sel':''}" data-i="${i}"><span class="em">${m.em}</span><span class="nm">:${m.nm}:</span></div>`).join('');
  autoBox.classList.add('on');
  autoBox.querySelectorAll('.row').forEach(r=>{
    r.onclick=()=>insertAuto(+r.dataset.i);
  });
}
function insertAuto(i){
  const m=autoMatches[i];if(!m)return;
  const val=ta.value,pos=ta.selectionStart;
  const before=val.slice(0,pos);
  const match=before.match(/:([a-z0-9_+-]{1,20})$/i);
  if(!match)return;
  const start=pos-match[0].length;
  ta.value=val.slice(0,start)+m.em+val.slice(pos);
  ta.selectionStart=ta.selectionEnd=start+m.em.length;
  ta.focus();
  autoBox.classList.remove('on');
}
ta.addEventListener('input',()=>{
  const q=getAutoQuery();
  if(q)showAuto(q);else autoBox.classList.remove('on');
});
ta.addEventListener('keydown',e=>{
  if(!autoBox.classList.contains('on'))return;
  if(e.key==='ArrowDown'){e.preventDefault();autoIdx=(autoIdx+1)%autoMatches.length;updateAutoSel()}
  else if(e.key==='ArrowUp'){e.preventDefault();autoIdx=(autoIdx-1+autoMatches.length)%autoMatches.length;updateAutoSel()}
  else if(e.key==='Tab'||(e.key==='Enter'&&!e.shiftKey)){e.preventDefault();insertAuto(autoIdx)}
  else if(e.key==='Escape')autoBox.classList.remove('on');
});
function updateAutoSel(){
  autoBox.querySelectorAll('.row').forEach((r,i)=>r.classList.toggle('sel',i===autoIdx));
}
"""

s=s.replace(old_emoji, new_emoji_js)

# ============ PROFILE JS ============
profile_js = """
// ============ PROFILE ============
async function openProfile(){
  try{
    const d=await api('profile_get');
    document.querySelector('#profName').textContent=d.username;
    document.querySelector('#profStatus').textContent=d.status||'Fără status';
    const av=document.querySelector('#profAvatar');
    if(d.avatar){
      av.style.backgroundImage='url('+d.avatar+')';
      av.textContent='';
    } else {
      av.style.backgroundImage='';
      av.textContent=d.username[0].toUpperCase();
    }
    document.querySelector('#statMsgs').textContent=d.messages||0;
    document.querySelector('#statGroups').textContent=d.groups||0;
    document.querySelector('#statDays').textContent=d.days||1;
    document.querySelector('#editStatus').value=d.status||'';
    document.querySelector('#editBio').value=d.bio||'';
    document.querySelector('#profile').classList.add('on');
  }catch(e){toast(e,'err')}
}
document.querySelector('#meAv').onclick=openProfile;
document.querySelector('#profBack').onclick=()=>document.querySelector('#profile').classList.remove('on');
document.querySelector('#saveProf').onclick=async()=>{
  try{
    await api('profile_set',{
      status:document.querySelector('#editStatus').value,
      bio:document.querySelector('#editBio').value
    });
    toast('✅ Profil salvat','ok');
    document.querySelector('#profStatus').textContent=document.querySelector('#editStatus').value||'Fără status';
  }catch(e){toast(e,'err')}
};
// Avatar upload
document.querySelector('#profAvatar').onclick=()=>document.querySelector('#avatarInput').click();
document.querySelector('#avatarInput').onchange=async()=>{
  const f=document.querySelector('#avatarInput').files[0];if(!f)return;
  const fd=new FormData();fd.append('f',f);
  try{
    toast('Se încarcă...','info');
    const r=await fetch('api.php?a=profile_avatar',{method:'POST',headers:{'X-Requested-With':'fetch'},body:fd});
    const j=await r.json();if(!r.ok)throw j.error;
    document.querySelector('#profAvatar').style.backgroundImage='url('+j.url+')';
    document.querySelector('#profAvatar').textContent='';
    document.querySelector('#meAv').style.backgroundImage='url('+j.url+')';
    document.querySelector('#meAv').textContent='';
    toast('✅ Avatar actualizat','ok');
  }catch(e){toast(e,'err')}
  document.querySelector('#avatarInput').value='';
};
"""

# Inserează JS-ul de profil înainte de "enter().catch(auth);"
s=s.replace('enter().catch(auth);', profile_js + '\nenter().catch(auth);')

open(f,'w').write(s)
print('✅ JavaScript profil + emoji avansat adăugat')
PYEOF

# Restart
docker compose restart nginx php
docker compose ps

echo ""
echo "🎉 UPDATE v6 COMPLET!"
echo "Deschide: http://10.130.70.55 (Ctrl+Shift+R)"
