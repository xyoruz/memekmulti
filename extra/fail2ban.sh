#!/bin/bash
# extra/fail2ban.sh - blokir IP yang brute-force SSH / Dropbear
[[ $EUID -eq 0 ]] || { echo "Jalankan sebagai root."; exit 1; }
export DEBIAN_FRONTEND=noninteractive

apt-get install -y fail2ban rsyslog >/dev/null 2>&1 || { echo "✘ Gagal memasang fail2ban."; exit 1; }
systemctl enable --now rsyslog >/dev/null 2>&1
touch /var/log/auth.log

SSH_PORT=$(ss -tnlp 2>/dev/null | awk '/sshd/{n=split($4,a,":"); print a[n]; exit}')
SSH_PORT=${SSH_PORT:-22}

mkdir -p /etc/fail2ban/jail.d
{
cat <<EOT
[DEFAULT]
bantime = 1h
findtime = 10m
maxretry = 5
ignoreip = 127.0.0.1/8 ::1

[sshd]
enabled = true
port = $SSH_PORT
EOT
if grep -q '^DROPBEAR_PORT=109' /etc/default/dropbear 2>/dev/null; then
cat <<EOT

[dropbear]
enabled = true
port = 109,143
backend = auto
logpath = /var/log/auth.log
EOT
fi
} > /etc/fail2ban/jail.d/xm.local

systemctl enable fail2ban >/dev/null 2>&1
systemctl restart fail2ban
sleep 2
if systemctl is-active --quiet fail2ban; then
  echo "✔ Fail2ban aktif (sshd port $SSH_PORT$(grep -q '^\[dropbear\]' /etc/fail2ban/jail.d/xm.local && echo ', dropbear'))"
else
  echo "✘ Fail2ban gagal jalan. Cek: journalctl -u fail2ban -n 20"; exit 1
fi
