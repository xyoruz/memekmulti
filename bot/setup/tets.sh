#!/bin/bash
# bot/setup/test.sh - kirim pesan tes ke admin
tg_test(){
  need_token || return
  [[ -n "$TG_ADMIN" ]] || { err "ID admin belum diatur."; return; }
  local a r
  for a in ${TG_ADMIN//,/ }; do
    r=$(curl -s --max-time 15 "https://api.telegram.org/bot$TG_TOKEN/sendMessage" \
        --data-urlencode "chat_id=$a" --data-urlencode "text=✅ Tes dari $DOMAIN")
    jq -e '.ok==true' <<<"$r" >/dev/null 2>&1 && ok "Terkirim ke $a" || err "Gagal kirim ke $a (sudah /start bot?)"
  done
}
