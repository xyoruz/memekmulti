#!/bin/bash
# bot/lib/keyboard.sh - inline keyboard Telegram
KB_MAIN='{"inline_keyboard":[[{"text":"🔹 VLESS","callback_data":"ls:vless"},{"text":"🔹 VMess","callback_data":"ls:vmess"},{"text":"🔹 Trojan","callback_data":"ls:trojan"}],[{"text":"📊 Info Server","callback_data":"info"},{"text":"🧹 Hapus Expired","callback_data":"exp"}],[{"text":"➕ Cara Buat Akun","callback_data":"help"}]]}'

kb_users(){ # proto
  { grep "^$1|" "$DB" || true; } | while IFS='|' read -r _ u _ e _; do
    jq -cn --arg t "$u ($e)" --arg d "u:$1:$u" '{text:$t,callback_data:$d}'
  done | jq -cs '(if length==0 then [] else [ _nwise(2) ] end) + [[{text:"⬅️ Menu",callback_data:"menu"}]] | {inline_keyboard:.}'
}
kb_user(){ # proto user
  jq -cn --arg p "$1" --arg u "$2" '{inline_keyboard:[
    [{text:"📄 Detail",callback_data:("d:"+$p+":"+$u)},{text:"⏫ +30 hari",callback_data:("r:"+$p+":"+$u)}],
    [{text:"♻️ Reset kuota",callback_data:("z:"+$p+":"+$u)},{text:"🗑 Hapus",callback_data:("x:"+$p+":"+$u)}],
    [{text:"⬅️ Kembali",callback_data:("ls:"+$p)}]]}'
}
kb_confirm(){ # proto user
  jq -cn --arg p "$1" --arg u "$2" '{inline_keyboard:[[{text:"✅ Ya, hapus",callback_data:("xy:"+$p+":"+$u)},{text:"❌ Batal",callback_data:("u:"+$p+":"+$u)}]]}'
}
