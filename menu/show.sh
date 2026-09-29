#!/bin/bash
. /usr/local/lib/xm/lib.sh
p=$1; valid_proto "$p" || exit 1
header "DETAIL AKUN ${p^^}"
pick_user "$p" || { pause; exit 0; }
clear; show_account "$P_PROTO" "$P_USER" "$P_ID" "$P_EXP"
pause
