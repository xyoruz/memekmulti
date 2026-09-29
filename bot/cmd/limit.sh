#!/bin/bash
# bot/cmd/limit.sh - /limit <proto> <user> <kuotaGB> <limitIP> : ubah limit
act_limit(){ # proto user kuota ip
  chk "$1" "$2" || return
  db_has "$1" "$2" || { echo "❌ Akun tidak ditemukan."; return; }
  [[ "$3" =~ ^[0-9]+$ && "$4" =~ ^[0-9]+$ ]] || { echo "❌ Format: /limit proto user kuotaGB limitIP"; return; }
  parse_line "$(db_line "$1" "$2")"
  db_set "$1" "$2" 5 "$3"; db_set "$1" "$2" 6 "$4"
  if [[ "$P_STATUS" == quota ]] && { (( $3 == 0 )) || (( $(usage_bytes "$1" "$2") < $3 * GB )); }; then
    unlock_user "$1" "$2"; xray_apply >/dev/null
  fi
  echo "✅ Limit $2: kuota $(lim_txt "$3" GB), IP $(lim_txt "$4" IP)"
}
