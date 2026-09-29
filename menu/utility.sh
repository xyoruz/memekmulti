#!/bin/bash
# menu/utility.sh - menu Utility: pengaturan server & layanan
. /usr/local/lib/xm/lib.sh
L=/usr/local/lib/xm

renew_ssl(){
  header "PERBARUI SSL"
  ~/.acme.sh/acme.sh --renew -d "$DOMAIN" --ecc --force && ok "SSL diperbarui." || err "Gagal memperbarui SSL."
  pause
}

restart_all(){
  header "RESTART LAYANAN"
  systemctl restart xray nginx && ok "Xray & Nginx di-restart." || err "Gagal restart."
  pause
}

while true; do
  header "UTILITY  |  $DOMAIN"
  echo " 1) Info server & layanan"
  echo " 2) Hapus akun expired sekarang"
  echo " 3) Perbarui SSL"
  echo " 4) Restart layanan"
  echo " 5) Ganti domain"
  echo " 6) Bot Telegram"
  echo " 7) Update script dari GitHub"
  echo " 0) Kembali"
  line; read -rp "Pilih: " c
  case $c in
    1) bash $L/info.sh ;;
    2) bash $L/expire.sh; pause ;;
    3) renew_ssl ;;
    4) restart_all ;;
    5) bash $L/domain.sh ;;
    6) bash $L/bot/setup.sh ;;
    7) bash $L/update.sh; pause ;;
    0) exit 0 ;;
  esac
done
