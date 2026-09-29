#!/bin/bash
# Menu pengaturan bot Telegram (token, admin, start/stop, log) - dibuka dari menu utama nomor 9
. /usr/local/lib/xm/lib.sh
CONF=$XM_DIR/telegram.conf
SVC=/etc/systemd/system/xm-bot.service
TG_TOKEN=""; TG_ADMIN=""; TG_NOTIFY="on"
[[ -f "$CONF" ]] && . "$CONF"

save_conf(){
  ( umask 077
    cat > "$CONF" <<EOF
TG_TOKEN="$TG_TOKEN"
TG_ADMIN="$TG_ADMIN"
TG_NOTIFY="$TG_NOTIFY"
EOF
  )
  chmod 600 "$CONF"
}

install_service(){
  cat > "$SVC" <<'EOF'
[Unit]
Description=Xray Manager Telegram Bot
After=network-online.target xray.service
Wants=network-online.target

[Service]
ExecStart=/bin/bash /usr/local/lib/xm/bot/bot.sh
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
  systemctl daemon-reload
}

need_token(){ [[ -n "$TG_TOKEN" ]] || { err "Token belum diatur. Pilih menu 1 dulu."; return 1; }; }

set_cfg(){
  header "ATUR TOKEN & ID ADMIN"
  echo "1. Buat bot di @BotFather (perintah /newbot), salin token-nya."
  echo "2. ID admin: kirim /start ke bot setelah bot aktif, ID kamu akan ditampilkan."
  echo
  read -rp "Token bot [Enter = tetap]: " t
  if [[ -n "$t" ]]; then
    [[ "$t" =~ ^[0-9]+:[A-Za-z0-9_-]{30,}$ ]] || { err "Format token tidak valid."; return; }
    res=$(curl -s --max-time 15 "https://api.telegram.org/bot$t/getMe")
    jq -e '.ok==true' <<<"$res" >/dev/null 2>&1 || { err "Token ditolak Telegram."; return; }
    TG_TOKEN=$t; ok "Bot terhubung: @$(jq -r '.result.username' <<<"$res")"
  fi
  need_token || return
  read -rp "ID admin (pisahkan koma, kosong = belum tahu) [${TG_ADMIN:-kosong}]: " a
  a=${a:-$TG_ADMIN}; a=${a// /}
  [[ -z "$a" || "$a" =~ ^-?[0-9]+(,-?[0-9]+)*$ ]] || { err "ID admin harus angka."; return; }
  TG_ADMIN=$a; save_conf
  systemctl is-active --quiet xm-bot && { systemctl restart xm-bot; ok "Bot di-restart."; }
  ok "Pengaturan tersimpan."
  [[ -z "$TG_ADMIN" ]] && warn "ID admin masih kosong: nyalakan bot, kirim /start, lalu isi ID yang tampil."
}

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
      1) set_cfg; pause ;;
      2) need_token && { install_service; systemctl enable --now xm-bot >/dev/null 2>&1; sleep 1
           systemctl is-active --quiet xm-bot && ok "Bot aktif. Kirim /start ke bot kamu." || err "Bot gagal jalan, cek log (menu 7)."; }; pause ;;
      3) systemctl disable --now xm-bot >/dev/null 2>&1 && ok "Bot dihentikan."; pause ;;
      4) systemctl restart xm-bot && ok "Bot di-restart."; pause ;;
      5) need_token && {
           [[ -n "$TG_ADMIN" ]] || { err "ID admin belum diatur."; pause; continue; }
           for a in ${TG_ADMIN//,/ }; do
             r=$(curl -s --max-time 15 "https://api.telegram.org/bot$TG_TOKEN/sendMessage" \
                 --data-urlencode "chat_id=$a" --data-urlencode "text=✅ Tes dari $DOMAIN")
             jq -e '.ok==true' <<<"$r" >/dev/null 2>&1 && ok "Terkirim ke $a" || err "Gagal kirim ke $a (sudah /start bot?)"
           done; }; pause ;;
      6) [[ "$TG_NOTIFY" == on ]] && TG_NOTIFY=off || TG_NOTIFY=on
         need_token && save_conf; ok "Notifikasi: $TG_NOTIFY"; pause ;;
      7) journalctl -u xm-bot -n 30 --no-pager; pause ;;
      8) read -rp "Hapus semua pengaturan bot? (y/N): " a
         if [[ "$a" =~ ^[Yy]$ ]]; then
           systemctl disable --now xm-bot >/dev/null 2>&1; rm -f "$SVC" "$CONF"; systemctl daemon-reload
           TG_TOKEN=""; TG_ADMIN=""; ok "Konfigurasi bot dihapus."
         fi; pause ;;
      0) return ;;
    esac
  done
}
case_menu
