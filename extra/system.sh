#!/bin/bash
# extra/system.sh - zona waktu Asia/Jakarta, swap 1GB (jika belum ada), BBR
[[ $EUID -eq 0 ]] || { echo "Jalankan sebagai root."; exit 1; }

# 1. Zona waktu
timedatectl set-timezone Asia/Jakarta 2>/dev/null && echo "✔ Zona waktu: Asia/Jakarta"

# 2. Swap (hanya jika belum ada swap & disk cukup)
if [[ -z $(swapon --show --noheadings 2>/dev/null) ]]; then
  avail=$(df --output=avail -m / | tail -1 | tr -d ' ')
  if (( avail > 4096 )); then
    if [[ ! -f /swapfile ]]; then
      fallocate -l 1G /swapfile 2>/dev/null || dd if=/dev/zero of=/swapfile bs=1M count=1024 status=none
      chmod 600 /swapfile
      mkswap /swapfile >/dev/null
    fi
    if swapon /swapfile 2>/dev/null; then
      grep -q '^/swapfile' /etc/fstab || echo '/swapfile none swap sw 0 0' >> /etc/fstab
      echo "✔ Swap 1GB aktif"
    else
      echo "! Swap tidak bisa diaktifkan (mungkin VPS container), dilewati."
    fi
  else
    echo "! Disk kurang dari 4GB kosong, swap dilewati."
  fi
else
  echo "✔ Swap sudah ada, dilewati."
fi

# 3. BBR
modprobe tcp_bbr 2>/dev/null
if grep -qw bbr /proc/sys/net/ipv4/tcp_available_congestion_control 2>/dev/null; then
  echo tcp_bbr > /etc/modules-load.d/bbr.conf
  cat > /etc/sysctl.d/99-xm-bbr.conf <<EOT
net.core.default_qdisc=fq
net.ipv4.tcp_congestion_control=bbr
EOT
  sysctl --system >/dev/null 2>&1
  echo "✔ BBR aktif: $(sysctl -n net.ipv4.tcp_congestion_control)"
else
  echo "! Kernel tidak mendukung BBR, dilewati."
fi
