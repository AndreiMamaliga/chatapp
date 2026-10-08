#!/bin/bash
# Chat v4: upload, voice, reactions, pin, search, export, PWA, theme
set -e
cd /home/admin/chatapp
[ -f html/api.php ] && cp html/api.php html/api.php.v3bak
[ -f html/index.html ] && cp html/index.html html/index.html.v3bak

mkdir -p html/uploads
chmod 755 html/uploads

# ============ API.PHP ============
cat > html/api.php <<'EOF_API'
<?php
session_set_cookie_params(['httponly'=>true,'samesite'=>'Lax']);
session_start();
require 'config.php';
header('Content-Type: application/json; charset=utf-8');
$pdo=new PDO('mysql:host=mysql;dbname=chatdb;charset=utf8mb4',DB_USER,DB_PASS,[PDO::ATTR_ERRMODE=>PDO::ERRMODE_EXCEPTION,PDO::ATTR_DEFAULT_FETCH_MODE=>PDO::FETCH_ASSOC]);
function out($d,$c=200){http_response_code($c);echo json_encode($d);exit;}
function q($sql,$p=[]){global $pdo;$s=$pdo->prepare($sql);$s->execute($p);return $s;}
$in=json_decode(file_get_contents('php://input'),true)?:[];
$a=$_GET['a']??'';
if($_SERVER['REQUEST_METHOD']==='POST'&&($_SERVER['HTTP_X_REQUESTED_WITH']??'')!=='fetch'&&$a!=='upload')out(['error'=>'bad request'],400);
$uid=$_SESSION['uid']??0;

if($a==='register'||$a==='login'){
 $u=trim($in['username']??'');$p=$in['password']??'';
 if($a==='register'){
  if(!preg_match('/^[A-Za-z0-9_]{3,20}$/',$u)||strlen($p)<6)out(['error'=>'Username 3-20 caractere, parolă min 6'],400);
  try{q('INSERT INTO users(username,password) VALUES(?,?)',[$u,password_hash($p,PASSWORD_DEFAULT)]);}catch(PDOException $e){out(['error'=>'Username ocupat'],400);}
 }
 $r=q('SELECT * FROM users WHERE username=?',[$u])->fetch();
 if(!$r||!password_verify($p,$r['password']))out(['error'=>'Date incorecte'],401);
 session_regenerate_id(true);$_SESSION['uid']=$r['id'];out(['ok'=>1]);
}
if($a==='logout'){session_destroy();out(['ok'=>1]);}
if(!$uid)out(['error'=>'auth'],401);
q('UPDATE users SET last_seen=NOW() WHERE id=?',[$uid]);
function member($rid){global $uid;return q('SELECT 1 FROM room_members WHERE room_id=? AND user_id=?',[$rid,$uid])->fetch();}
function colorOf($n){$h=0;foreach(str_split($n) as $c)$h=(($h<<5)-$h+ord($c))&0xFFFFFF;$p=['#6c5ce7','#00b894','#e17055','#0984e3','#d63031','#fdcb6e','#e84393','#00cec9','#a29bfe','#55efc4'];return $p[abs($h)%count($p)];}

switch($a){
case 'me':
 out(q('SELECT id,username FROM users WHERE id=?',[$uid])->fetch());
case 'rooms':
 $rows=q('SELECT r.id,r.is_group,r.name,
  (SELECT m.body FROM messages m WHERE m.room_id=r.id AND m.deleted=0 ORDER BY m.id DESC LIMIT 1) lastmsg,
  (SELECT m.created_at FROM messages m WHERE m.room_id=r.id AND m.deleted=0 ORDER BY m.id DESC LIMIT 1) lasttime,
  (SELECT MAX(m.id) FROM messages m WHERE m.room_id=r.id) last_id,
  (SELECT COUNT(*) FROM messages m WHERE m.room_id=r.id AND m.id>rm.last_read AND m.user_id<>? AND m.deleted=0) unread,
  (SELECT GROUP_CONCAT(u.username) FROM room_members x JOIN users u ON u.id=x.user_id WHERE x.room_id=r.id AND x.user_id<>?) others,
  (SELECT COUNT(*) FROM room_members WHERE room_id=r.id) memcount
  FROM rooms r JOIN room_members rm ON rm.room_id=r.id AND rm.user_id=? ORDER BY COALESCE(last_id,0) DESC, r.id DESC',[$uid,$uid,$uid])->fetchAll();
 foreach($rows as &$r){if(!$r['is_group'])$r['name']=$r['others'];$r['color']=colorOf($r['name']??'?');}
 out($rows);
case 'users':
 $s='%'.str_replace(['%','_'],'',$_GET['q']??'').'%';
 out(q('SELECT id,username FROM users WHERE username LIKE ? AND id<>? ORDER BY username LIMIT 30',[$s,$uid])->fetchAll());
case 'dm':
 $o=(int)($in['user_id']??0);
 if($o==$uid||!q('SELECT 1 FROM users WHERE id=?',[$o])->fetch())out(['error'=>'Utilizator invalid'],400);
 $r=q('SELECT r.id FROM rooms r JOIN room_members a ON a.room_id=r.id AND a.user_id=? JOIN room_members b ON b.room_id=r.id AND b.user_id=? WHERE r.is_group=0 LIMIT 1',[$uid,$o])->fetchColumn();
 if(!$r){q('INSERT INTO rooms(is_group,created_by) VALUES(0,?)',[$uid]);$r=$pdo->lastInsertId();q('INSERT INTO room_members VALUES(?,?),(?,?)',[$r,$uid,$r,$o]);}
 out(['id'=>$r]);
case 'group':
 $n=trim($in['name']??'');
 if($n===''||mb_strlen($n)>40)out(['error'=>'Nume grup invalid'],400);
 q('INSERT INTO rooms(is_group,name,created_by) VALUES(1,?,?)',[$n,$uid]);$r=$pdo->lastInsertId();
 q('INSERT INTO room_members VALUES(?,?)',[$r,$uid]);
 foreach(array_slice((array)($in['members']??[]),0,50) as $m){$i=q('SELECT id FROM users WHERE username=?',[$m])->fetchColumn();if($i)q('INSERT IGNORE INTO room_members VALUES(?,?)',[$r,$i]);}
 out(['id'=>$r]);
case 'add':
 $r=(int)($in['room_id']??0);
 if(!member($r)||!q('SELECT 1 FROM rooms WHERE id=? AND is_group=1',[$r])->fetch())out(['error'=>'Interzis'],403);
 $i=q('SELECT id FROM users WHERE username=?',[trim($in['username']??'')])->fetchColumn();
 if(!$i)out(['error'=>'User inexistent'],404);
 q('INSERT IGNORE INTO room_members VALUES(?,?)',[$r,$i]);out(['ok'=>1]);
case 'members':
 $r=(int)($_GET['room']??0);if(!member($r))out(['error'=>'Interzis'],403);
 out(q('SELECT u.id,u.username,u.last_seen>NOW()-INTERVAL 30 SECOND online FROM room_members x JOIN users u ON u.id=x.user_id WHERE x.room_id=? ORDER BY online DESC,u.username',[$r])->fetchAll());
case 'msgs':
 $r=(int)($_GET['room']??0);if(!member($r))out(['error'=>'Interzis'],403);
 $ms=q('SELECT * FROM (SELECT m.id,m.user_id,u.username,m.body,m.type,m.file_url,m.file_name,m.created_at,m.edited,m.deleted,m.reply_id,m.pinned,rm.body reply_body,ru.username reply_user,
  (SELECT GROUP_CONCAT(CONCAT(rx.emoji,":",rx.cnt)) FROM (SELECT emoji,COUNT(*) cnt FROM reactions WHERE message_id=m.id GROUP BY emoji) rx) reactions,
  (SELECT GROUP_CONCAT(CONCAT(x.user_id,":",x.emoji)) FROM reactions x WHERE x.message_id=m.id) my_reactions
  FROM messages m JOIN users u ON u.id=m.user_id LEFT JOIN messages rm ON rm.id=m.reply_id LEFT JOIN users ru ON ru.id=rm.user_id WHERE m.room_id=? AND m.id>? ORDER BY m.id DESC LIMIT 100) t ORDER BY id',[$r,(int)($_GET['after']??0)])->fetchAll();
 q('UPDATE room_members SET last_read=(SELECT COALESCE(MAX(id),0) FROM messages WHERE room_id=?) WHERE room_id=? AND user_id=?',[$r,$r,$uid]);
 $ty=q('SELECT u.username FROM room_members x JOIN users u ON u.id=x.user_id WHERE x.room_id=? AND x.user_id<>? AND x.typing_at>NOW()-INTERVAL 4 SECOND',[$r,$uid])->fetchAll(PDO::FETCH_COLUMN);
 $on=q('SELECT u.username FROM room_members x JOIN users u ON u.id=x.user_id WHERE x.room_id=? AND x.user_id<>? AND u.last_seen>NOW()-INTERVAL 30 SECOND',[$r,$uid])->fetchAll(PDO::FETCH_COLUMN);
 out(['msgs'=>$ms,'typing'=>$ty,'online'=>$on]);
case 'typing':
 $r=(int)($in['room_id']??0);q('UPDATE room_members SET typing_at=NOW() WHERE room_id=? AND user_id=?',[$r,$uid]);out(['ok'=>1]);
case 'send':
 $r=(int)($in['room_id']??0);$b=trim($in['body']??'');$rep=(int)($in['reply_id']??0)?:null;$ty=$in['type']??'text';$fu=$in['file_url']??null;$fn=$in['file_name']??null;
 if(!member($r))out(['error'=>'Interzis'],403);
 if($ty==='text'&&($b===''||mb_strlen($b)>2000))out(['error'=>'Mesaj invalid'],400);
 $cnt=q('SELECT COUNT(*) FROM messages WHERE user_id=? AND created_at>NOW()-INTERVAL 30 SECOND',[$uid])->fetchColumn();
 if($cnt>20)out(['error'=>'Prea rapid! Așteaptă puțin'],429);
 q('INSERT INTO messages(room_id,user_id,body,type,file_url,file_name,reply_id) VALUES(?,?,?,?,?,?,?)',[$r,$uid,$b,$ty,$fu,$fn,$rep]);out(['id'=>$pdo->lastInsertId()]);
case 'upload':
 if(!$uid)out(['error'=>'auth'],401);
 $r=(int)($_POST['room_id']??0);if(!member($r))out(['error'=>'Interzis'],403);
 if(!isset($_FILES['f'])||$_FILES['f']['error'])out(['error'=>'Upload eșuat'],400);
 $f=$_FILES['f'];
 if($f['size']>10485760)out(['error'=>'Fișier > 10MB'],400);
 $ext=strtolower(pathinfo($f['name'],PATHINFO_EXTENSION));
 $allowed=['jpg','jpeg','png','gif','webp','pdf','txt','doc','docx','zip','mp3','ogg','webm','mp4'];
 if(!in_array($ext,$allowed))out(['error'=>'Tip fișier nepermis'],400);
 $safe=bin2hex(random_bytes(8)).'.'.$ext;
 $dir=__DIR__.'/uploads/';if(!is_dir($dir))mkdir($dir,0755,true);
 if(!move_uploaded_file($f['tmp_name'],$dir.$safe))out(['error'=>'Salvare eșuată'],500);
 $ty=in_array($ext,['jpg','jpeg','png','gif','webp'])?'image':(in_array($ext,['mp3','ogg','webm'])?'audio':'file');
 out(['url'=>'uploads/'.$safe,'name'=>$f['name'],'type'=>$ty]);
case 'edit':
 $id=(int)($in['id']??0);$b=trim($in['body']??'');
 $m=q('SELECT * FROM messages WHERE id=? AND user_id=?',[$id,$uid])->fetch();
 if(!$m||$b===''||mb_strlen($b)>2000)out(['error'=>'Nu poți edita'],403);
 q('UPDATE messages SET body=?,edited=1 WHERE id=?',[$b,$id]);out(['ok'=>1]);
case 'del':
 $id=(int)($in['id']??0);
 $m=q('SELECT * FROM messages WHERE id=? AND user_id=?',[$id,$uid])->fetch();
 if(!$m)out(['error'=>'Nu poți șterge'],403);
 q('UPDATE messages SET deleted=1,body="" WHERE id=?',[$id]);out(['ok'=>1]);
case 'pin':
 $id=(int)($in['id']??0);
 $m=q('SELECT room_id,pinned FROM messages WHERE id=?',[$id])->fetch();
 if(!$m||!member($m['room_id']))out(['error'=>'Interzis'],403);
 q('UPDATE messages SET pinned=? WHERE id=?',[$m['pinned']?0:1,$id]);out(['ok'=>1,'pinned'=>!$m['pinned']]);
case 'pinned':
 $r=(int)($_GET['room']??0);if(!member($r))out(['error'=>'Interzis'],403);
 out(q('SELECT m.id,m.body,u.username FROM messages m JOIN users u ON u.id=m.user_id WHERE m.room_id=? AND m.pinned=1 AND m.deleted=0 ORDER BY m.id DESC LIMIT 5',[$r])->fetchAll());
case 'react':
 $id=(int)($in['id']??0);$e=$in['emoji']??'';
 $allow=['❤️','😂','👍','😮','😢','🔥'];
 if(!in_array($e,$allow))out(['error'=>'Emoji invalid'],400);
 $m=q('SELECT room_id FROM messages WHERE id=?',[$id])->fetch();
 if(!$m||!member($m['room_id']))out(['error'=>'Interzis'],403);
 $ex=q('SELECT id FROM reactions WHERE message_id=? AND user_id=? AND emoji=?',[$id,$uid,$e])->fetch();
 if($ex)q('DELETE FROM reactions WHERE id=?',[$ex['id']]);
 else q('INSERT INTO reactions(message_id,user_id,emoji) VALUES(?,?,?)',[$id,$uid,$e]);
 out(['ok'=>1]);
case 'search':
 $r=(int)($_GET['room']??0);$qs=trim($_GET['q']??'');
 if(!member($r)||strlen($qs)<2)out(['error'=>'Interzis'],403);
 out(q('SELECT m.id,m.body,m.created_at,u.username FROM messages m JOIN users u ON u.id=m.user_id WHERE m.room_id=? AND m.body LIKE ? AND m.deleted=0 ORDER BY m.id DESC LIMIT 50',[$r,'%'.$qs.'%'])->fetchAll());
case 'export':
 $r=(int)($_GET['room']??0);if(!member($r))out(['error'=>'Interzis'],403);
 $ms=q('SELECT m.id,u.username,m.body,m.type,m.created_at FROM messages m JOIN users u ON u.id=m.user_id WHERE m.room_id=? AND m.deleted=0 ORDER BY m.id',[$r])->fetchAll();
 header('Content-Disposition: attachment; filename="chat-'.$r.'-'.date('Y-m-d').'.json"');
 header('Content-Type: application/json');
 echo json_encode(['room'=>$r,'exported'=>date('c'),'messages'=>$ms],JSON_PRETTY_PRINT|JSON_UNESCAPED_UNICODE);exit;
case 'unread':
 $n=q('SELECT COUNT(*) FROM messages m JOIN room_members rm ON rm.room_id=m.room_id AND rm.user_id=? WHERE m.id>rm.last_read AND m.user_id<>? AND m.deleted=0',[$uid,$uid])->fetchColumn();
 out(['n'=>(int)$n]);
}
out(['error'=>'unknown'],404);
EOF_API

docker compose exec -T php php -l /usr/share/nginx/html/api.php || { echo "❌ Eroare PHP în api.php"; exit 1; }

# ============ INDEX.HTML ============
cat > html/index.html <<'EOF_HTML'
<!DOCTYPE html><html lang="ro"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1,viewport-fit=cover">
<meta name="theme-color" content="#6c5ce7">
<meta name="format-detection" content="telephone=no">
<title>💬 Chat</title>
<style>
:root{--bg:#eef0f7;--card:#fff;--tx:#14152a;--mut:#8a8fa3;--ac:#6c5ce7;--other:#eef0fa;--bd:#e5e7f0;--me:linear-gradient(135deg,#6c5ce7,#8e7cff);--ok:#00b894;--warn:#fdcb6e}
[data-theme=dark]{--bg:#0a0b1a;--card:#141530;--tx:#eceefa;--other:#1f2145;--bd:#262948;--mut:#7c81a8}
*{box-sizing:border-box}html,body{height:100%;margin:0;overscroll-behavior:none}
body{font:15px system-ui,-apple-system,sans-serif;background:var(--bg);color:var(--tx);transition:background .2s}
button,input,textarea{font:inherit;color:inherit}
input,textarea{width:100%;padding:12px 14px;border:1px solid var(--bd);border-radius:12px;background:var(--card);outline:none;transition:border .15s;color:var(--tx)}
input:focus,textarea:focus{border-color:var(--ac);box-shadow:0 0 0 3px rgba(108,92,231,.15)}
.btn{background:var(--me);color:#fff;border:0;border-radius:12px;padding:12px 18px;cursor:pointer;font-weight:600;transition:transform .1s,opacity .15s}
.btn:active{transform:scale(.97)}.btn:hover{opacity:.9}
.ghost{background:none;border:0;cursor:pointer;color:var(--mut);padding:8px;border-radius:8px;transition:background .15s}
.ghost:hover{background:var(--other);color:var(--tx)}
#auth{display:grid;max-width:360px;margin:10vh auto;padding:32px;gap:14px;text-align:center}
#auth h1{margin:0 0 8px;font-size:32px}
#auth .logo{font-size:56px;line-height:1}
#app{display:none;height:100%;max-width:1100px;margin:auto;background:var(--card);box-shadow:0 0 40px rgba(0,0,0,.08)}
#app.on{display:flex}
#side{width:340px;border-right:1px solid var(--bd);display:flex;flex-direction:column;min-width:0}
#main{flex:1;display:flex;flex-direction:column;min-width:0;background:var(--bg)}
header{display:flex;align-items:center;gap:10px;padding:14px;padding-top:max(14px,env(safe-area-inset-top));border-bottom:1px solid var(--bd);font-weight:600;background:var(--card);min-height:64px}
.sp{flex:1}
#rooms{overflow:auto;flex:1}
#rooms::-webkit-scrollbar,#msgs::-webkit-scrollbar{width:6px}
#rooms::-webkit-scrollbar-thumb,#msgs::-webkit-scrollbar-thumb{background:var(--bd);border-radius:3px}
.room{padding:12px 14px;cursor:pointer;display:flex;gap:12px;align-items:center;transition:background .12s;position:relative}
.room:hover{background:var(--other)}
.room.on{background:var(--other)}
.room.on::before{content:'';position:absolute;left:0;top:8px;bottom:8px;width:3px;background:var(--ac);border-radius:0 3px 3px 0}
.av{width:48px;height:48px;border-radius:50%;display:flex;align-items:center;justify-content:center;color:#fff;font-weight:700;font-size:18px;flex-shrink:0}
.av.sm{width:36px;height:36px;font-size:14px}
.room .info{flex:1;min-width:0}
.room b{display:block;font-size:15px;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}
.room small{color:var(--mut);font-size:13px;white-space:nowrap;overflow:hidden;text-overflow:ellipsis;display:block;margin-top:2px}
.room .meta{text-align:right;flex-shrink:0;display:flex;flex-direction:column;align-items:flex-end;gap:4px}
.room .time{font-size:11px;color:var(--mut)}
.bd{background:var(--ac);color:#fff;border-radius:10px;padding:1px 7px;font-size:11px;font-weight:700;min-width:20px;text-align:center}
#msgs{flex:1;overflow:auto;padding:16px;display:flex;flex-direction:column;gap:8px;background:var(--bg)}
.m{max-width:75%;padding:8px 12px 6px;border-radius:16px;background:var(--card);word-wrap:break-word;white-space:pre-wrap;align-self:flex-start;position:relative;box-shadow:0 1px 2px rgba(0,0,0,.05)}
.m.me{background:var(--me);color:#fff;align-self:flex-end}
.m .meta{display:flex;gap:6px;align-items:center;font-size:11px;margin-top:2px;justify-content:flex-end;opacity:.75}
.m.me .meta{color:rgba(255,255,255,.85)}
.m .name{font-size:12px;font-weight:700;margin-bottom:2px;opacity:.9}
.m .reply{background:rgba(0,0,0,.06);border-left:3px solid var(--ac);padding:4px 8px;border-radius:6px;font-size:12px;margin-bottom:4px;opacity:.85}
.m.me .reply{background:rgba(255,255,255,.15);border-left-color:#fff}
.m .acts{position:absolute;top:-8px;right:8px;display:none;gap:2px;background:var(--card);border:1px solid var(--bd);border-radius:8px;padding:2px;box-shadow:0 2px 8px rgba(0,0,0,.1);z-index:5}
.m:hover .acts{display:flex}
.m .acts button{background:none;border:0;cursor:pointer;padding:4px;border-radius:6px;color:var(--mut);font-size:14px;line-height:1}
.m .acts button:hover{background:var(--other);color:var(--tx)}
.m.del{opacity:.5;font-style:italic}
.m img,.m video{max-width:100%;border-radius:8px;margin-top:4px;display:block}
.m audio{width:100%;margin-top:4px}
.m .file{display:flex;align-items:center;gap:8px;padding:8px;background:rgba(0,0,0,.05);border-radius:8px;margin-top:4px;text-decoration:none;color:inherit}
.m .pinned{position:absolute;top:-6px;left:-6px;background:var(--warn);color:#000;width:20px;height:20px;border-radius:50%;display:flex;align-items:center;justify-content:center;font-size:11px}
.reacts{display:flex;gap:3px;flex-wrap:wrap;margin-top:4px}
.reacts span{background:rgba(0,0,0,.08);padding:1px 6px;border-radius:10px;font-size:13px;cursor:pointer;user-select:none}
.reacts span.mine{background:rgba(108,92,231,.25);outline:1px solid var(--ac)}
#f{display:flex;gap:8px;padding:12px;padding-bottom:max(12px,env(safe-area-inset-bottom));border-top:1px solid var(--bd);background:var(--card);align-items:flex-end;position:relative}
#t{resize:none;max-height:120px;min-height:44px;padding:11px 14px;border-radius:22px;font-family:inherit}
#f .ico{background:none;border:0;cursor:pointer;font-size:22px;padding:8px;border-radius:50%;color:var(--mut);transition:background .15s}
#f .ico:hover{background:var(--other);color:var(--tx)}
#f .ico.rec{color:#e74c3c;animation:pulse 1s infinite}
@keyframes pulse{50%{opacity:.4}}
#f .send{width:44px;height:44px;border-radius:50%;padding:0;display:flex;align-items:center;justify-content:center;flex-shrink:0}
#empty{margin:auto;color:var(--mut);text-align:center}
#empty .big{font-size:64px;margin-bottom:12px}
dialog{border:0;border-radius:20px;padding:20px;width:min(420px,92vw);background:var(--card);color:var(--tx);box-shadow:0 20px 60px rgba(0,0,0,.25)}
dialog::backdrop{background:rgba(0,0,0,.5);backdrop-filter:blur(4px)}
dialog h3{margin:0 0 14px}
.u{padding:10px 12px;border-radius:10px;cursor:pointer;display:flex;align-items:center;gap:10px}
.u:hover{background:var(--other)}
.u.sel{background:var(--other);font-weight:600}
.u.sel::after{content:'✓';margin-left:auto;color:var(--ac);font-weight:700}
.tools{display:flex;gap:8px;padding:10px 14px}
.tools .btn{flex:1;padding:10px;font-size:14px}
.back{display:none}
@media(max-width:760px){#side{width:100%}#main{display:none}#app.open #side{display:none}#app.open #main{display:flex}.back{display:inline}}
#emojis{position:absolute;bottom:100%;left:12px;background:var(--card);border:1px solid var(--bd);border-radius:16px;padding:10px;display:none;grid-template-columns:repeat(8,1fr);gap:4px;box-shadow:0 8px 24px rgba(0,0,0,.15);max-height:220px;overflow:auto;width:min(340px,90vw);margin-bottom:8px;z-index:10}
#emojis.on{display:grid}
#emojis span{font-size:22px;cursor:pointer;padding:4px;border-radius:8px;text-align:center}
#emojis span:hover{background:var(--other)}
.reply-bar{display:none;padding:8px 14px;background:var(--other);border-top:1px solid var(--bd);align-items:center;gap:8px;font-size:13px}
.reply-bar.on{display:flex}
.reply-bar .txt{flex:1;white-space:nowrap;overflow:hidden;text-overflow:ellipsis;color:var(--mut)}
#search{display:none;padding:8px 14px;border-bottom:1px solid var(--bd)}
#search.on{display:block}
</style></head><body>

<div id="auth">
<div class="logo">💬</div>
<h1>Chat</h1>
<input id="u" type="text" placeholder="Username" name="username" autocomplete="on" autocapitalize="off" autocorrect="off" spellcheck="true">
<input id="p" type="password" placeholder="Parolă" name="password" autocomplete="current-password">
<button class="btn" id="login">Intră în cont</button>
<button class="ghost" id="reg">Nu ai cont? Creează unul</button>
<small id="err" style="color:#e55;min-height:16px"></small>
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
    <div id="search"><input id="sq" placeholder="🔍 Caută conversații..."></div>
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
    <div id="msgs"><div id="empty"><div class="big">💬</div>Alege o conversație<br><small>sau începe una nouă</small></div></div>
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
<div id="ul" style="max-height:260px;overflow:auto;margin:8px 0"></div>
<div style="display:flex;gap:8px"><button class="ghost" id="cx">Anulează</button><span class="sp"></span><button class="btn" id="ok">Creează</button></div>
</dialog>

<dialog id="infoDlg"><h3>Membri</h3><div id="mlist" style="max-height:300px;overflow:auto"></div>
<div style="display:flex;margin-top:12px"><span class="sp"></span><button class="btn" onclick="infoDlg.close()">Închide</button></div></dialog>

<dialog id="searchDlg"><h3>🔍 Caută în mesaje</h3>
<input id="qmsg" placeholder="Caută...">
<div id="sres" style="max-height:300px;overflow:auto;margin-top:10px"></div>
<div style="display:flex;margin-top:12px"><span class="sp"></span><button class="ghost" onclick="searchDlg.close()">Închide</button></div></dialog>

<script>
const $=s=>document.querySelector(s);
let prevU=-1,ac,me,room,last=0,timer,mode,sel=new Set(),n=0,busy=false,replyTo=null,editing=null,mediaRec=null,recChunks=[],recTimer=null;

// Fix tastatură - forțează input dacă policy corporate blochează
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
    const f=t.form;if(f)f.requestSubmit();
    e.preventDefault();
  }
},true);

const savedTheme=localStorage.getItem('theme');
if(savedTheme==='dark'||(!savedTheme&&matchMedia('(prefers-color-scheme:dark)').matches)){document.documentElement.dataset.theme='dark';$('#theme').textContent='☀️'}
$('#theme').onclick=()=>{const d=document.documentElement.dataset.theme==='dark';document.documentElement.dataset.theme=d?'':'dark';$('#theme').textContent=d?'🌙':'☀️';localStorage.setItem('theme',d?'light':'dark')};

async function api(a,body,qs=''){const opt=body?{method:'POST',headers:{'X-Requested-With':'fetch','Content-Type':'application/json'},body:JSON.stringify(body)}:{};const r=await fetch('api.php?a='+a+qs,opt);const j=await r.json();if(r.status===401&&!['login','register'].includes(a)){auth();throw 0}if(!r.ok)throw j.error||'Eroare';return j}
function auth(){clearInterval(timer);$('#app').classList.remove('on');$('#auth').style.display='grid'}
async function enter(){me=await api('me');$('#auth').style.display='none';$('#app').classList.add('on');$('#me').textContent=me.username;$('#meAv').textContent=me.username[0].toUpperCase();loadRooms();clearInterval(timer);timer=setInterval(tick,2000)}
async function sign(a){try{await api(a,{username:$('#u').value,password:$('#p').value});enter()}catch(e){$('#err').textContent=e}}
$('#login').onclick=()=>sign('login');$('#reg').onclick=()=>sign('register');
$('#p').onkeydown=e=>e.key==='Enter'&&sign('login');
$('#out').onclick=async()=>{await api('logout',{});room=null;auth()};

function fmtTime(t){if(!t)return'';const d=new Date(t.replace(' ','T')+'Z'),now=new Date();const diff=(now-d)/1000;if(diff<60)return'acum';if(diff<3600)return Math.floor(diff/60)+'m';if(diff<86400)return d.toLocaleTimeString([],{hour:'2-digit',minute:'2-digit'});return d.toLocaleDateString([],{day:'2-digit',month:'2-digit'})}
function color(name){let h=0;for(const c of name)h=((h<<5)-h)+c.charCodeAt(0);const p=['#6c5ce7','#00b894','#e17055','#0984e3','#d63031','#fdcb6e','#e84393','#00cec9','#a29bfe','#55efc4'];return p[Math.abs(h)%p.length]}

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
  room=r;last=0;replyTo=null;editing=null;
  $('#msgs').innerHTML='';$('#title').textContent=r.name;$('#sub').textContent='';
  $('#tAv').textContent=r.is_group==1?'👥':(r.name||'?')[0].toUpperCase();
  $('#tAv').style.background='linear-gradient(135deg,'+(r.color||color(r.name||'?'))+',#a29bfe)';
  $('#f').hidden=false;$('#add').hidden=r.is_group!=1;$('#info').hidden=r.is_group!=1;
  $('#app').classList.add('open');$('#rbar').classList.remove('on');
  $('#t').focus();tick();loadRooms()
}
$('#bk').onclick=()=>{room=null;$('#app').classList.remove('open')};

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
      const d=document.createElement('div');
      const mine=x.user_id==me.id;
      d.className='m'+(mine?' me':'')+(x.deleted?' del':'');
      d.dataset.id=x.id;
      if(!mine&&room.is_group==1){const i=document.createElement('div');i.className='name';i.textContent=x.username;i.style.color=color(x.username);d.append(i)}
      if(x.reply_id&&x.reply_body){const rp=document.createElement('div');rp.className='reply';const rn=document.createElement('b');rn.textContent=(x.reply_user||'?')+': ';rp.append(rn,document.createTextNode(x.reply_body.slice(0,80)));d.append(rp)}
      if(x.pinned){const pin=document.createElement('div');pin.className='pinned';pin.textContent='📌';d.append(pin)}
      if(x.deleted){d.append(document.createTextNode('🚫 mesaj șters'))}
      else if(x.type==='image'&&x.file_url){const img=document.createElement('img');img.src=x.file_url;img.loading='lazy';img.onclick=()=>window.open(x.file_url,'_blank');d.append(img)}
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
        const rb=document.createElement('button');rb.textContent='↩';rb.onclick=e=>{e.stopPropagation();setReply(x)};acts.append(rb);
        const re=document.createElement('button');re.textContent='😊';re.onclick=e=>{e.stopPropagation();reactQuick(x)};acts.append(re);
        const pb=document.createElement('button');pb.textContent='📌';pb.onclick=e=>{e.stopPropagation();api('pin',{id:+x.id}).then(reloadMsgs)};acts.append(pb);
        if(mine){const eb=document.createElement('button');eb.textContent='✎';eb.onclick=e=>{e.stopPropagation();startEdit(x)};acts.append(eb);
          const db=document.createElement('button');db.textContent='🗑';db.onclick=e=>{e.stopPropagation();delMsg(x.id)};acts.append(db)}
        d.append(acts);
      }
      b.append(d);
    });
    if(!init&&m.some(x=>x.user_id!=me.id))beep();
    if(near||init)b.scrollTop=b.scrollHeight;
  }catch(e){}finally{busy=false}
}
function reactQuick(x){const e=prompt('Reacție (❤️ 😂 👍 😮 😢 🔥):','❤️');if(e)api('react',{id:+x.id,emoji:e}).then(reloadMsgs)}
function setReply(x){replyTo=x;$('#rtxt').textContent=(x.username||'')+': '+(x.body||'').slice(0,60);$('#rbar').classList.add('on');$('#t').focus()}
$('#rcancel').onclick=()=>{replyTo=null;$('#rbar').classList.remove('on')};
function startEdit(x){editing=x.id;$('#t').value=x.body;$('#t').focus()}
async function delMsg(id){if(!confirm('Ștergi?'))return;try{await api('del',{id});reloadMsgs()}catch(e){alert(e)}}
async function reloadMsgs(){last=0;$('#msgs').innerHTML='';await tick()}

$('#f').onsubmit=async e=>{
  e.preventDefault();
  const t=$('#t').value.trim();if(!t||!room)return;
  try{
    if(editing){await api('edit',{id:editing,body:t});editing=null}
    else{await api('send',{room_id:room.id,body:t,reply_id:replyTo?+replyTo.id:0})}
    $('#t').value='';replyTo=null;$('#rbar').classList.remove('on');reloadMsgs()
  }catch(x){alert(x)}
};
$('#t').onkeydown=e=>{if(e.key==='Enter'&&!e.shiftKey){e.preventDefault();$('#f').requestSubmit()}};
$('#t').oninput=()=>{$('#t').style.height='auto';$('#t').style.height=Math.min($('#t').scrollHeight,120)+'px';if(room&&Date.now()-tt>2500){tt=Date.now();api('typing',{room_id:room.id}).catch(()=>{})}};
let tt=0;

// Emoji
const EMOJIS='😀 😃 😄 😁 😆 😅 🤣 😂 🙂 🙃 😉 😊 😇 🥰 😍 🤩 😘 😗 😚 😙 😋 😛 😜 🤪 😝 🤑 🤗 🤭 🤫 🤔 🤐 🤨 😐 😑 😶 😏 😒 🙄 😬 🤥 😌 😔 😪 🤤 😴 😷 🤒 🤕 🤢 🤮 🥵 🥶 😵 🤯 🤠 🥳 😎 🤓 🧐 😕 😟 🙁 😮 😯 😲 😳 🥺 😦 😧 😨 😰 😥 😢 😭 😱 😖 😣 😞 😓 😩 😫 🥱 😤 😡 😠 🤬 😈 👿 💀 💩 👻 👽 🤖 😺 ❤️ 🧡 💛 💚 💙 💜 🖤 🤍 💔 ❣️ 💕 💞 💓 💗 💖 💘 💝 👍 👎 👏 🙌 🤝 🙏 ✌️ 🤞 🤟 🤘 👌 👈 👉 👆 👇 ✋ 🔥 ⭐ ✨ 🎉 🎊 🎁 🎈 💯 ✅ ❌ ⚡ 💥 🚀 🎯 🏆 🥇 🎵 🎶 ☕ 🍕 🍔 🍟 🍰 🍺 🍻'.split(' ');
$('#emojis').innerHTML=EMOJIS.map(e=>'<span>'+e+'</span>').join('');
$('#emoBtn').onclick=e=>{e.stopPropagation();$('#emojis').classList.toggle('on')};
$('#emojis').onclick=e=>{if(e.target.tagName==='SPAN'){$('#t').value+=$('#t').value?' '+e.target.textContent:e.target.textContent;$('#t').focus()}};
document.addEventListener('click',e=>{if(!e.target.closest('#emojis')&&e.target.id!=='emoBtn')$('#emojis').classList.remove('on')});

// Upload
$('#fileBtn').onclick=()=>$('#fileInput').click();
$('#fileInput').onchange=async()=>{
  const f=$('#fileInput').files[0];if(!f||!room)return;
  const fd=new FormData();fd.append('f',f);fd.append('room_id',room.id);
  try{
    const r=await fetch('api.php?a=upload',{method:'POST',headers:{'X-Requested-With':'fetch'},body:fd});
    const j=await r.json();if(!r.ok)throw j.error||'Eroare';
    await api('send',{room_id:room.id,body:j.name,type:j.type,file_url:j.url,file_name:j.name});
    reloadMsgs()
  }catch(e){alert(e)}
  $('#fileInput').value=''
};

// Voice
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
      try{const r=await fetch('api.php?a=upload',{method:'POST',headers:{'X-Requested-With':'fetch'},body:fd});const j=await r.json();if(!r.ok)throw j.error;await api('send',{room_id:room.id,body:'🎙️ Voice',type:'audio',file_url:j.url,file_name:j.name});reloadMsgs()}catch(e){alert(e)}
    };
    mediaRec.start();$('#voiceBtn').classList.add('rec');
    recTimer=setTimeout(()=>{if(mediaRec.state==='recording')mediaRec.stop();$('#voiceBtn').classList.remove('rec')},60000);
  }catch(e){alert('Nu pot accesa microfonul: '+e.message)}
};

// Search în mesaje
$('#srchBtn').onclick=()=>{if(!room)return;$('#qmsg').value='';$('#sres').innerHTML='';$('#searchDlg').showModal();setTimeout(()=>$('#qmsg').focus(),100)};
$('#qmsg').oninput=async()=>{
  const q=$('#qmsg').value.trim();if(q.length<2){$('#sres').innerHTML='';return}
  try{const r=await api('search',0,'&room='+room.id+'&q='+encodeURIComponent(q));
    $('#sres').innerHTML=r.map(m=>'<div style="padding:8px;border-bottom:1px solid var(--bd)"><b style="color:'+color(m.username)+'">'+m.username+'</b> <small style="color:var(--mut)">'+fmtTime(m.created_at)+'</small><div>'+m.body.replace(/</g,'&lt;')+'</div></div>').join('')||'<p style="color:var(--mut)">Nimic găsit</p>';
  }catch(e){}
};

// Export
$('#expBtn').onclick=()=>{if(!room)return;window.open('api.php?a=export&room='+room.id,'_blank')};

// Dialog
function dlg(m){mode=m;sel.clear();$('#dt').textContent=m=='dm'?'💬 Chat nou':m=='grp'?'👥 Grup nou':'➕ Adaugă membri';$('#gn').style.display=m=='grp'?'':'none';$('#gn').value='';$('#ok').style.display=m=='dm'?'none':'';$('#ok').textContent=m=='grp'?'Creează':'Adaugă';$('#q').value='';find();$('#dlg').showModal()}
async function find(){const l=await api('users',0,'&q='+encodeURIComponent($('#q').value));const b=$('#ul');b.innerHTML='';if(!l.length){b.innerHTML='<p style="padding:14px;color:var(--mut);text-align:center">Niciun utilizator</p>';return}l.forEach(u=>{const d=document.createElement('div');d.className='u'+(sel.has(u.username)?' sel':'');const av=document.createElement('div');av.className='av sm';av.style.background='linear-gradient(135deg,'+color(u.username)+','+color(u.username)+'cc)';av.textContent=u.username[0].toUpperCase();d.append(av,document.createTextNode(u.username));d.onclick=async()=>{if(mode=='dm'){const r=await api('dm',{user_id:u.id});$('#dlg').close();await loadRooms();openRoom({id:r.id,name:u.username,is_group:0})}else{sel.has(u.username)?sel.delete(u.username):sel.add(u.username);d.classList.toggle('sel')}};b.append(d)})}
$('#q').oninput=find;$('#nd').onclick=()=>dlg('dm');$('#ng').onclick=()=>dlg('grp');$('#add').onclick=()=>dlg('add');$('#cx').onclick=()=>$('#dlg').close();
$('#ok').onclick=async()=>{try{if(mode=='grp'){const name=$('#gn').value.trim();if(!name){alert('Dă nume grupului');return}const r=await api('group',{name,members:[...sel]});$('#dlg').close();await loadRooms();openRoom({id:r.id,name,is_group:1,color:color(name),memcount:sel.size+1})}else{for(const u of sel)await api('add',{room_id:room.id,username:u});$('#dlg').close();loadRooms()}}catch(e){alert(e)}};

$('#info').onclick=async()=>{const l=await api('members',0,'&room='+room.id);$('#mlist').innerHTML=l.map(u=>{const c=color(u.username);return '<div class="u"><div class="av sm" style="background:linear-gradient(135deg,'+c+','+c+'cc)">'+u.username[0].toUpperCase()+'</div>'+u.username+(u.online?' <span style="color:#00b894;font-size:11px">● online</span>':'')+'</div>'}).join('');$('#infoDlg').showModal()};

function status(R){$('#sub').textContent=R.typing.length?R.typing.join(', ')+' scrie...':(R.online.length?(room.is_group==1?R.online.length+' online':'● online'):'');$('#sub').style.color=R.typing.length?'var(--ac)':(R.online.length?'#00b894':'var(--mut)')}

document.addEventListener('click',()=>{try{ac=ac||new(window.AudioContext||window.webkitAudioContext)();ac.resume()}catch(e){}},{once:true});
function beep(){if(!ac)return;try{const o=ac.createOscillator(),g=ac.createGain();o.connect(g);g.connect(ac.destination);o.type='sine';o.frequency.setValueAtTime(660,ac.currentTime);o.frequency.exponentialRampToValueAtTime(880,ac.currentTime+.1);g.gain.setValueAtTime(.06,ac.currentTime);g.gain.exponentialRampToValueAtTime(.001,ac.currentTime+.2);o.start();o.stop(ac.currentTime+.2)}catch(e){}}

enter().catch(auth);
</script></body></html>
EOF_HTML

# ============ MIGRARE DB ============
M() { docker compose exec -T mysql sh -c 'mysql -uroot -p"$MYSQL_ROOT_PASSWORD" chatdb' 2>/dev/null; }

echo "ALTER TABLE messages ADD COLUMN type VARCHAR(20) DEFAULT 'text', ADD COLUMN file_url VARCHAR(255) NULL, ADD COLUMN file_name VARCHAR(255) NULL, ADD COLUMN pinned TINYINT(1) DEFAULT 0;" | M 2>/dev/null || echo "→ Coloane messages deja existente"

echo "CREATE TABLE IF NOT EXISTS reactions (id INT AUTO_INCREMENT PRIMARY KEY, message_id INT NOT NULL, user_id INT NOT NULL, emoji VARCHAR(10) NOT NULL, created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP, UNIQUE KEY uniq_react (message_id, user_id, emoji), FOREIGN KEY (message_id) REFERENCES messages(id) ON DELETE CASCADE, FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE);" | M

echo "DESCRIBE messages;" | M | head -20
echo "---"
echo "SHOW TABLES;" | M

# Restart
docker compose restart
docker compose ps

echo ""
echo "✅ UPDATE v4 COMPLET!"
echo "Deschide: http://10.130.70.55:8080 (Ctrl+Shift+R)"
