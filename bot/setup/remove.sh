#!/bin/bash
# bot/setup/remove.sh - hapus konfigurasi & service bot
tg_remove(){
  local a
  read -rp "Hapus semua pengaturan bot? (y/N): " a
  if [[ "$a" =~ ^[Yy]$ ]]; then
    systemctl disable --now xm-bot >/dev/null 2>&1
    rm -f "$SVC" "$CONF"; systemctl daemon-reload
    TG_TOKEN=""; TG_ADMIN=""
    ok "Konfigurasi bot dihapus."
  fi
}
