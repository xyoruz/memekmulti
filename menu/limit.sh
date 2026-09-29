#!/bin/bash
. /usr/local/lib/xm/lib.sh
p=$1; valid_proto "$p" || exit 1
header "UBAH LIMIT IP & KUOTA ${p^^}"
pick_user "$p" || { pause; exit 0; }
echo
echo "Akun    : $P_USER"
echo "Kuota   : $(lim_txt "$P_QUOTA" GB)  (terpakai $(fmt_bytes "$(usage_bytes "$P_PROTO" "$P_USER")"))"
echo "Limit IP: $(lim_txt "$P_IPLIM" IP)"
echo
read -rp "Kuota baru GB (0 = tanpa batas) [$P_QUOTA]: " q; q=${q:-$P_QUOTA}
read -rp "Limit IP baru (0 = tanpa batas) [$P_IPLIM]: " i; i=${i:-$P_IPLIM}
[[ "$q" =~ ^[0-9]+$ && "$i" =~ ^[0-9]+$ ]] || { err "Nilai harus berupa angka."; pause; exit 1; }
db_set "$P_PROTO" "$P_USER" 5 "$q"
db_set "$P_PROTO" "$P_USER" 6 "$i"
# Buka kunci otomatis jika kuota kini sudah cukup
if [[ "$P_STATUS" == quota ]]; then
  used=$(usage_bytes "$P_PROTO" "$P_USER")
  if (( q == 0 || used < q * GB )); then unlock_user "$P_PROTO" "$P_USER"; xray_apply; fi
fi
ok "Limit akun $P_USER diperbarui."
pause
