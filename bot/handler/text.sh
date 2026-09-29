#!/bin/bash
# bot/handler/text.sh - router perintah teks (/add, /del, dst)
on_text(){ # chat teks
  local chat=$1 cmd a b c d e
  read -r cmd a b c d e <<<"$2"; cmd=${cmd%%@*}
  case $cmd in
    /start|/menu) send "$chat" "<b>Xray Manager</b>"$'\n'"Pilih menu:" "$KB_MAIN" ;;
    /help)   send "$chat" "$HELP_TXT" ;;
    /add)    send "$chat" "$(locked act_add "$a" "$b" "$c" "$d" "$e")" ;;
    /del)    send "$chat" "$(locked act_del "$a" "$b")" ;;
    /renew)  send "$chat" "$(locked act_renew "$a" "$b" "$c")" ;;
    /limit)  send "$chat" "$(locked act_limit "$a" "$b" "$c" "$d")" ;;
    /reset)  send "$chat" "$(locked act_reset "$a" "$b")" ;;
    /detail) chk "$a" "$b" >/dev/null && send "$chat" "$(acct_text "$a" "$b")" || send "$chat" "❌ Format: /detail proto user" ;;
    /list)   if valid_proto "$a"; then send "$chat" "$(act_list "$a")"
             else send "$chat" "$(act_list_all)"; fi ;;
    /info)   send "$chat" "$(act_info)" ;;
    /expire) send "$chat" "$(locked act_expire)" ;;
    /restart) send "$chat" "$(act_restart)" ;;
    *)       send "$chat" "Perintah tidak dikenal. Ketik /menu atau /help." ;;
  esac
}
