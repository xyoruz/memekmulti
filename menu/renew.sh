#!/bin/bash
. /usr/local/lib/xm/lib.sh
p=$1; valid_proto "$p" || exit 1
header "PERPANJANG AKUN ${p^^}"
pick_user "$p" || { pause; exit 0; }
read -rp "Tambah masa aktif (hari) [30]: " days; days=${days:-30}
[[ "$days" =~ ^[0-9]+$ ]] && ((days>=1)) || { err "Jumlah hari tidak valid."; pause; exit 1; }
today=$(date +%F); base=$P_EXP; [[ "$base" < "$today" ]] && base=$today
new=$(date -d "$base +$days days" +%F)
db_set "$P_PROTO" "$P_USER" 4 "$new"
ok "Akun $P_USER diperpanjang sampai $new"
pause
