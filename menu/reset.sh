#!/bin/bash
. /usr/local/lib/xm/lib.sh
p=$1; valid_proto "$p" || exit 1
header "RESET PEMAKAIAN / BUKA KUNCI ${p^^}"
pick_user "$p" || { pause; exit 0; }
usage_reset "$P_PROTO" "$P_USER"
if [[ "$P_STATUS" != active ]]; then
  unlock_user "$P_PROTO" "$P_USER"; xray_apply
fi
ok "Pemakaian akun $P_USER di-reset dan akun aktif kembali."
pause
