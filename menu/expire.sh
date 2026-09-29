#!/bin/bash
. /usr/local/lib/xm/lib.sh
today=$(date +%F); n=0
while IFS= read -r l; do
  [[ -z "$l" ]] && continue
  parse_line "$l"
  if [[ "$P_EXP" < "$today" ]]; then
    xray_del "$P_PROTO" "$P_USER"
    sed -i "/^$P_PROTO|$P_USER|/d" "$DB"
    rm -f "$USAGE_DIR/${P_PROTO}_${P_USER}"
    ((n++))
    tg_notify "🧹 <b>$P_PROTO/$P_USER</b> expired dan dihapus"
  fi
done < <(cat "$DB")
((n>0)) && xray_apply
echo "$(date '+%F %T') hapus $n akun expired" >> /var/log/xm-expire.log
[[ -t 1 ]] && ok "$n akun expired dihapus."
exit 0
