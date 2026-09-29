#!/bin/bash
# bot/cmd/reset.sh - /reset <proto> <user> : reset pemakaian & buka kunci
act_reset(){
  chk "$1" "$2" || return
  db_has "$1" "$2" || { echo "❌ Akun tidak ditemukan."; return; }
  parse_line "$(db_line "$1" "$2")"
  usage_reset "$1" "$2"
  if [[ "$P_STATUS" != active ]]; then unlock_user "$1" "$2"; xray_apply >/dev/null; fi
  echo "♻️ Pemakaian $2 di-reset, akun aktif."
}
