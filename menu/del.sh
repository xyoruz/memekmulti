#!/bin/bash
. /usr/local/lib/xm/lib.sh
p=$1; valid_proto "$p" || exit 1
header "HAPUS AKUN ${p^^}"
pick_user "$p" || { pause; exit 0; }
read -rp "Hapus akun '$P_USER'? (y/N): " a
[[ "$a" =~ ^[Yy]$ ]] || { warn "Dibatalkan."; pause; exit 0; }
xray_del "$P_PROTO" "$P_USER" && sed -i "/^$P_PROTO|$P_USER|/d" "$DB"
rm -f "$USAGE_DIR/${P_PROTO}_${P_USER}"
xray_apply && ok "Akun $P_USER dihapus."
pause
