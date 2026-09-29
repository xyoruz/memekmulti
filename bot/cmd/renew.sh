#!/bin/bash
# bot/cmd/renew.sh - /renew <proto> <user> <hari> : perpanjang akun
act_renew(){ # proto user hari
  chk "$1" "$2" || return
  db_has "$1" "$2" || { echo "❌ Akun tidak ditemukan."; return; }
  [[ "$3" =~ ^[0-9]+$ ]] && (($3>=1)) || { echo "❌ Jumlah hari tidak valid."; return; }
  parse_line "$(db_line "$1" "$2")"
  local base=$P_EXP today; today=$(date +%F); [[ "$base" < "$today" ]] && base=$today
  local new; new=$(date -d "$base +$3 days" +%F)
  db_set "$1" "$2" 4 "$new"; echo "✅ Akun $2 diperpanjang sampai $new"
}
