#!/bin/bash
# bot/cmd/expire.sh - /expire : hapus akun expired sekarang
act_expire(){
  local a b; a=$(wc -l < "$DB")
  bash /usr/local/lib/xm/expire.sh >/dev/null 2>&1
  b=$(wc -l < "$DB"); echo "🧹 $((a-b)) akun expired dihapus."
}
