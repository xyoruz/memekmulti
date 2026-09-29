#!/bin/bash
# ==========================================================
#  Autoscript Xray: VLESS, VMess, Trojan (WebSocket) + Nginx
#  Multi-port TLS & nTLS | Manajemen akun via menu
#  OS: Ubuntu 20.x/22.x, Debian 10/11/12
#  Jalankan sebagai root:  bash multiport.sh
# ==========================================================

R='\033[0;31m'; G='\033[0;32m'; Y='\033[0;33m'; C='\033[0;36m'; N='\033[0m'
die(){ echo -e "${R}Error: $*${N}"; exit 1; }
step(){ echo -e "${Y}[$1/10] $2${N}"; }

[[ $EUID -eq 0 ]] || die "Jalankan sebagai root (sudo su)."
. /etc/os-release 2>/dev/null
[[ "${ID:-}" =~ ^(ubuntu|debian)$ ]] || die "OS tidak didukung (hanya Ubuntu/Debian)."

XM_DIR=/etc/xray-manager
LIB_DIR=/usr/local/lib/xm
XRAY_CFG=/usr/local/etc/xray/config.json
CERT_DIR=/usr/local/etc/xray

# ---------- Sumber file modul ----------
# Isi REPO_RAW dengan URL raw repo GitHub kamu (dipakai jika script dijalankan tanpa git clone)
REPO_RAW="https://raw.githubusercontent.com/USER/REPO/main"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)"
fetch(){ # path_di_repo  tujuan
  mkdir -p "$(dirname "$2")"
  if [[ -n "$SCRIPT_DIR" && -f "$SCRIPT_DIR/$1" ]]; then
    cp "$SCRIPT_DIR/$1" "$2"
  else
    [[ "$REPO_RAW" != *USER/REPO* ]] || die "Isi REPO_RAW di bagian atas script dengan URL raw repo GitHub kamu."
    wget -q -O "$2" "$REPO_RAW/$1" || die "Gagal mengunduh $1"
  fi
}

clear
echo -e "${G}=================================================${N}"
echo -e "${G}   INSTALASI XRAY VLESS / VMESS / TROJAN (WS)    ${N}"
echo -e "${G}=================================================${N}"
read -rp "Masukkan domain (contoh: vpn.domain.com): " DOMAIN
[[ "$DOMAIN" =~ ^[A-Za-z0-9.-]+\.[A-Za-z]{2,}$ ]] || die "Format domain tidak valid."

# ---------- 1. Dependensi ----------
step 1 "Memperbarui sistem & memasang dependensi..."
export DEBIAN_FRONTEND=noninteractive
apt-get update -y
apt-get install -y nginx curl wget uuid-runtime jq ufw unzip socat cron psmisc openssl net-tools \
  || die "Gagal memasang dependensi."

# ---------- 2. Cek DNS ----------
step 2 "Memeriksa DNS domain..."
SERVER_IP=$(curl -4s --max-time 10 https://ifconfig.me || curl -4s --max-time 10 https://api.ipify.org)
DOMAIN_IP=$(getent ahostsv4 "$DOMAIN" | awk 'NR==1{print $1}')
echo "IP server : ${SERVER_IP:-?}"
echo "IP domain : ${DOMAIN_IP:-belum resolve}"
if [[ -z "$DOMAIN_IP" || "$DOMAIN_IP" != "$SERVER_IP" ]]; then
  echo -e "${Y}Domain belum mengarah ke IP server ini (atau Cloudflare proxy masih aktif).${N}"
  read -rp "Tetap lanjut? (y/N): " a
  [[ "$a" =~ ^[Yy]$ ]] || die "Dibatalkan. Arahkan A record ke ${SERVER_IP} (awan abu-abu) lalu ulangi."
fi

# ---------- 3. Bebaskan port ----------
step 3 "Menyiapkan port 80/443..."
systemctl stop nginx 2>/dev/null
fuser -k 80/tcp 2>/dev/null
fuser -k 443/tcp 2>/dev/null

# ---------- 4. SSL ----------
step 4 "Menerbitkan sertifikat SSL untuk ${DOMAIN}..."
curl -s https://get.acme.sh | sh -s email="admin@${DOMAIN}" >/dev/null 2>&1
ACME=~/.acme.sh/acme.sh
[[ -x "$ACME" ]] || die "Gagal memasang acme.sh."
"$ACME" --set-default-ca --server letsencrypt
"$ACME" --issue -d "$DOMAIN" --standalone -k ec-256 \
  --pre-hook "systemctl stop nginx" --post-hook "systemctl start nginx" \
  || die "Penerbitan SSL gagal. Cek DNS/port 80 lalu ulangi."
mkdir -p "$CERT_DIR"
"$ACME" --installcert -d "$DOMAIN" --ecc \
  --fullchainpath "$CERT_DIR/xray.crt" --keypath "$CERT_DIR/xray.key" \
  --reloadcmd "systemctl reload nginx 2>/dev/null || true"
chmod 644 "$CERT_DIR/xray.crt"; chmod 600 "$CERT_DIR/xray.key"   # Nginx (root) yang membaca key

# ---------- 5. Xray core ----------
step 5 "Memasang Xray core..."
bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install \
  || die "Gagal memasang Xray."
[[ -x /usr/local/bin/xray ]] || die "Binary Xray tidak ditemukan."

# ---------- 6. Konfigurasi Xray ----------
step 6 "Menulis konfigurasi Xray..."
mkdir -p "$XM_DIR" /usr/local/etc/xray
echo "$DOMAIN" > "$XM_DIR/domain"
touch "$XM_DIR/users.db"

fetch config/xray.json "$XRAY_CFG"
chmod 644 "$XRAY_CFG"

# Log Xray (dipakai limit IP) + usage dir
mkdir -p "$XM_DIR/usage" /var/log/xray
touch /var/log/xray/access.log /var/log/xray/error.log
chown -R nobody /var/log/xray; chmod 755 /var/log/xray
cat > /etc/logrotate.d/xray <<'LR'
/var/log/xray/*.log {
    daily
    rotate 3
    missingok
    notifempty
    copytruncate
    compress
}
LR

# ---------- 7. Nginx ----------
step 7 "Mengonfigurasi Nginx..."
rm -f /etc/nginx/sites-enabled/default
mkdir -p /var/www/html
echo "<h1>It works.</h1>" > /var/www/html/index.html

ws_loc(){ cat <<EOF
    location = $1 {
        if (\$http_upgrade != "websocket") { return 404; }
        proxy_redirect off;
        proxy_pass http://127.0.0.1:$2;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_read_timeout 86400s;
    }
EOF
}

{
  echo "server {"
  echo "    listen 80; listen 8080; listen 8880; listen 2086;"
  echo "    server_name $DOMAIN;"
  echo "    location / { root /var/www/html; index index.html; }"
  ws_loc /vless-ntls 10002
  ws_loc /vmess-ntls 10004
  ws_loc /trojan-ntls 10006
  echo "}"
  echo
  echo "server {"
  echo "    listen 443 ssl; listen 8443 ssl;"
  echo "    server_name $DOMAIN;"
  echo "    ssl_certificate $CERT_DIR/xray.crt;"
  echo "    ssl_certificate_key $CERT_DIR/xray.key;"
  echo "    ssl_protocols TLSv1.2 TLSv1.3;"
  echo "    ssl_ciphers HIGH:!aNULL:!MD5;"
  echo "    location / { root /var/www/html; index index.html; }"
  ws_loc /vless-tls 10001
  ws_loc /vmess-tls 10003
  ws_loc /trojan-tls 10005
  echo "}"
} > /etc/nginx/conf.d/xray.conf
nginx -t || die "Konfigurasi Nginx tidak valid."

# ---------- 8. Modul menu (dipisah per fungsi) ----------
step 8 "Memasang modul menu & manajemen akun..."
mkdir -p "$LIB_DIR"

MENU_FILES="lib.sh add.sh list.sh show.sh renew.sh del.sh expire.sh info.sh limit.sh reset.sh domain.sh limiter.sh menu"
BOT_FILES="bot.sh setup.sh lib/core.sh lib/keyboard.sh lib/validate.sh cmd/help.sh cmd/add.sh cmd/del.sh cmd/renew.sh cmd/limit.sh cmd/reset.sh cmd/detail.sh cmd/list.sh cmd/info.sh cmd/expire.sh cmd/restart.sh handler/text.sh handler/callback.sh handler/update.sh setup/config.sh setup/service.sh setup/test.sh setup/notify.sh setup/remove.sh"
for f in $MENU_FILES; do
  fetch "menu/$f" "$LIB_DIR/$f"
done
for f in $BOT_FILES; do
  fetch "bot/$f" "$LIB_DIR/bot/$f"
done
fetch update.sh "$LIB_DIR/update.sh"
[[ "$REPO_RAW" != *USER/REPO* ]] && echo "$REPO_RAW" > "$XM_DIR/repo"
ln -sf "$LIB_DIR/update.sh" /usr/local/bin/xm-update
chmod +x "$LIB_DIR"/*.sh "$LIB_DIR/menu" "$LIB_DIR"/bot/*.sh "$LIB_DIR"/bot/lib/*.sh "$LIB_DIR"/bot/cmd/*.sh "$LIB_DIR"/bot/handler/*.sh "$LIB_DIR"/bot/setup/*.sh
ln -sf "$LIB_DIR/menu" /usr/local/bin/menu

# Cron: bersihkan akun expired tiap hari 00:05
echo "5 0 * * * root /bin/bash $LIB_DIR/expire.sh >/dev/null 2>&1" > /etc/cron.d/xm-expire
chmod 644 /etc/cron.d/xm-expire
# Limiter (kuota & limit IP) tiap menit
echo "* * * * * root /bin/bash $LIB_DIR/limiter.sh >/dev/null 2>&1" > /etc/cron.d/xm-limiter
chmod 644 /etc/cron.d/xm-limiter

step 9 "Memasang komponen tambahan (zona waktu/swap/BBR, Dropbear, vnstat, Fail2ban, pembersih log)..."
EXTRA_FILES="system.sh dropbear.sh vnstat.sh fail2ban.sh logclean.sh"
mkdir -p "$LIB_DIR/extra"
for f in $EXTRA_FILES; do
  fetch "extra/$f" "$LIB_DIR/extra/$f"
  chmod +x "$LIB_DIR/extra/$f"
done
for f in $EXTRA_FILES; do
  bash "$LIB_DIR/extra/$f" || echo -e "${Y}Peringatan: extra/$f gagal, dilewati (bisa dijalankan ulang: bash $LIB_DIR/extra/$f).${N}"
done

# ---------- 10. Firewall & start ----------
step 10 "Mengaktifkan firewall & layanan..."
SSH_PORT=$(ss -tnlp 2>/dev/null | awk '/sshd/{n=split($4,a,":"); print a[n]; exit}')
SSH_PORT=${SSH_PORT:-22}
ufw allow "${SSH_PORT}/tcp" >/dev/null 2>&1
ufw allow 80,8080,8880,2086,443,8443/tcp >/dev/null 2>&1
grep -q "^DROPBEAR_PORT=109" /etc/default/dropbear 2>/dev/null && ufw allow 109,143/tcp >/dev/null 2>&1
ufw --force enable >/dev/null 2>&1

systemctl daemon-reload
systemctl enable --now cron >/dev/null 2>&1
systemctl enable xray nginx >/dev/null 2>&1
systemctl restart xray
systemctl restart nginx

sleep 1
systemctl is-active --quiet xray  || echo -e "${R}Peringatan: Xray belum berjalan, cek: journalctl -u xray -n 30${N}"
systemctl is-active --quiet nginx || echo -e "${R}Peringatan: Nginx belum berjalan, cek: nginx -t${N}"

echo
echo -e "${G}=================================================${N}"
echo -e "${G}  INSTALASI SELESAI${N}"
echo -e "${G}=================================================${N}"
echo "Domain      : $DOMAIN"
echo "Port TLS    : 443, 8443"
echo "Port nTLS   : 80, 8080, 8880, 2086"
echo "Port SSH    : $SSH_PORT (diizinkan di firewall)"
grep -q "^DROPBEAR_PORT=109" /etc/default/dropbear 2>/dev/null && echo "Dropbear    : 109, 143"
echo
echo -e "Ketik ${Y}menu${N} untuk membuat & mengelola akun."
echo -e "Ketik ${Y}xm-update${N} untuk memperbarui script dari GitHub."
