#!/bin/bash
# extra/dropbear.sh - Dropbear SSH (port 109 & 143) + banner login
[[ $EUID -eq 0 ]] || { echo "Jalankan sebagai root."; exit 1; }
export DEBIAN_FRONTEND=noninteractive

apt-get install -y dropbear >/dev/null 2>&1 || { echo "✘ Gagal memasang dropbear."; exit 1; }

cat > /etc/issue.net <<'EOT'
=====================================
   Akses hanya untuk pengguna berizin
=====================================
EOT

cat > /etc/default/dropbear <<'EOT'
NO_START=0
DROPBEAR_PORT=109
DROPBEAR_EXTRA_ARGS="-p 143"
DROPBEAR_BANNER="/etc/issue.net"
DROPBEAR_RECEIVE_WINDOW=65536
EOT

# Dropbear butuh shell terdaftar agar user tanpa shell bisa login
for s in /bin/false /usr/sbin/nologin; do
  grep -qx "$s" /etc/shells || echo "$s" >> /etc/shells
done

systemctl enable dropbear >/dev/null 2>&1
systemctl restart dropbear
sleep 1
if systemctl is-active --quiet dropbear; then
  echo "✔ Dropbear aktif (port 109, 143)"
else
  echo "✘ Dropbear gagal jalan. Cek: journalctl -u dropbear -n 20"; exit 1
fi
