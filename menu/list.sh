#!/bin/bash
. /usr/local/lib/xm/lib.sh
p=$1; valid_proto "$p" || exit 1
header "DAFTAR AKUN ${p^^}"
today=$(date +%F); i=0
printf "%-3s %-14s %-11s %-20s %-6s %s\n" NO USER EXPIRED "KUOTA(pakai/limit)" "IP" STATUS
while IFS= read -r l; do
  ((i++)); parse_line "$l"
  used=$(fmt_bytes "$(usage_bytes "$P_PROTO" "$P_USER")")
  (( P_QUOTA > 0 )) && q="$used / ${P_QUOTA}GB" || q="$used / -"
  (( P_IPLIM > 0 )) && ip="$P_IPLIM" || ip="-"
  s=$(st_label "$P_STATUS"); [[ "$P_EXP" < "$today" ]] && s="EXPIRED"
  printf "%-3s %-14s %-11s %-20s %-6s %s\n" "$i" "$P_USER" "$P_EXP" "$q" "$ip" "$s"
done < <(grep "^$p|" "$DB")
((i==0)) && warn "Belum ada akun."
echo; echo "Total: $i akun"
pause
