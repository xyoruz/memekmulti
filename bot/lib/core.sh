#!/bin/bash
# bot/lib/core.sh - konfigurasi, API Telegram, kirim pesan, cek admin, lock (di-source oleh bot.sh)
CONF=$XM_DIR/telegram.conf
[[ -f "$CONF" ]] && . "$CONF"
[[ -n "${TG_TOKEN:-}" ]] || { echo "TG_TOKEN belum diatur"; exit 1; }
API="https://api.telegram.org/bot$TG_TOKEN"
LOCK=/var/run/xm-db.lock

esc(){ sed -e 's/&/\&amp;/g' -e 's/</\&lt;/g' -e 's/>/\&gt;/g'; }

send(){ # chat teks [keyboard_json]
  local a=(-s --max-time 30 "$API/sendMessage" --data-urlencode "chat_id=$1"
           --data-urlencode "text=$2" -d parse_mode=HTML -d disable_web_page_preview=true)
  [[ -n "$3" ]] && a+=(--data-urlencode "reply_markup=$3")
  curl "${a[@]}" >/dev/null
}
answer(){ curl -s --max-time 10 "$API/answerCallbackQuery" --data-urlencode "callback_query_id=$1" >/dev/null; }

is_admin(){ local a; for a in ${TG_ADMIN//,/ }; do [[ "$a" == "$1" ]] && return 0; done; return 1; }

# aksi yang mengubah data dijalankan dengan lock
locked(){ ( flock 9; "$@" ) 9>"$LOCK"; }
