#!/bin/bash
. /usr/local/lib/xm/lib.sh
p=$1; valid_proto "$p" || exit 1
header "BUAT AKUN ${p^^}"
read -rp "Username (3-20, huruf/angka/_/-): " u
[[ "$u" =~ ^[A-Za-z0-9_-]{3,20}$ ]] || { err "Username tidak valid."; pause; exit 1; }
db_has "$p" "$u" && { err "Username sudah dipakai."; pause; exit 1; }
read -rp "Masa aktif (hari) [30]: " days; days=${days:-30}
[[ "$days" =~ ^[0-9]+$ ]] && ((days>=1)) || { err "Jumlah hari tidak valid."; pause; exit 1; }
read -rp "Limit IP (0 = tanpa batas) [0]: " iplim; iplim=${iplim:-0}
[[ "$iplim" =~ ^[0-9]+$ ]] || { err "Limit IP tidak valid."; pause; exit 1; }
read -rp "Limit kuota GB (0 = tanpa batas) [0]: " quota; quota=${quota:-0}
[[ "$quota" =~ ^[0-9]+$ ]] || { err "Kuota tidak valid."; pause; exit 1; }
id=$(uuidgen); exp=$(date -d "+$days days" +%F)
xray_add "$p" "$u" "$id" || { err "Gagal menulis config."; pause; exit 1; }
echo "$p|$u|$id|$exp|$quota|$iplim|active" >> "$DB"
usage_reset "$p" "$u"
xray_apply || { xray_del "$p" "$u"; sed -i "/^$p|$u|/d" "$DB"; pause; exit 1; }
clear; show_account "$p" "$u" "$id" "$exp"
pause
