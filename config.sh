#!/bin/bash
# bot/setup/config.sh - simpan/muat konfigurasi, atur token & ID admin
CONF=$XM_DIR/telegram.conf
TG_TOKEN=""; TG_ADMIN=""; TG_NOTIFY="on"
[[ -f "$CONF" ]] && . "$CONF"

save_conf(){
  ( umask 077
    cat > "$CONF" <<EOT
TG_TOKEN="$TG_TOKEN"
TG_ADMIN="$TG_ADMIN"
TG_NOTIFY="$TG_NOTIFY"
EOT
  )
  chmod 600 "$CONF"
}

need_token(){ [[ -n "$TG_TOKEN" ]] || { err "Token belum diatur. Pilih menu 1 dulu."; return 1; }; }

tg_set_cfg(){
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
