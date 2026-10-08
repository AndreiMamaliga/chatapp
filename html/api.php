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
 if(!$r){q('INSERT INTO rooms(is_group,created_by) VALUES(0,?)',[$uid]);$r=$pdo->lastInsertId();q('INSERT INTO room_members(room_id,user_id) VALUES(?,?),(?,?)',[$r,$uid,$r,$o]);}
 out(['id'=>$r]);
case 'group':
 $n=trim($in['name']??'');
 if($n===''||mb_strlen($n)>40)out(['error'=>'Nume grup invalid'],400);
 q('INSERT INTO rooms(is_group,name,created_by) VALUES(1,?,?)',[$n,$uid]);$r=$pdo->lastInsertId();
 q('INSERT INTO room_members(room_id,user_id) VALUES(?,?)',[$r,$uid]);
 foreach(array_slice((array)($in['members']??[]),0,50) as $m){$i=q('SELECT id FROM users WHERE username=?',[$m])->fetchColumn();if($i)q('INSERT IGNORE INTO room_members(room_id,user_id) VALUES(?,?)',[$r,$i]);}
 out(['id'=>$r]);
case 'add':
 $r=(int)($in['room_id']??0);
 if(!member($r)||!q('SELECT 1 FROM rooms WHERE id=? AND is_group=1',[$r])->fetch())out(['error'=>'Interzis'],403);
 $i=q('SELECT id FROM users WHERE username=?',[trim($in['username']??'')])->fetchColumn();
 if(!$i)out(['error'=>'User inexistent'],404);
 q('INSERT IGNORE INTO room_members(room_id,user_id) VALUES(?,?)',[$r,$i]);out(['ok'=>1]);
case 'members':
 $r=(int)($_GET['room']??0);if(!member($r))out(['error'=>'Interzis'],403);
 out(q('SELECT u.id,u.username,u.last_seen>NOW()-INTERVAL 30 SECOND online FROM room_members x JOIN users u ON u.id=x.user_id WHERE x.room_id=? ORDER BY online DESC,u.username',[$r])->fetchAll());
case 'msgs':
 $r=(int)($_GET['room']??0);if(!member($r))out(['error'=>'Interzis'],403);
 $ms=q('SELECT * FROM (SELECT m.id,m.user_id,u.username,m.body,m.type,m.file_url,m.file_name,m.created_at,m.edited,m.deleted,m.reply_id,m.pinned,m.view_once,(SELECT COUNT(*) FROM room_members x WHERE x.room_id=m.room_id AND x.user_id<>m.user_id AND x.last_read>=m.id) read_by,(SELECT COUNT(*) FROM room_members x WHERE x.room_id=m.room_id AND x.user_id<>m.user_id) others_total,rm.body reply_body,ru.username reply_user,
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
 $r=(int)($in['room_id']??0);$b=trim($in['body']??'');$rep=(int)($in['reply_id']??0)?:null;$ty=$in['type']??'text';$fu=$in['file_url']??null;$fn=$in["file_name"]??null;$vo=!empty($in["view_once"])?1:0;
 if(!member($r))out(['error'=>'Interzis'],403);
 if($ty==='text'&&($b===''||mb_strlen($b)>2000))out(['error'=>'Mesaj invalid'],400);
 $cnt=q('SELECT COUNT(*) FROM messages WHERE user_id=? AND created_at>NOW()-INTERVAL 30 SECOND',[$uid])->fetchColumn();
 if($cnt>20)out(['error'=>'Prea rapid! Așteaptă puțin'],429);
 q('INSERT INTO messages(room_id,user_id,body,type,file_url,file_name,reply_id,view_once) VALUES(?,?,?,?,?,?,?,?)',[$r,$uid,$b,$ty,$fu,$fn,$rep,$vo]);out(['id'=>$pdo->lastInsertId()]);
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
 $allow=['❤️','🧡','💛','💚','💙','💜','🖤','🤍','🤎','💔','❣️','💕','💞','💓','💗','💖','💘','💝','💟','♥️','💋','💌','😂','🤣','😅','😊','😍','🥰','😘','😉','😎','🤔','😮','😯','😲','😳','🥺','😢','😭','😱','😡','🤬','👍','👎','👏','🙌','🤝','🙏','✌️','🤞','🤟','🤘','👌','✊','👊','💪','🙋','🔥','💯','✅','❌','⭐','🌟','✨','⚡','💥','🎉','🎊','🎁','🎈','🚀','🎯','🏆','🥇','👑','💎','🎮','🎲','🍕','🍔','🍟','☕','🍺','🍻','🥂','🍰','🎂','🐶','🐱','🦊','🐼','🐨','🦁','🐯','⚽','🏀','🎾','🚗','🏠','🌈','☀️','🌙','⏰','📎','📍','📌','🔔','💬','💭'];
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
case 'profile_get':
 $d=q('SELECT id,username,avatar,bio,status,created_at FROM users WHERE id=?',[$uid])->fetch();
 $d['messages']=(int)q('SELECT COUNT(*) FROM messages WHERE user_id=? AND deleted=0',[$uid])->fetchColumn();
 $d['groups']=(int)q('SELECT COUNT(*) FROM room_members rm JOIN rooms r ON r.id=rm.room_id WHERE rm.user_id=? AND r.is_group=1',[$uid])->fetchColumn();
 $d['days']=max(1,(int)q('SELECT DATEDIFF(NOW(),COALESCE(created_at,NOW())) FROM users WHERE id=?',[$uid])->fetchColumn());
 out($d);
case 'profile_set':
 if(isset($in['status']))q('UPDATE users SET status=? WHERE id=?',[mb_substr(trim($in['status']),0,60),$uid]);
 if(isset($in['bio']))q('UPDATE users SET bio=? WHERE id=?',[mb_substr(trim($in['bio']),0,300),$uid]);
 out(['ok'=>1]);
case 'profile_avatar':
 if(!isset($_FILES['f'])||$_FILES['f']['error'])out(['error'=>'Upload eșuat'],400);
 $f=$_FILES['f'];
 if($f['size']>2097152)out(['error'=>'Avatar max 2MB'],400);
 $ext=strtolower(pathinfo($f['name'],PATHINFO_EXTENSION));
 if(!in_array($ext,['jpg','jpeg','png','gif','webp']))out(['error'=>'Doar imagini'],400);
 $safe='av-'.$uid.'-'.bin2hex(random_bytes(6)).'.'.$ext;
 $dir=__DIR__.'/uploads/avatars/';if(!is_dir($dir))mkdir($dir,0755,true);
 if(!move_uploaded_file($f['tmp_name'],$dir.$safe))out(['error'=>'Salvare eșuată'],500);
 $url='uploads/avatars/'.$safe;
 q('UPDATE users SET avatar=? WHERE id=?',[$url,$uid]);
 out(['url'=>$url]);
case 'user_profile':
 $oid=(int)($_GET['id']??0);
 if(!$oid)out(['error'=>'ID lipsă'],400);
 $d=q('SELECT id,username,avatar,bio,status,last_seen FROM users WHERE id=?',[$oid])->fetch();
 if(!$d)out(['error'=>'User inexistent'],404);
 $d['online']=$d['last_seen']>date('Y-m-d H:i:s',time()-30);
 out($d);
case 'view_once_read':
 $id=(int)($in['id']??0);
 $m=q('SELECT room_id,view_once FROM messages WHERE id=?',[$id])->fetch();
 if(!$m||!member($m['room_id']))out(['error'=>'Interzis'],403);
 q('INSERT IGNORE INTO message_views(message_id,user_id) VALUES(?,?)',[$id,$uid]);
 q('UPDATE messages SET body="",file_url=NULL WHERE id=?',[$id]);
 out(['ok'=>1]);
case 'poll_create':
 $r=(int)($in['room_id']??0);$ques=trim($in['question']??'');$opts=(array)($in['options']??[]);
 if(!member($r)||$ques===''||count($opts)<2||count($opts)>10)out(['error'=>'Date invalide'],400);
 q('INSERT INTO messages(room_id,user_id,body,type) VALUES(?,?,?,?)',[$r,$uid,$ques,'poll']);
 $mid=$pdo->lastInsertId();
 q('INSERT INTO polls(message_id,question,options,multiple,anonymous) VALUES(?,?,?,?,?)',[$mid,$ques,json_encode(array_values($opts),JSON_UNESCAPED_UNICODE),!empty($in['multiple'])?1:0,!empty($in['anonymous'])?1:0]);
 out(['id'=>$mid]);
case 'poll_vote':
 $mid=(int)($in['message_id']??0);$idx=(int)($in['option_idx']??-1);
 $p=q('SELECT p.id,p.options,p.multiple FROM polls p JOIN messages m ON m.id=p.message_id WHERE p.message_id=?',[$mid])->fetch();
 if(!$p||$idx<0)out(['error'=>'Sondaj invalid'],400);
 $m=q('SELECT room_id FROM messages WHERE id=?',[$mid])->fetch();
 if(!member($m['room_id']))out(['error'=>'Interzis'],403);
 if($p['multiple']){
   $ex=q('SELECT id FROM poll_votes WHERE poll_id=? AND user_id=? AND option_idx=?',[$p['id'],$uid,$idx])->fetch();
   if($ex)q('DELETE FROM poll_votes WHERE id=?',[$ex['id']]);
   else q('INSERT INTO poll_votes(poll_id,user_id,option_idx) VALUES(?,?,?)',[$p['id'],$uid,$idx]);
 } else {
   q('DELETE FROM poll_votes WHERE poll_id=? AND user_id=?',[$p['id'],$uid]);
   q('INSERT INTO poll_votes(poll_id,user_id,option_idx) VALUES(?,?,?)',[$p['id'],$uid,$idx]);
 }
 out(['ok'=>1]);
case 'poll_results':
 $mid=(int)($_GET['message_id']??0);
 $p=q('SELECT id,options,multiple,anonymous FROM polls WHERE message_id=?',[$mid])->fetch();
 if(!$p)out(['error'=>'Lipsă'],404);
 $r=q('SELECT option_idx,COUNT(*) cnt FROM poll_votes WHERE poll_id=? GROUP BY option_idx',[$p['id']])->fetchAll();
 $votes=[];foreach($r as $row)$votes[(int)$row['option_idx']]=(int)$row['cnt'];
 $my=q('SELECT option_idx FROM poll_votes WHERE poll_id=? AND user_id=?',[$p['id'],$uid])->fetchAll(PDO::FETCH_COLUMN);
 out(['options'=>json_decode($p['options'],true),'votes'=>$votes,'my'=>array_map('intval',$my),'multiple'=>(int)$p['multiple'],'anonymous'=>(int)$p['anonymous']]);
case 'password_change':
 $old=$in['old_password']??'';$new=$in['new_password']??'';
 if(strlen($new)<6)out(['error'=>'Parola noua minim 6 caractere'],400);
 $r=q('SELECT password FROM users WHERE id=?',[$uid])->fetch();
 if(!$r||!password_verify($old,$r['password']))out(['error'=>'Parola veche incorecta'],401);
 q('UPDATE users SET password=? WHERE id=?',[password_hash($new,PASSWORD_DEFAULT),$uid]);
 out(['ok'=>1]);
}
out(['error'=>'unknown'],404);
