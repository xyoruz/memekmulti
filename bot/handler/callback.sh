#!/bin/bash
# bot/handler/callback.sh - router tombol inline (callback_query)
on_callback(){ # chat data
  local chat=$1 act p u
  IFS=: read -r act p u <<<"$2"
  case $act in ls|a|u|d|r|z|x|xy) valid_proto "$p" || return ;; esac
  [[ "$u" =~ ^[A-Za-z0-9_-]*$ ]] || return
  case $act in
    menu) send "$chat" "<b>Xray Manager</b>" "$KB_MAIN" ;;
    util) send "$chat" "<b>Utility</b>"$'\n'"Pengaturan lainnya:" "$KB_UTIL" ;;
    rs)   send "$chat" "$(act_restart)" "$KB_UTIL" ;;
    a)    send "$chat" "<b>Buat akun ${p^^}</b>"$'\n'"Kirim:"$'\n'"<code>/add $p &lt;user&gt; &lt;hari&gt; [kuotaGB] [limitIP]</code>"$'\n'"Contoh: <code>/add $p budi 30 10 2</code>"$'\n'"(kuota 0 / limit IP 0 = tanpa batas)" ;;
    help) send "$chat" "$HELP_TXT" ;;
    info) send "$chat" "$(act_info)" ;;
    exp)  send "$chat" "$(locked act_expire)" ;;
    ls)   send "$chat" "$(act_list "$p")" "$(kb_users "$p")" ;;
    u)    send "$chat" "Akun <b>$u</b> (${p^^})" "$(kb_user "$p" "$u")" ;;
    d)    send "$chat" "$(acct_text "$p" "$u")" "$(kb_user "$p" "$u")" ;;
    r)    send "$chat" "$(locked act_renew "$p" "$u" 30)" "$(kb_user "$p" "$u")" ;;
    z)    send "$chat" "$(locked act_reset "$p" "$u")" "$(kb_user "$p" "$u")" ;;
    x)    send "$chat" "Hapus akun <b>$u</b> (${p^^})?" "$(kb_confirm "$p" "$u")" ;;
    xy)   send "$chat" "$(locked act_del "$p" "$u")" "$(kb_users "$p")" ;;
  esac
}
