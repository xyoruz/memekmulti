#!/bin/bash
# bot/handler/update.sh - satu update masuk: cek admin lalu teruskan ke router
handle(){ # satu update (JSON)
  local chat from text data cbid
  eval "$(jq -r '@sh "chat=\(.message.chat.id // .callback_query.message.chat.id // "") from=\(.message.from.id // .callback_query.from.id // "") text=\(.message.text // "") data=\(.callback_query.data // "") cbid=\(.callback_query.id // "")"' <<<"$1")"
  [[ -n "$chat" && -n "$from" ]] || return
  [[ -n "$cbid" ]] && answer "$cbid"
  if ! is_admin "$from"; then
    send "$chat" "⛔ Akses ditolak."$'\n'"ID Telegram kamu: <code>$from</code>"
    return
  fi
  if [[ -n "$data" ]]; then on_callback "$chat" "$data"
  elif [[ -n "$text" ]]; then on_text "$chat" "$text"; fi
}
