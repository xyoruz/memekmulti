#!/bin/bash
# bot/cmd/add.sh - /add <proto> <user> <hari> [kuotaGB] [limitIP] : buat akun
act_add(){ # proto user hari [kuota] [ip]
  local p=$1 u=$2 days=$3 q=${4:-0} il=${5:-0} id exp
  chk "$p" "$u" || return
  db_has "$p" "$u" && { echo "❌ Username sudah dipakai."; return; }
  [[ "$days" =~ ^[0-9]+$ ]] && ((days>=1)) || { echo "❌ Jumlah hari tidak valid."; return; }
  [[ "$q" =~ ^[0-9]+$ && "$il" =~ ^[0-9]+$ ]] || { echo "❌ Kuota dan limit IP harus angka."; return; }
  id=$(uuidgen); exp=$(date -d "+$days days" +%F)
  xray_add "$p" "$u" "$id" || { echo "❌ Gagal menulis config."; return; }
  echo "$p|$u|$id|$exp|$q|$il|active" >> "$DB"; usage_reset "$p" "$u"
  xray_apply >/dev/null || { xray_del "$p" "$u"; sed -i "/^$p|$u|/d" "$DB"; echo "❌ Xray gagal menerapkan config."; return; }
  acct_text "$p" "$u"
}
