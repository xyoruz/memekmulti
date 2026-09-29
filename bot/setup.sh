#!/bin/bash
# Menu pengaturan bot Telegram - dibuka dari menu Utility → Bot Telegram
# Struktur:  setup/config.sh  setup/service.sh  setup/test.sh  setup/notify.sh  setup/remove.sh
. /usr/local/lib/xm/lib.sh
SETUP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/setup"
for f in "$SETUP_DIR"/*.sh; do
  . "$f" || { echo "Gagal memuat setup/$(basename "$f")"; exit 1; }
done

case_menu(){
  while true; do
    header "BOT TELEGRAM"
    echo -n "Token   : "; [[ -n "$TG_TOKEN" ]] && echo "terpasang" || echo "belum diatur"
    echo "Admin   : ${TG_ADMIN:-belum diatur}"
    echo "Notifikasi: $TG_NOTIFY"
    echo -n "Layanan : "; systemctl is-active xm-bot 2>/dev/null || echo "belum dipasang"
    line
    echo " 1) Atur token & ID admin"
    echo " 2) Aktifkan / start bot"
    echo " 3) Stop bot"
    echo " 4) Restart bot"
    echo " 5) Kirim pesan tes"
    echo " 6) Notifikasi kunci akun & expired (on/off)"
    echo " 7) Lihat log bot"
    echo " 8) Hapus konfigurasi bot"
    echo " 0) Kembali"
    line; read -rp "Pilih: " c
    case $c in
      1) tg_set_cfg; pause ;;
      2) tg_start; pause ;;
      3) tg_stop; pause ;;
      4) tg_restart; pause ;;
      5) tg_test; pause ;;
      6) tg_notify; pause ;;
      7) tg_logs; pause ;;
      8) tg_remove; pause ;;
      0) return ;;
    esac
  done
}
case_menu
