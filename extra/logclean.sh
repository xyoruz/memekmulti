#!/bin/bash
# extra/logclean.sh - pembersih log harian (journal & log Nginx besar)
# Catatan: log akses Xray TIDAK dikosongkan tiap menit karena dipakai limiter IP (dirotasi via logrotate).
[[ $EUID -eq 0 ]] || { echo "Jalankan sebagai root."; exit 1; }

cat > /etc/cron.d/xm-logclean <<'EOT'
0 3 * * * root journalctl --vacuum-time=3d >/dev/null 2>&1; find /var/log/nginx -name "*.log" -size +50M -exec truncate -s 0 {} + >/dev/null 2>&1
EOT
chmod 644 /etc/cron.d/xm-logclean
echo "✔ Pembersih log harian aktif (03:00)"
