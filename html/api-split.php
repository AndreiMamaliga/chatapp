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
$uid=$_SESSION['uid']??0;
if(!$uid)out(['error'=>'auth'],401);

function member($rid){global $uid;return q('SELECT 1 FROM room_members WHERE room_id=? AND user_id=?',[$rid,$uid])->fetch();}

switch($a){
case 'add_expense':
 $r=(int)($in['room_id']??0);
 $paid_by=(int)($in['paid_by']??0);
 $amount=(float)($in['amount']??0);
 $desc=trim($in['description']??'');
 $split_with=(array)($in['split_with']??[]);

 if(!member($r)||!$amount||!$desc||empty($split_with))out(['error'=>'Date invalide'],400);

 // 1. Adaugă cheltuiala
 q('INSERT INTO expenses(room_id,paid_by,amount,description) VALUES(?,?,?,?)',[$r,$paid_by,$amount,$desc]);
 $eid=$pdo->lastInsertId();

 // 2. Împarte suma la membrii selectați
 $per_person=round($amount / count($split_with), 2);
 foreach($split_with as $u){ q('INSERT INTO expense_splits(expense_id,user_id,amount_owed) VALUES(?,?,?)',[$eid,$u,$per_person]); }

 // 3. Trimite un mesaj automat în chat (opțional, dar frumos)
 $u_name=q('SELECT username FROM users WHERE id=?',[$uid])->fetchColumn();
 q('INSERT INTO messages(room_id,user_id,body,type) VALUES(?,?,?,?)',[$r,$uid,"💰 $desc — $amount MDL","text"]);

 out(['ok'=>1,'expense_id'=>$eid]);

case 'settle_up':
 $r=(int)($in['room_id']??0);
 $from=(int)($in['from_user']??0);
 $to=(int)($in['to_user']??0);
 $amount=(float)($in['amount']??0);

 if(!member($r)||!$from||!$to||!$amount)out(['error'=>'Date invalide'],400);

 q('INSERT INTO settlements(room_id,from_user,to_user,amount) VALUES(?,?,?,?)',[$r,$from,$to,$amount]);

 // Trimite mesaj automat în chat
 $from_name=q('SELECT username FROM users WHERE id=?',[$from])->fetchColumn();
 $to_name=q('SELECT username FROM users WHERE id=?',[$to])->fetchColumn();
 q('INSERT INTO messages(room_id,user_id,body,type) VALUES(?,?,?,?)',[$r,$uid,"💸 $from_name a decontat $amount MDL către $to_name","text"]);

 out(['ok'=>1]);
case 'get_expenses':
 $r=(int)($_GET['room']??0);
 if(!member($r))out(['error'=>'Interzis'],403);
 $ms=q('SELECT e.id,e.amount,e.description,e.created_at,u.username as paid_by_name FROM expenses e JOIN users u ON u.id=e.paid_by WHERE e.room_id=? ORDER BY e.id DESC',[$r])->fetchAll();
 out($ms);

case 'get_balances':
 $r=(int)($_GET['room']??0);
 if(!member($r))out(['error'=>'Interzis'],403);

 // 1. Cine a plătit cât
 $paid=q('SELECT paid_by as uid, SUM(amount) as total FROM expenses WHERE room_id=? GROUP BY paid_by',[$r])->fetchAll();
 $balances=[];
 foreach($paid as $p){ $balances[$p['uid']] = (float)$p['total']; }

 // 2. Cine datorează cât
 $owed=q('SELECT s.user_id as uid, SUM(s.amount_owed) as total FROM expense_splits s JOIN expenses e ON e.id=s.expense_id WHERE e.room_id=? GROUP BY s.user_id',[$r])->fetchAll();
 foreach($owed as $o){
   if(!isset($balances[$o['uid']])) $balances[$o['uid']] = 0;
   $balances[$o['uid']] -= (float)$o['total'];
 }

 // 3. Scădem decontările din balanțe
 $sent=q('SELECT from_user as uid, SUM(amount) as total FROM settlements WHERE room_id=? GROUP BY from_user',[$r])->fetchAll();
 foreach($sent as $s){ if(isset($balances[$s['uid']])) $balances[$s['uid']] += (float)$s['total']; }

 $received=q('SELECT to_user as uid, SUM(amount) as total FROM settlements WHERE room_id=? GROUP BY to_user',[$r])->fetchAll();
 foreach($received as $s){ if(isset($balances[$s['uid']])) $balances[$s['uid']] -= (float)$s['total']; }

 // 4. Algoritmul de simplificare a datoriilor
 $debtors=[]; $creditors=[];
 foreach($balances as $uid=>$bal){
   if($bal < -0.01) $debtors[] = ['uid'=>$uid, 'bal'=>abs($bal)];
   elseif($bal > 0.01) $creditors[] = ['uid'=>$uid, 'bal'=>$bal];
 }

 $transactions=[];
 while(!empty($debtors) && !empty($creditors)){
   usort($debtors, function($a,$b){ return $b['bal'] <=> $a['bal']; });
   usort($creditors, function($a,$b){ return $b['bal'] <=> $a['bal']; });

   $d = &$debtors[0]; $c = &$creditors[0];
   $min = min($d['bal'], $c['bal']);

   $transactions[] = ['from'=>$d['uid'], 'to'=>$c['uid'], 'amount'=>round($min,2)];

   $d['bal'] -= $min; $c['bal'] -= $min;
   if($d['bal'] < 0.01) array_shift($debtors);
   if($c['bal'] < 0.01) array_shift($creditors);
 }

 // Adăugăm numele pentru frumusețe
 foreach($transactions as &$t){
   $t['from_name']=q('SELECT username FROM users WHERE id=?',[$t['from']])->fetchColumn();
   $t['to_name']=q('SELECT username FROM users WHERE id=?',[$t['to']])->fetchColumn();
 }

 out(['balances'=>$balances, 'transactions'=>$transactions]);
}
out(['error'=>'unknown'],404);
