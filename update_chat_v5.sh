#!/bin/bash
# Chat v5 - UI modern aurora + glassmorphism + toate feature-urile v4 + toast/lightbox/date-separators
set -e
cd /home/admin/chatapp
cp html/index.html html/index.html.v4bak 2>/dev/null || true
cp html/api.php html/api.php.v4bak 2>/dev/null || true

# păstrează api.php v4 (deja funcțional)
# doar rescrie index.html cu UI nou

cat > html/index.html <<'EOF_HTML'
<!DOCTYPE html><html lang="ro"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1,viewport-fit=cover">
<meta name="theme-color" content="#6c5ce7">
<title>💬 Chat</title>
<style>
/* ============ VARIABILE ============ */
:root{
  --bg:#f0f2fa;--bg2:#e8ebf8;--card:rgba(255,255,255,.85);--card-solid:#fff;
  --tx:#14152a;--mut:#6b7094;--ac:#6c5ce7;--ac2:#a29bfe;--ac3:#fd79a8;
  --other:rgba(108,92,231,.08);--bd:rgba(108,92,231,.12);
  --me:linear-gradient(135deg,#6c5ce7 0%,#a29bfe 50%,#fd79a8 100%);
  --ok:#00b894;--warn:#fdcb6e;--err:#e74c3c;
  --shadow:0 4px 20px rgba(108,92,231,.08);
  --shadow-lg:0 12px 40px rgba(108,92,231,.15);
  --radius:16px;--radius-sm:10px;
}
[data-theme=dark]{
  --bg:#0a0b1a;--bg2:#0f1130;--card:rgba(20,21,48,.85);--card-solid:#141530;
  --tx:#eceefa;--mut:#8a8fb5;--other:rgba(108,92,231,.15);--bd:rgba(108,92,231,.25);
  --shadow:0 4px 20px rgba(0,0,0,.3);--shadow-lg:0 12px 40px rgba(0,0,0,.5);
}
*{box-sizing:border-box;margin:0;padding:0}
html,body{height:100%;overscroll-behavior:none}
body{
  font:15px/1.5 system-ui,-apple-system,'Segoe UI',sans-serif;
  background:var(--bg);color:var(--tx);
  transition:background .3s,color .3s;
  position:relative;overflow:hidden;
}
/* Aurora background */
body::before,body::after{
  content:'';position:fixed;border-radius:50%;filter:blur(80px);opacity:.4;z-index:-1;pointer-events:none;
  animation:aurora 20s ease-in-out infinite;
}
body::before{width:500px;height:500px;background:radial-gradient(circle,#6c5ce7,transparent 70%);top:-200px;left:-200px}
body::after{width:600px;height:600px;background:radial-gradient(circle,#fd79a8,transparent 70%);bottom:-300px;right:-200px;animation-delay:-10s}
@keyframes aurora{0%,100%{transform:translate(0,0) scale(1)}33%{transform:translate(100px,-50px) scale(1.1)}66%{transform:translate(-50px,100px) scale(.95)}}

button,input,textarea{font:inherit;color:inherit;font-family:inherit}
input,textarea{
  width:100%;padding:13px 16px;border:2px solid var(--bd);border-radius:var(--radius-sm);
  background:var(--card);backdrop-filter:blur(20px);-webkit-backdrop-filter:blur(20px);
  outline:none;transition:all .2s;color:var(--tx);
}
input:focus,textarea:focus{border-color:var(--ac);box-shadow:0 0 0 4px rgba(108,92,231,.15);background:var(--card-solid)}
.btn{
  background:var(--me);color:#fff;border:0;border-radius:var(--radius-sm);
  padding:13px 20px;cursor:pointer;font-weight:600;
  transition:transform .15s,box-shadow .2s,filter .2s;
  box-shadow:0 4px 12px rgba(108,92,231,.3);
  background-size:200% 200%;animation:gradient 4s ease infinite;
}
@keyframes gradient{0%,100%{background-position:0% 50%}50%{background-position:100% 50%}}
.btn:hover{transform:translateY(-1px);box-shadow:0 8px 20px rgba(108,92,231,.4);filter:brightness(1.05)}
.btn:active{transform:scale(.98)}
.ghost{background:none;border:0;cursor:pointer;color:var(--mut);padding:8px;border-radius:10px;transition:all .15s;font-size:18px;line-height:1}
.ghost:hover{background:var(--other);color:var(--tx);transform:scale(1.1)}

/* ============ AUTH ============ */
#auth{
  display:grid;max-width:380px;margin:8vh auto;padding:40px 32px;gap:16px;text-align:center;
  background:var(--card);backdrop-filter:blur(30px);-webkit-backdrop-filter:blur(30px);
  border-radius:24px;box-shadow:var(--shadow-lg);border:1px solid var(--bd);
  animation:fadeUp .5s ease;
}
@keyframes fadeUp{from{opacity:0;transform:translateY(20px)}to{opacity:1;transform:none}}
#auth h1{font-size:36px;font-weight:800;background:var(--me);-webkit-background-clip:text;-webkit-text-fill-color:transparent;background-clip:text;margin-bottom:8px}
#auth .logo{font-size:64px;line-height:1;animation:float 3s ease-in-out infinite}
@keyframes float{0%,100%{transform:translateY(0)}50%{transform:translateY(-8px)}}
#auth small{min-height:20px;font-size:13px}

/* ============ APP ============ */
#app{
  display:none;height:100%;max-width:1200px;margin:0 auto;
  background:var(--card);backdrop-filter:blur(30px);-webkit-backdrop-filter:blur(30px);
  box-shadow:var(--shadow-lg);
}
#app.on{display:flex;animation:fadeIn .3s}
@keyframes fadeIn{from{opacity:0}to{opacity:1}}
#side{width:360px;border-right:1px solid var(--bd);display:flex;flex-direction:column;min-width:0}
#main{flex:1;display:flex;flex-direction:column;min-width:0;background:var(--bg2)}
header{
  display:flex;align-items:center;gap:12px;padding:16px;padding-top:max(16px,env(safe-area-inset-top));
  border-bottom:1px solid var(--bd);font-weight:600;background:var(--card);
  backdrop-filter:blur(20px);-webkit-backdrop-filter:blur(20px);min-height:68px;
}
.sp{flex:1}

/* ============ ROOMS ============ */
#rooms{overflow:auto;flex:1;padding:8px}
#rooms::-webkit-scrollbar,#msgs::-webkit-scrollbar{width:8px}
#rooms::-webkit-scrollbar-thumb,#msgs::-webkit-scrollbar-thumb{background:var(--bd);border-radius:4px}
#rooms::-webkit-scrollbar-thumb:hover{background:var(--ac)}
.room{
  padding:12px;cursor:pointer;display:flex;gap:12px;align-items:center;
  border-radius:var(--radius);transition:all .2s;position:relative;margin-bottom:4px;
}
.room:hover{background:var(--other);transform:translateX(2px)}
.room.on{background:var(--other);box-shadow:inset 3px 0 0 var(--ac)}
.av{
  width:52px;height:52px;border-radius:50%;display:flex;align-items:center;justify-content:center;
  color:#fff;font-weight:700;font-size:20px;flex-shrink:0;position:relative;
  box-shadow:0 4px 12px rgba(0,0,0,.15);
}
.av.sm{width:38px;height:38px;font-size:15px;box-shadow:none}
.av.online::after{content:'';position:absolute;bottom:1px;right:1px;width:13px;height:13px;border-radius:50%;background:var(--ok);border:2px solid var(--card-solid)}
.room .info{flex:1;min-width:0}
.room b{display:block;font-size:15px;font-weight:600;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}
.room small{color:var(--mut);font-size:13px;white-space:nowrap;overflow:hidden;text-overflow:ellipsis;display:block;margin-top:2px}
.room .meta{text-align:right;flex-shrink:0;display:flex;flex-direction:column;align-items:flex-end;gap:4px}
.room .time{font-size:11px;color:var(--mut);font-weight:500}
.bd{background:var(--me);color:#fff;border-radius:11px;padding:2px 8px;font-size:11px;font-weight:700;min-width:22px;text-align:center;box-shadow:0 2px 6px rgba(108,92,231,.4);animation:pop .3s}
@keyframes pop{0%{transform:scale(0)}70%{transform:scale(1.15)}100%{transform:scale(1)}}

/* ============ MESSAGES ============ */
#msgs{flex:1;overflow:auto;padding:20px;display:flex;flex-direction:column;gap:6px;background:var(--bg2);scroll-behavior:smooth}
.date-sep{
  text-align:center;margin:16px 0 8px;position:relative;
}
.date-sep span{
  background:var(--card-solid);padding:6px 16px;border-radius:20px;font-size:12px;
  color:var(--mut);font-weight:600;box-shadow:var(--shadow);border:1px solid var(--bd);
}
.m{
  max-width:75%;padding:10px 14px 8px;border-radius:20px;
  background:var(--card-solid);word-wrap:break-word;white-space:pre-wrap;
  align-self:flex-start;position:relative;box-shadow:var(--shadow);
  animation:msgIn .25s ease-out;border:1px solid var(--bd);
}
@keyframes msgIn{from{opacity:0;transform:translateY(8px) scale(.96)}to{opacity:1;transform:none}}
.m.me{
  background:var(--me);color:#fff;align-self:flex-end;border-color:transparent;
  box-shadow:0 4px 16px rgba(108,92,231,.3);
}
.m .meta{display:flex;gap:6px;align-items:center;font-size:11px;margin-top:4px;justify-content:flex-end;opacity:.7;font-weight:500}
.m.me .meta{color:rgba(255,255,255,.9);opacity:.9}
.m .name{font-size:12px;font-weight:700;margin-bottom:3px}
.m .reply{
  background:rgba(108,92,231,.08);border-left:3px solid var(--ac);
  padding:6px 10px;border-radius:8px;font-size:12px;margin-bottom:6px;opacity:.9;
}
.m.me .reply{background:rgba(255,255,255,.2);border-left-color:#fff}
.m .acts{
  position:absolute;top:-12px;right:8px;display:none;gap:2px;
  background:var(--card-solid);border:1px solid var(--bd);border-radius:12px;
  padding:4px;box-shadow:var(--shadow-lg);z-index:5;
  backdrop-filter:blur(20px);-webkit-backdrop-filter:blur(20px);
}
.m:hover .acts{display:flex;animation:pop .15s}
.m .acts button{
  background:none;border:0;cursor:pointer;padding:6px;border-radius:8px;
  color:var(--mut);font-size:15px;line-height:1;transition:all .15s;
}
.m .acts button:hover{background:var(--other);color:var(--tx);transform:scale(1.15)}
.m.del{opacity:.5;font-style:italic}
.m img,.m video{max-width:100%;border-radius:12px;margin-top:6px;display:block;cursor:pointer;transition:transform .2s}
.m img:hover{transform:scale(1.02)}
.m audio{width:100%;margin-top:6px}
.m .file{
  display:flex;align-items:center;gap:10px;padding:10px 12px;
  background:rgba(108,92,231,.08);border-radius:12px;margin-top:6px;
  text-decoration:none;color:inherit;transition:background .15s;
}
.m .file:hover{background:rgba(108,92,231,.15)}
.m .pinned{
  position:absolute;top:-8px;left:-8px;background:var(--warn);color:#000;
  width:22px;height:22px;border-radius:50%;display:flex;align-items:center;justify-content:center;
  font-size:12px;box-shadow:0 2px 8px rgba(253,203,110,.5);
}
.reacts{display:flex;gap:4px;flex-wrap:wrap;margin-top:6px}
.reacts span{
  background:rgba(0,0,0,.06);padding:2px 8px;border-radius:12px;
  font-size:14px;cursor:pointer;user-select:none;transition:all .15s;
}
.reacts span:hover{transform:scale(1.1)}
.reacts span.mine{background:rgba(108,92,231,.25);outline:1.5px solid var(--ac)}
.m.me .reacts span{background:rgba(255,255,255,.2)}

/* Typing indicator */
.typing-dots{display:inline-flex;gap:3px;align-items:center;padding:8px 14px;background:var(--card-solid);border-radius:20px;align-self:flex-start;border:1px solid var(--bd)}
.typing-dots span{width:7px;height:7px;border-radius:50%;background:var(--mut);animation:bounce 1.4s infinite}
.typing-dots span:nth-child(2){animation-delay:.2s}
.typing-dots span:nth-child(3){animation-delay:.4s}
@keyframes bounce{0%,60%,100%{transform:translateY(0);opacity:.5}30%{transform:translateY(-6px);opacity:1}}

/* ============ FORM ============ */
#f{display:flex;gap:8px;padding:12px;padding-bottom:max(12px,env(safe-area-inset-bottom));border-top:1px solid var(--bd);background:var(--card);align-items:flex-end;position:relative;backdrop-filter:blur(20px);-webkit-backdrop-filter:blur(20px)}
#t{resize:none;max-height:120px;min-height:46px;padding:12px 16px;border-radius:24px;font-family:inherit;font-size:15px}
#f .ico{
  background:none;border:0;cursor:pointer;font-size:22px;padding:8px;border-radius:50%;
  color:var(--mut);transition:all .2s;flex-shrink:0;
}
#f .ico:hover{background:var(--other);color:var(--tx);transform:scale(1.15)}
#f .ico.rec{color:var(--err);animation:pulse 1s infinite;background:rgba(231,76,60,.15)}
@keyframes pulse{50%{transform:scale(1.15);opacity:.7}}
#f .send{
  width:46px;height:46px;border-radius:50%;padding:0;display:flex;align-items:center;justify-content:center;
  flex-shrink:0;font-size:20px;
}

/* ============ EMPTY ============ */
#empty{margin:auto;color:var(--mut);text-align:center;padding:40px}
#empty .big{font-size:80px;margin-bottom:20px;animation:float 3s ease-in-out infinite}
#empty h3{font-size:20px;color:var(--tx);margin-bottom:8px;font-weight:600}

/* ============ DIALOG ============ */
dialog{
  border:0;border-radius:24px;padding:24px;width:min(440px,92vw);
  background:var(--card-solid);color:var(--tx);box-shadow:var(--shadow-lg);
  animation:dlgIn .25s cubic-bezier(.3,1.4,.6,1);
}
@keyframes dlgIn{from{opacity:0;transform:scale(.9)}to{opacity:1;transform:scale(1)}}
dialog::backdrop{background:rgba(0,0,0,.5);backdrop-filter:blur(8px);-webkit-backdrop-filter:blur(8px);animation:fadeIn .2s}
dialog h3{margin-bottom:16px;font-size:20px;font-weight:700}
.u{
  padding:10px 12px;border-radius:12px;cursor:pointer;display:flex;align-items:center;
  gap:12px;transition:all .15s;
}
.u:hover{background:var(--other);transform:translateX(2px)}
.u.sel{background:var(--other);font-weight:600}
.u.sel::after{content:'✓';margin-left:auto;color:var(--ac);font-weight:700;font-size:18px}

/* ============ TOOLS ============ */
.tools{display:flex;gap:8px;padding:12px 16px}
.tools .btn{flex:1;padding:11px;font-size:14px}
.back{display:none}
@media(max-width:760px){
  #side{width:100%}#main{display:none}
  #app.open #side{display:none}#app.open #main{display:flex}
  .back{display:inline}
}

/* ============ EMOJI PICKER ============ */
#emojis{
  position:absolute;bottom:100%;left:12px;background:var(--card-solid);
  border:1px solid var(--bd);border-radius:20px;padding:14px;
  display:none;grid-template-columns:repeat(8,1fr);gap:4px;
  box-shadow:var(--shadow-lg);max-height:240px;overflow:auto;
  width:min(360px,90vw);margin-bottom:8px;z-index:10;
  animation:pop .2s;
}
#emojis.on{display:grid}
#emojis span{font-size:24px;cursor:pointer;padding:6px;border-radius:10px;text-align:center;transition:all .15s}
#emojis span:hover{background:var(--other);transform:scale(1.25)}

/* ============ REPLY BAR ============ */
.reply-bar{
  display:none;padding:10px 16px;background:var(--other);
  border-top:1px solid var(--bd);align-items:center;gap:10px;font-size:13px;
  animation:slideDown .2s;
}
@keyframes slideDown{from{transform:translateY(-100%);opacity:0}to{transform:none;opacity:1}}
.reply-bar.on{display:flex}
.reply-bar .txt{flex:1;white-space:nowrap;overflow:hidden;text-overflow:ellipsis;color:var(--mut)}

/* ============ SEARCH ============ */
#search{display:none;padding:8px 16px;border-bottom:1px solid var(--bd)}
#search.on{display:block;animation:slideDown .2s}

/* ============ LIGHTBOX ============ */
#lightbox{
  position:fixed;inset:0;background:rgba(0,0,0,.92);z-index:1000;
  display:none;align-items:center;justify-content:center;cursor:zoom-out;
  animation:fadeIn .2s;
}
#lightbox.on{display:flex}
#lightbox img{max-width:95vw;max-height:95vh;border-radius:8px;box-shadow:0 20px 60px rgba(0,0,0,.5);animation:pop .25s}

/* ============ TOAST ============ */
#toasts{position:fixed;top:20px;right:20px;z-index:2000;display:flex;flex-direction:column;gap:10px;pointer-events:none}
.toast{
  background:var(--card-solid);border:1px solid var(--bd);border-radius:14px;
  padding:14px 18px;box-shadow:var(--shadow-lg);min-width:240px;
  animation:toastIn .3s cubic-bezier(.3,1.4,.6,1);pointer-events:auto;
  border-left:4px solid var(--ac);font-weight:500;
}
.toast.ok{border-left-color:var(--ok)}
.toast.err{border-left-color:var(--err)}
.toast.warn{border-left-color:var(--warn)}
@keyframes toastIn{from{opacity:0;transform:translateX(100%)}to{opacity:1;transform:none}}
.toast.out{animation:toastOut .3s forwards}
@keyframes toastOut{to{opacity:0;transform:translateX(100%)}}

/* ============ SCROLL TO BOTTOM ============ */
#scrollBtn{
  position:absolute;bottom:90px;right:20px;width:44px;height:44px;border-radius:50%;
  background:var(--me);color:#fff;border:0;cursor:pointer;font-size:20px;
  box-shadow:var(--shadow-lg);display:none;align-items:center;justify-content:center;
  transition:all .2s;z-index:5;animation:pop .2s;
}
#scrollBtn.on{display:flex}
#scrollBtn:hover{transform:scale(1.1) translateY(-2px)}

/* ============ PINNED BAR ============ */
#pinnedBar{
  display:none;background:linear-gradient(135deg,rgba(253,203,110,.15),rgba(253,203,110,.05));
  border-bottom:1px solid var(--warn);padding:8px 16px;font-size:13px;
}
#pinnedBar.on{display:block}

@media(max-width:760px){
  #toasts{top:auto;bottom:20px;right:10px;left:10px}
  .toast{min-width:0}
}
</style></head><body>

<div id="lightbox" onclick="this.classList.remove('on')"><img id="lbimg"></div>
<div id="toasts"></div>

<div id="auth">
<div class="logo">💬</div>
<h1>Chat</h1>
<input id="u" type="text" placeholder="Username" name="username" autocomplete="on" autocapitalize="off" spellcheck="true">
<input id="p" type="password" placeholder="Parolă" name="password" autocomplete="current-password">
<button class="btn" id="login">Intră în cont</button>
<button class="ghost" id="reg">Nu ai cont? Creează unul</button>
<small id="err" style="color:var(--err)"></small>
</div>

<div id="app">
  <div id="side">
    <header>
      <div class="av sm" id="meAv" style="background:var(--me)"></div>
      <span id="me">...</span>
      <span class="sp"></span>
      <button class="ghost" id="theme" title="Temă">🌙</button>
      <button class="ghost" id="out" title="Ieși">⎋</button>
    </header>
    <div class="tools" style="padding:12px 16px 0">
      <input id="sq" placeholder="🔍 Caută conversații..." style="padding:10px 14px">
    </div>
    <div class="tools">
      <button class="btn" id="nd">＋ Chat</button>
      <button class="btn" id="ng">＋ Grup</button>
    </div>
    <div id="rooms"></div>
  </div>
  <div id="main">
    <header>
      <button class="ghost back" id="bk">←</button>
      <div class="av sm" id="tAv" style="background:var(--ac)"></div>
      <span style="min-width:0">
        <span id="title" style="display:block;white-space:nowrap;overflow:hidden;text-overflow:ellipsis">Alege o conversație</span>
        <small id="sub" style="display:block;font-weight:400;color:var(--mut);font-size:12px"></small>
      </span>
      <span class="sp"></span>
      <button class="ghost" id="srchBtn" title="Caută în mesaje">🔍</button>
      <button class="ghost" id="expBtn" title="Export">📤</button>
      <button class="ghost" id="info" title="Membri" hidden>👥</button>
      <button class="ghost" id="add" title="Adaugă" hidden>＋</button>
    </header>
    <div id="pinnedBar"></div>
    <div id="msgs" style="position:relative"><div id="empty"><div class="big">💬</div><h3>Bine ai venit!</h3>Alege o conversație<br><small>sau începe una nouă</small></div></div>
    <button id="scrollBtn" title="Jos">↓</button>
    <div class="reply-bar" id="rbar"><span>↩ Răspuns:</span><span class="txt" id="rtxt"></span><button class="ghost" id="rcancel">✕</button></div>
    <div id="emojis"></div>
    <form id="f" hidden>
      <button type="button" class="ico" id="fileBtn" title="Fișier">📎</button>
      <button type="button" class="ico" id="emoBtn" title="Emoji">😊</button>
      <button type="button" class="ico" id="voiceBtn" title="Voice">🎙️</button>
      <textarea id="t" placeholder="Scrie un mesaj..." autocomplete="off" rows="1"></textarea>
      <button class="btn send" type="submit">➤</button>
    </form>
    <input type="file" id="fileInput" hidden>
  </div>
</div>

<dialog id="dlg"><h3 id="dt"></h3>
<input id="gn" placeholder="Nume grup" style="display:none">
<input id="q" placeholder="🔍 Caută utilizator...">
<div id="ul" style="max-height:260px;overflow:auto;margin:12px 0"></div>
<div style="display:flex;gap:8px"><button class="ghost" id="cx">Anulează</button><span class="sp"></span><button class="btn" id="ok">Creează</button></div>
</dialog>

<dialog id="infoDlg"><h3>👥 Membri</h3><div id="mlist" style="max-height:300px;overflow:auto"></div>
<div style="display:flex;margin-top:16px"><span class="sp"></span><button class="btn" onclick="infoDlg.close()">Închide</button></div></dialog>

<dialog id="searchDlg"><h3>🔍 Caută în mesaje</h3>
<input id="qmsg" placeholder="Scrie minim 2 caractere...">
<div id="sres" style="max-height:300px;overflow:auto;margin-top:12px"></div>
<div style="display:flex;margin-top:16px"><span class="sp"></span><button class="ghost" onclick="searchDlg.close()">Închide</button></div></dialog>

<script>
const $=s=>document.querySelector(s);
let prevU=-1,ac,me,room,last=0,timer,mode,sel=new Set(),n=0,busy=false,replyTo=null,editing=null,mediaRec=null,recChunks=[],recTimer=null,lastDate='';

// ============ FIX TASTATURĂ ============
document.addEventListener('keydown',function(e){
  const t=document.activeElement;
  if(!t||(t.tagName!=='INPUT'&&t.tagName!=='TEXTAREA'))return;
  if(!['u','p','t','sq','gn','q','qmsg'].includes(t.id))return;
  if(e.ctrlKey||e.metaKey||e.altKey)return;
  if(e.key.length===1){
    const s=t.selectionStart??t.value.length,en=t.selectionEnd??t.value.length;
    t.value=t.value.slice(0,s)+e.key+t.value.slice(en);
    t.selectionStart=t.selectionEnd=s+1;
    t.dispatchEvent(new Event('input',{bubbles:true}));
    e.preventDefault();e.stopPropagation();
  }else if(e.key==='Backspace'){
    const s=t.selectionStart??0,en=t.selectionEnd??0;
    if(s===en&&s>0){t.value=t.value.slice(0,s-1)+t.value.slice(s);t.selectionStart=t.selectionEnd=s-1}
    else{t.value=t.value.slice(0,s)+t.value.slice(en);t.selectionStart=t.selectionEnd=s}
    t.dispatchEvent(new Event('input',{bubbles:true}));
    e.preventDefault();e.stopPropagation();
  }else if(e.key==='Enter'&&!e.shiftKey&&t.id!=='t'){
    const f=t.form;if(f)f.requestSubmit();e.preventDefault();
  }
},true);

// ============ TOAST ============
function toast(msg,type='info',timeout=3000){
  const d=document.createElement('div');d.className='toast '+type;d.textContent=msg;
  $('#toasts').append(d);
  setTimeout(()=>{d.classList.add('out');setTimeout(()=>d.remove(),300)},timeout);
}

// ============ LIGHTBOX ============
function lightbox(url){$('#lbimg').src=url;$('#lightbox').classList.add('on')}

// ============ THEME ============
const savedTheme=localStorage.getItem('theme');
if(savedTheme==='dark'||(!savedTheme&&matchMedia('(prefers-color-scheme:dark)').matches)){document.documentElement.dataset.theme='dark';$('#theme').textContent='☀️'}
$('#theme').onclick=()=>{const d=document.documentElement.dataset.theme==='dark';document.documentElement.dataset.theme=d?'':'dark';$('#theme').textContent=d?'🌙':'☀️';localStorage.setItem('theme',d?'light':'dark')};

// ============ API ============
async function api(a,body,qs=''){const opt=body?{method:'POST',headers:{'X-Requested-With':'fetch','Content-Type':'application/json'},body:JSON.stringify(body)}:{};const r=await fetch('api.php?a='+a+qs,opt);const j=await r.json();if(r.status===401&&!['login','register'].includes(a)){auth();throw 0}if(!r.ok)throw j.error||'Eroare';return j}
function auth(){clearInterval(timer);$('#app').classList.remove('on');$('#auth').style.display='grid'}
async function enter(){me=await api('me');$('#auth').style.display='none';$('#app').classList.add('on');$('#me').textContent=me.username;$('#meAv').textContent=me.username[0].toUpperCase();loadRooms();clearInterval(timer);timer=setInterval(tick,2000)}
async function sign(a){try{await api(a,{username:$('#u').value,password:$('#p').value});enter()}catch(e){$('#err').textContent=e;toast(e,'err')}}
$('#login').onclick=()=>sign('login');$('#reg').onclick=()=>sign('register');
$('#p').onkeydown=e=>e.key==='Enter'&&sign('login');
$('#out').onclick=async()=>{await api('logout',{});room=null;auth()};

// ============ UTILS ============
function fmtTime(t){if(!t)return'';const d=new Date(t.replace(' ','T')+'Z'),now=new Date();const diff=(now-d)/1000;if(diff<60)return'acum';if(diff<3600)return Math.floor(diff/60)+'m';if(diff<86400)return d.toLocaleTimeString([],{hour:'2-digit',minute:'2-digit'});return d.toLocaleDateString([],{day:'2-digit',month:'2-digit'})}
function fmtDate(t){const d=new Date(t.replace(' ','T')+'Z'),now=new Date(),y=new Date(now-86400000);if(d.toDateString()===now.toDateString())return'Azi';if(d.toDateString()===y.toDateString())return'Ieri';return d.toLocaleDateString('ro-RO',{day:'numeric',month:'long',year:d.getFullYear()!==now.getFullYear()?'numeric':undefined})}
function color(name){let h=0;for(const c of name)h=((h<<5)-h)+c.charCodeAt(0);const p=['#6c5ce7','#00b894','#e17055','#0984e3','#d63031','#fdcb6e','#e84393','#00cec9','#a29bfe','#55efc4'];return p[Math.abs(h)%p.length]}

// ============ ROOMS ============
async function loadRooms(){
  const l=await api('rooms');
  const q=($('#sq').value||'').toLowerCase();
  const box=$('#rooms');box.innerHTML='';let tot=0;
  const filtered=q?l.filter(r=>(r.name||'').toLowerCase().includes(q)):l;
  filtered.forEach(r=>{
    const d=document.createElement('div');d.className='room'+(room&&room.id==r.id?' on':'');
    const un=(room&&room.id==r.id)?0:+r.unread;tot+=un;
    const av=document.createElement('div');av.className='av';av.style.background='linear-gradient(135deg,'+r.color+','+r.color+'cc)';
    av.textContent=r.is_group==1?'👥':(r.name||'?')[0].toUpperCase();
    const info=document.createElement('div');info.className='info';
    const b=document.createElement('b');b.textContent=r.name||'?';
    if(r.is_group==1){const i=document.createElement('span');i.textContent=' · '+r.memcount;i.style.cssText='color:var(--mut);font-weight:400;font-size:12px';b.append(i)}
    const s=document.createElement('small');s.textContent=r.lastmsg||'Fără mesaje';
    info.append(b,s);
    const meta=document.createElement('div');meta.className='meta';
    if(r.lasttime){const t=document.createElement('span');t.className='time';t.textContent=fmtTime(r.lasttime);meta.append(t)}
    if(un){const bd=document.createElement('span');bd.className='bd';bd.textContent=un>99?'99+':un;meta.append(bd)}
    d.append(av,info,meta);
    d.onclick=()=>openRoom(r);box.append(d);
  });
  if(!filtered.length)box.innerHTML='<p style="padding:20px;color:var(--mut);text-align:center">'+(q?'Nicio conversație':'Apasă „＋ Chat” 💬')+'</p>';
  if(prevU>=0&&tot>prevU)beep();
  prevU=tot;document.title=(tot?'('+tot+') ':'')+'Chat';
}
$('#sq').oninput=loadRooms;

async function openRoom(r){
  room=r;last=0;replyTo=null;editing=null;lastDate='';
  $('#msgs').innerHTML='';$('#title').textContent=r.name;$('#sub').textContent='';
  $('#tAv').textContent=r.is_group==1?'👥':(r.name||'?')[0].toUpperCase();
  $('#tAv').style.background='linear-gradient(135deg,'+(r.color||color(r.name||'?'))+',#a29bfe)';
  $('#f').hidden=false;$('#add').hidden=r.is_group!=1;$('#info').hidden=r.is_group!=1;
  $('#app').classList.add('open');$('#rbar').classList.remove('on');$('#pinnedBar').classList.remove('on');
  $('#t').focus();tick();loadRooms();loadPinned()
}
$('#bk').onclick=()=>{room=null;$('#app').classList.remove('open')};

async function loadPinned(){try{const p=await api('pinned',0,'&room='+room.id);if(p.length){$('#pinnedBar').innerHTML='📌 <b>'+p.length+'</b> mesaj(e) fixat(e) — ultim: <i>'+p[0].body.slice(0,60)+'</i>';$('#pinnedBar').classList.add('on')}else $('#pinnedBar').classList.remove('on')}catch(e){}}

// ============ MESSAGES ============
async function tick(){
  if(n++%3==0)loadRooms().catch(()=>{});
  if(!room||busy)return;busy=true;
  try{
    const id=room.id,init=last==0;
    const R=await api('msgs',0,'&room='+id+'&after='+last);
    if(!room||room.id!=id)return;
    status(R);
    const m=R.msgs;
    if(!m.length)return;
    const b=$('#msgs'),near=b.scrollHeight-b.scrollTop-b.clientHeight<150;
    m.forEach(x=>{
      last=Math.max(last,+x.id);
      const dDate=x.created_at.slice(0,10);
      if(dDate!==lastDate){
        lastDate=dDate;
        const sep=document.createElement('div');sep.className='date-sep';
        const s=document.createElement('span');s.textContent=fmtDate(x.created_at);sep.append(s);b.append(sep);
      }
      const d=document.createElement('div');
      const mine=x.user_id==me.id;
      d.className='m'+(mine?' me':'')+(x.deleted?' del':'');
      d.dataset.id=x.id;
      if(!mine&&room.is_group==1){const i=document.createElement('div');i.className='name';i.textContent=x.username;i.style.color=color(x.username);d.append(i)}
      if(x.reply_id&&x.reply_body){const rp=document.createElement('div');rp.className='reply';const rn=document.createElement('b');rn.textContent=(x.reply_user||'?')+': ';rp.append(rn,document.createTextNode(x.reply_body.slice(0,80)));d.append(rp)}
      if(x.pinned){const pin=document.createElement('div');pin.className='pinned';pin.textContent='📌';d.append(pin)}
      if(x.deleted){d.append(document.createTextNode('🚫 mesaj șters'))}
      else if(x.type==='image'&&x.file_url){const img=document.createElement('img');img.src=x.file_url;img.loading='lazy';img.onclick=()=>lightbox(x.file_url);d.append(img)}
      else if(x.type==='audio'&&x.file_url){const au=document.createElement('audio');au.controls=true;au.src=x.file_url;d.append(au)}
      else if(x.type==='file'&&x.file_url){const a=document.createElement('a');a.className='file';a.href=x.file_url;a.target='_blank';a.download=x.file_name||'file';a.textContent='📎 '+(x.file_name||'Fișier');d.append(a)}
      else{d.append(document.createTextNode(x.body))}
      const meta=document.createElement('div');meta.className='meta';
      const t=document.createElement('span');t.textContent=fmtTime(x.created_at);meta.append(t);
      if(x.edited&&!x.deleted){const e=document.createElement('span');e.textContent='✎';meta.append(e)}
      d.append(meta);
      if(x.reactions){const rc=document.createElement('div');rc.className='reacts';const mineSet=new Set((x.my_reactions||'').split(',').filter(Boolean));x.reactions.split(',').forEach(pair=>{const [emo,cnt]=pair.split(':');const s=document.createElement('span');s.textContent=emo+(cnt>1?' '+cnt:'');if([...mineSet].some(m=>m.split(':')[1]===emo))s.classList.add('mine');s.onclick=async e=>{e.stopPropagation();await api('react',{id:+x.id,emoji:emo});reloadMsgs()};rc.append(s)});d.append(rc)}
      if(!x.deleted){
        const acts=document.createElement('div');acts.className='acts';
        const rb=document.createElement('button');rb.textContent='↩';rb.title='Răspunde';rb.onclick=e=>{e.stopPropagation();setReply(x)};acts.append(rb);
        const re=document.createElement('button');re.textContent='😊';re.title='Reacție';re.onclick=e=>{e.stopPropagation();reactQuick(x)};acts.append(re);
        const cb=document.createElement('button');cb.textContent='📋';cb.title='Copiază';cb.onclick=e=>{e.stopPropagation();navigator.clipboard.writeText(x.body||'');toast('Copiat!','ok',1500)};acts.append(cb);
        const pb=document.createElement('button');pb.textContent='📌';pb.title='Pin';pb.onclick=e=>{e.stopPropagation();api('pin',{id:+x.id}).then(()=>{reloadMsgs();loadPinned()})};acts.append(pb);
        if(mine){const eb=document.createElement('button');eb.textContent='✎';eb.title='Editează';eb.onclick=e=>{e.stopPropagation();startEdit(x)};acts.append(eb);
          const db=document.createElement('button');db.textContent='🗑';db.title='Șterge';db.onclick=e=>{e.stopPropagation();delMsg(x.id)};acts.append(db)}
        d.append(acts);
      }
      b.append(d);
    });
    if(!init&&m.some(x=>x.user_id!=me.id))beep();
    if(near||init)setTimeout(()=>b.scrollTop=b.scrollHeight,50);
  }catch(e){}finally{busy=false}
}
function reactQuick(x){const e=prompt('Reacție (❤️ 😂 👍 😮 😢 🔥):','❤️');if(e)api('react',{id:+x.id,emoji:e}).then(reloadMsgs)}
function setReply(x){replyTo=x;$('#rtxt').textContent=(x.username||'')+': '+(x.body||'').slice(0,60);$('#rbar').classList.add('on');$('#t').focus()}
$('#rcancel').onclick=()=>{replyTo=null;$('#rbar').classList.remove('on')};
function startEdit(x){editing=x.id;$('#t').value=x.body;$('#t').focus()}
async function delMsg(id){if(!confirm('Ștergi?'))return;try{await api('del',{id});reloadMsgs();toast('Șters','ok')}catch(e){toast(e,'err')}}
async function reloadMsgs(){last=0;lastDate='';$('#msgs').innerHTML='';await tick()}

// ============ SEND ============
$('#f').onsubmit=async e=>{
  e.preventDefault();
  const t=$('#t').value.trim();if(!t||!room)return;
  try{
    if(editing){await api('edit',{id:editing,body:t});editing=null}
    else{await api('send',{room_id:room.id,body:t,reply_id:replyTo?+replyTo.id:0})}
    $('#t').value='';replyTo=null;$('#rbar').classList.remove('on');reloadMsgs()
  }catch(x){toast(x,'err')}
};
$('#t').onkeydown=e=>{if(e.key==='Enter'&&!e.shiftKey){e.preventDefault();$('#f').requestSubmit()}};
$('#t').oninput=()=>{$('#t').style.height='auto';$('#t').style.height=Math.min($('#t').scrollHeight,120)+'px';if(room&&Date.now()-tt>2500){tt=Date.now();api('typing',{room_id:room.id}).catch(()=>{})}};
let tt=0;

// ============ EMOJI ============
const EMOJIS='😀 😃 😄 😁 😆 😅 🤣 😂 🙂 🙃 😉 😊 😇 🥰 😍 🤩 😘 😗 😚 😙 😋 😛 😜 🤪 😝 🤑 🤗 🤭 🤫 🤔 🤐 🤨 😐 😑 😶 😏 😒 🙄 😬 🤥 😌 😔 😪 🤤 😴 😷 🤒 🤕 🤢 🤮 🥵 🥶 😵 🤯 🤠 🥳 😎 🤓 🧐 😕 😟 🙁 😮 😯 😲 😳 🥺 😦 😧 😨 😰 😥 😢 😭 😱 😖 😣 😞 😓 😩 😫 🥱 😤 😡 😠 🤬 😈 👿 💀 💩 👻 👽 🤖 😺 ❤️ 🧡 💛 💚 💙 💜 🖤 🤍 💔 ❣️ 💕 💞 💓 💗 💖 💘 💝 👍 👎 👏 🙌 🤝 🙏 ✌️ 🤞 🤟 🤘 👌 👈 👉 👆 👇 ✋ 🔥 ⭐ ✨ 🎉 🎊 🎁 🎈 💯 ✅ ❌ ⚡ 💥 🚀 🎯 🏆 🥇 🎵 🎶 ☕ 🍕 🍔 🍟 🍰 🍺 🍻'.split(' ');
$('#emojis').innerHTML=EMOJIS.map(e=>'<span>'+e+'</span>').join('');
$('#emoBtn').onclick=e=>{e.stopPropagation();$('#emojis').classList.toggle('on')};
$('#emojis').onclick=e=>{if(e.target.tagName==='SPAN'){$('#t').value+=$('#t').value?' '+e.target.textContent:e.target.textContent;$('#t').focus()}};
document.addEventListener('click',e=>{if(!e.target.closest('#emojis')&&e.target.id!=='emoBtn')$('#emojis').classList.remove('on')});

// ============ UPLOAD ============
$('#fileBtn').onclick=()=>$('#fileInput').click();
$('#fileInput').onchange=async()=>{
  const f=$('#fileInput').files[0];if(!f||!room)return;
  const fd=new FormData();fd.append('f',f);fd.append('room_id',room.id);
  try{toast('Se încarcă...','info');
    const r=await fetch('api.php?a=upload',{method:'POST',headers:{'X-Requested-With':'fetch'},body:fd});
    const j=await r.json();if(!r.ok)throw j.error||'Eroare';
    await api('send',{room_id:room.id,body:j.name,type:j.type,file_url:j.url,file_name:j.name});
    toast('Trimis!','ok',1500);reloadMsgs()
  }catch(e){toast(e,'err')}
  $('#fileInput').value=''
};

// ============ VOICE ============
$('#voiceBtn').onclick=async()=>{
  if(mediaRec&&mediaRec.state==='recording'){mediaRec.stop();clearTimeout(recTimer);$('#voiceBtn').classList.remove('rec');return}
  try{
    const s=await navigator.mediaDevices.getUserMedia({audio:true});
    mediaRec=new MediaRecorder(s);recChunks=[];
    mediaRec.ondataavailable=e=>recChunks.push(e.data);
    mediaRec.onstop=async()=>{
      s.getTracks().forEach(t=>t.stop());
      const blob=new Blob(recChunks,{type:'audio/webm'});
      if(blob.size<1000)return;
      const fd=new FormData();fd.append('f',new File([blob],'voice-'+Date.now()+'.webm',{type:'audio/webm'}));fd.append('room_id',room.id);
      try{const r=await fetch('api.php?a=upload',{method:'POST',headers:{'X-Requested-With':'fetch'},body:fd});const j=await r.json();if(!r.ok)throw j.error;await api('send',{room_id:room.id,body:'🎙️ Voice',type:'audio',file_url:j.url,file_name:j.name});reloadMsgs();toast('Voice trimis!','ok',1500)}catch(e){toast(e,'err')}
    };
    mediaRec.start();$('#voiceBtn').classList.add('rec');toast('Înregistrez... click din nou să oprești','info',2500);
    recTimer=setTimeout(()=>{if(mediaRec.state==='recording')mediaRec.stop();$('#voiceBtn').classList.remove('rec')},60000);
  }catch(e){toast('Nu pot accesa microfonul: '+e.message,'err')}
};

// ============ SEARCH MESSAGES ============
$('#srchBtn').onclick=()=>{if(!room)return;$('#qmsg').value='';$('#sres').innerHTML='';$('#searchDlg').showModal();setTimeout(()=>$('#qmsg').focus(),100)};
$('#qmsg').oninput=async()=>{
  const q=$('#qmsg').value.trim();if(q.length<2){$('#sres').innerHTML='';return}
  try{const r=await api('search',0,'&room='+room.id+'&q='+encodeURIComponent(q));
    $('#sres').innerHTML=r.map(m=>'<div style="padding:10px;border-bottom:1px solid var(--bd)"><b style="color:'+color(m.username)+'">'+m.username+'</b> <small style="color:var(--mut)">'+fmtTime(m.created_at)+'</small><div style="margin-top:4px">'+m.body.replace(/</g,'&lt;')+'</div></div>').join('')||'<p style="color:var(--mut);text-align:center;padding:20px">Nimic găsit</p>';
  }catch(e){}
};

// ============ EXPORT ============
$('#expBtn').onclick=()=>{if(!room)return;window.open('api.php?a=export&room='+room.id,'_blank');toast('Se descarcă...','info',1500)};

// ============ DIALOG ============
function dlg(m){mode=m;sel.clear();$('#dt').textContent=m=='dm'?'💬 Chat nou':m=='grp'?'👥 Grup nou':'➕ Adaugă membri';$('#gn').style.display=m=='grp'?'':'none';$('#gn').value='';$('#ok').style.display=m=='dm'?'none':'';$('#ok').textContent=m=='grp'?'Creează':'Adaugă';$('#q').value='';find();$('#dlg').showModal()}
async function find(){const l=await api('users',0,'&q='+encodeURIComponent($('#q').value));const b=$('#ul');b.innerHTML='';if(!l.length){b.innerHTML='<p style="padding:14px;color:var(--mut);text-align:center">Niciun utilizator</p>';return}l.forEach(u=>{const d=document.createElement('div');d.className='u'+(sel.has(u.username)?' sel':'');const av=document.createElement('div');av.className='av sm';av.style.background='linear-gradient(135deg,'+color(u.username)+','+color(u.username)+'cc)';av.textContent=u.username[0].toUpperCase();d.append(av,document.createTextNode(u.username));d.onclick=async()=>{if(mode=='dm'){const r=await api('dm',{user_id:u.id});$('#dlg').close();await loadRooms();openRoom({id:r.id,name:u.username,is_group:0})}else{sel.has(u.username)?sel.delete(u.username):sel.add(u.username);d.classList.toggle('sel')}};b.append(d)})}
$('#q').oninput=find;$('#nd').onclick=()=>dlg('dm');$('#ng').onclick=()=>dlg('grp');$('#add').onclick=()=>dlg('add');$('#cx').onclick=()=>$('#dlg').close();
$('#ok').onclick=async()=>{try{if(mode=='grp'){const name=$('#gn').value.trim();if(!name){toast('Dă nume grupului','warn');return}const r=await api('group',{name,members:[...sel]});$('#dlg').close();await loadRooms();openRoom({id:r.id,name,is_group:1,color:color(name),memcount:sel.size+1})}else{for(const u of sel)await api('add',{room_id:room.id,username:u});$('#dlg').close();loadRooms();toast('Adăugat!','ok')}}catch(e){toast(e,'err')}};

$('#info').onclick=async()=>{const l=await api('members',0,'&room='+room.id);$('#mlist').innerHTML=l.map(u=>{const c=color(u.username);return '<div class="u"><div class="av sm" style="background:linear-gradient(135deg,'+c+','+c+'cc)">'+u.username[0].toUpperCase()+'</div>'+u.username+(u.online?' <span style="color:var(--ok);font-size:11px;font-weight:600">● online</span>':'')+'</div>'}).join('');$('#infoDlg').showModal()};

function status(R){$('#sub').textContent=R.typing.length?R.typing.join(', ')+' scrie...':(R.online.length?(room.is_group==1?R.online.length+' online':'● online'):'');$('#sub').style.color=R.typing.length?'var(--ac)':(R.online.length?'var(--ok)':'var(--mut)')}

// ============ SCROLL BUTTON ============
$('#msgs').addEventListener('scroll',()=>{
  const b=$('#msgs');const near=b.scrollHeight-b.scrollTop-b.clientHeight<150;
  $('#scrollBtn').classList.toggle('on',!near&&b.scrollHeight>400);
});
$('#scrollBtn').onclick=()=>{$('#msgs').scrollTop=$('#msgs').scrollHeight};

// ============ SOUND ============
document.addEventListener('click',()=>{try{ac=ac||new(window.AudioContext||window.webkitAudioContext)();ac.resume()}catch(e){}},{once:true});
function beep(){if(!ac)return;try{const o=ac.createOscillator(),g=ac.createGain();o.connect(g);g.connect(ac.destination);o.type='sine';o.frequency.setValueAtTime(660,ac.currentTime);o.frequency.exponentialRampToValueAtTime(880,ac.currentTime+.1);g.gain.setValueAtTime(.06,ac.currentTime);g.gain.exponentialRampToValueAtTime(.001,ac.currentTime+.2);o.start();o.stop(ac.currentTime+.2)}catch(e){}}

// ============ KEYBOARD SHORTCUTS ============
document.addEventListener('keydown',e=>{
  if(e.ctrlKey&&e.key==='k'){e.preventDefault();$('#sq').focus()}
  if(e.key==='Escape'){if(room&&$('#app').classList.contains('open')&&innerWidth<760){$('#app').classList.remove('open')}}
});

enter().catch(auth);
</script></body></html>
EOF_HTML

echo "✅ index.html v5 scris"
echo "✅ Folosește api.php v4 (nemodificat)"
echo ""
echo "🎨 Chat v5 activat! Deschide: http://10.130.70.55:8080 (Ctrl+Shift+R)"
echo ""
echo "🎁 Ce e nou în v5:"
echo "   • Aurora background animat"
echo "   • Glassmorphism pe carduri"
echo "   • Toast notifications (nu mai alert())"
echo "   • Lightbox pentru imagini"
echo "   • Separatoare de dată (Azi/Ieri)"
echo "   • Scroll-to-bottom button"
echo "   • Copy message"
echo "   • Pin bar sus"
echo "   • Micro-animații peste tot"
echo "   • Gradient animat pe butoane"
echo "   • Fix tastatură inclus"
