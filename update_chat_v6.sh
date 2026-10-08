#!/bin/bash
set -e
cd /home/admin/chatapp

# Backup
mkdir -p backups
cp html/api.php backups/api.php.v6bak-$(date +%s) 2>/dev/null || true
cp html/index.html backups/index.html.v6bak-$(date +%s) 2>/dev/null || true

echo "📦 Backup făcut. Aplic migrarea DB..."

# ============ MIGRARE DB ============
M() { docker compose exec -T mysql sh -c 'mysql -uroot -p"$MYSQL_ROOT_PASSWORD" chatdb' 2>/dev/null; }

echo "ALTER TABLE users ADD COLUMN avatar VARCHAR(255) DEFAULT NULL;" | M || echo "→ avatar deja existent"
echo "ALTER TABLE users ADD COLUMN bio TEXT DEFAULT NULL;" | M || echo "→ bio deja existent"
echo "ALTER TABLE users ADD COLUMN status VARCHAR(60) DEFAULT NULL;" | M || echo "→ status deja existent"
echo "ALTER TABLE users ADD COLUMN created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP;" | M || echo "→ created_at deja existent"

echo "=== Verificare users ==="
echo "DESCRIBE users;" | M

# ============ API.PHP (adaugă endpoints profil) ============
echo "🔧 Actualizez api.php..."

# Adaugă endpoint-uri profil dacă nu există
if ! grep -q "case 'profile_get'" html/api.php; then
  # Inserează case-uri noi înainte de "out(['error'=>'unknown'],404);"
  python3 <<'PYEOF'
f='html/api.php'
s=open(f).read()

new_cases = """case 'profile_get':
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
 if(!$uid)out(['error'=>'auth'],401);
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
"""
s=s.replace("out(['error'=>'unknown'],404);", new_cases + "out(['error'=>'unknown'],404);")
open(f,'w').write(s)
print('✅ api.php actualizat')
PYEOF
fi

# Crează folderul avatars
mkdir -p html/uploads/avatars
chmod 755 html/uploads/avatars

docker compose exec -T php php -l /usr/share/nginx/html/api.php && echo "✅ PHP valid"

echo ""
echo "🎉 Migrare DB + API complete!"
echo "Acum rulează: bash update_chat_v6_ui.sh"
