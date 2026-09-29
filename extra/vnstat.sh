#!/bin/bash
# extra/vnstat.sh - monitor pemakaian bandwidth (perintah: vnstat)
[[ $EUID -eq 0 ]] || { echo "Jalankan sebagai root."; exit 1; }
export DEBIAN_FRONTEND=noninteractive

apt-get install -y vnstat >/dev/null 2>&1 || { echo "✘ Gagal memasang vnstat."; exit 1; }
NET=$(ip route show default | awk '/default/ {print $5; exit}')
if [[ -n "$NET" ]]; then
  vnstat --add -i "$NET" >/dev/null 2>&1 || vnstat -u -i "$NET" >/dev/null 2>&1 || true
fi
systemctl enable --now vnstat >/dev/null 2>&1
systemctl restart vnstat
echo "✔ vnstat aktif (interface: ${NET:-otomatis}). Cek dengan: vnstat"
