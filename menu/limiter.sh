#!/bin/bash
. /usr/local/lib/xm/lib.sh
exec 9>/var/run/xm-db.lock; flock -n 9 || exit 0
now=$(date +%s); changed=0

# 1) Akumulasi trafik (selisih sejak query terakhir, lalu counter di-reset)
out=$("$XRAY_BIN" api statsquery --server="$API_ADDR" -pattern "user>>>" -reset 2>/dev/null)
if [[ -n "$out" ]]; then
  echo "$out" | jq -r '.stat[]? | "\(.name|split(">>>")[1]) \(.value // 0)"' 2>/dev/null \
  | awk '{s[$1]+=$2} END{for(e in s) printf "%s %.0f\n", e, s[e]}' \
  | while read -r e b; do
      u=${e%@*}; p=${e#*@}
      db_has "$p" "$u" || continue
      cur=$(usage_bytes "$p" "$u")
      echo $((cur + b)) > "$USAGE_DIR/${p}_${u}"
    done
fi

# 2) IP aktif per akun dari access log (jendela IP_WINDOW_MIN menit terakhir)
ips=$(mktemp); trap 'rm -f "$ips"' EXIT
if [[ -f "$XRAY_LOG" ]]; then
  cut=$(date -d "-${IP_WINDOW_MIN} min" '+%Y/%m/%d %H:%M:%S')
  tail -n 50000 "$XRAY_LOG" | awk -v c="$cut" '
    ($1" "$2) >= c && /email: / {
      src=""
      for (i=3; i<=NF; i++) {
        if ($i=="from")     { src=$(i+1); break }
        if ($i=="accepted") { src=$(i-1); break }
      }
      sub(/^(tcp|udp):/, "", src)
      if (src !~ /^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+:[0-9]+$/) next
      sub(/:[0-9]+$/, "", src)
      if (src != "127.0.0.1") print $NF, src
    }' | sort -u > "$ips"
fi

# 3) Terapkan limit
while IFS= read -r l; do
  [[ -z "$l" ]] && continue
  parse_line "$l"; p=$P_PROTO; u=$P_USER
  case $P_STATUS in
    quota) continue ;;
    ip:*)  if (( now >= ${P_STATUS#ip:} )); then unlock_user "$p" "$u"; changed=1; tg_notify "🔓 <b>$p/$u</b> dibuka kembali (kunci IP selesai)"; fi
           continue ;;
  esac
  if (( P_QUOTA > 0 )) && (( $(usage_bytes "$p" "$u") >= P_QUOTA * GB )); then
    lock_user "$p" "$u" quota; changed=1
    echo "$(date '+%F %T') $p/$u dikunci: kuota habis" >> /var/log/xm-limiter.log
    tg_notify "🔒 <b>$p/$u</b> dikunci: kuota habis"
    continue
  fi
  if (( P_IPLIM > 0 )); then
    n=$(grep -c "^$u@$p " "$ips")
    if (( n > P_IPLIM )); then
      lock_user "$p" "$u" "ip:$((now + IP_LOCK_MIN * 60))"; changed=1
      echo "$(date '+%F %T') $p/$u dikunci ${IP_LOCK_MIN}m: $n IP (limit $P_IPLIM)" >> /var/log/xm-limiter.log
      tg_notify "🔒 <b>$p/$u</b> dikunci ${IP_LOCK_MIN} menit: $n IP (limit $P_IPLIM)"
    fi
  fi
done < <(cat "$DB")

(( changed )) && xray_apply
exit 0
