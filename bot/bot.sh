#!/bin/bash
# Bot Telegram untuk mengelola akun Xray Manager (long polling, dijalankan oleh systemd: xm-bot)
# Struktur:  lib/ (dasar)  cmd/ (satu file per perintah)  handler/ (router pesan & tombol)
. /usr/local/lib/xm/lib.sh
BOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# urutan muat: lib (dasar) -> cmd (satu file per perintah) -> handler (router)
for d in lib cmd handler; do
  for f in "$BOT_DIR/$d"/*.sh; do
    . "$f" || { echo "Gagal memuat $d/$(basename "$f")"; exit 1; }
  done
done

# ---------- loop utama ----------
curl -s --max-time 15 "$API/setMyCommands" --data-urlencode 'commands=[{"command":"menu","description":"Menu utama"},{"command":"list","description":"Daftar akun"},{"command":"info","description":"Info server"},{"command":"help","description":"Bantuan"}]' >/dev/null
echo "Bot berjalan. Admin: ${TG_ADMIN:-(kosong - mode cari ID)}"
offset=0
while true; do
  resp=$(curl -s --max-time 65 "$API/getUpdates" -d timeout=50 -d "offset=$offset" -d 'allowed_updates=["message","callback_query"]')
  if ! jq -e '.ok==true' <<<"$resp" >/dev/null 2>&1; then sleep 5; continue; fi
  while IFS= read -r upd; do
    [[ -z "$upd" ]] && continue
    offset=$(( $(jq -r '.update_id' <<<"$upd") + 1 ))
    handle "$upd"
  done < <(jq -c '.result[]?' <<<"$resp")
done
