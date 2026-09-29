#!/bin/bash
# bot/cmd/del.sh - /del <proto> <user> : hapus akun
act_del(){
  chk "$1" "$2" || return
  db_has "$1" "$2" || { echo "❌ Akun tidak ditemukan."; return; }
  xray_del "$1" "$2"; sed -i "/^$1|$2|/d" "$DB"; rm -f "$USAGE_DIR/$1_$2"
  xray_apply >/dev/null; echo "🗑 Akun $2 (${1^^}) dihapus."
}
