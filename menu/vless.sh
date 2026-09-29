#!/bin/bash
# menu/vless.sh - menu VLESS (dibuka dari menu utama)
. /usr/local/lib/xm/lib.sh
L=/usr/local/lib/xm
p=vless

while true; do
  header "MENU ${p^^}  |  $DOMAIN"
  echo " 1) Buat akun"
  echo " 2) Daftar akun"
  echo " 3) Lihat detail / link akun"
  echo " 4) Perpanjang akun"
  echo " 5) Ubah limit IP & kuota"
  echo " 6) Reset pemakaian / buka kunci"
  echo " 7) Hapus akun"
  echo " 0) Kembali"
  line; read -rp "Pilih: " c
  case $c in
    1) bash $L/add.sh "$p" ;;
    2) bash $L/list.sh "$p" ;;
    3) bash $L/show.sh "$p" ;;
    4) bash $L/renew.sh "$p" ;;
    5) bash $L/limit.sh "$p" ;;
    6) bash $L/reset.sh "$p" ;;
    7) bash $L/del.sh "$p" ;;
    0) exit 0 ;;
  esac
done
