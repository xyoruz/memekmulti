#!/bin/bash
. /usr/local/lib/xm/lib.sh
ACME=/root/.acme.sh/acme.sh
CERT_DIR=/usr/local/etc/xray
header "GANTI DOMAIN"
echo "Domain saat ini: $DOMAIN"
read -rp "Domain baru: " nd
[[ "$nd" =~ ^[A-Za-z0-9.-]+\.[A-Za-z]{2,}$ ]] || { err "Format domain tidak valid."; pause; exit 1; }
[[ "$nd" == "$DOMAIN" ]] && { warn "Domain sama dengan yang sekarang."; pause; exit 0; }

sip=$(curl -4s --max-time 10 https://ifconfig.me)
dip=$(getent ahostsv4 "$nd" | awk 'NR==1{print $1}')
echo "IP server : ${sip:-?}"
echo "IP domain : ${dip:-belum resolve}"
if [[ -z "$dip" || "$dip" != "$sip" ]]; then
  warn "Domain belum mengarah ke IP server ini (atau proxy Cloudflare masih aktif)."
  read -rp "Tetap lanjut? (y/N): " a; [[ "$a" =~ ^[Yy]$ ]] || { pause; exit 0; }
fi

bk=$(mktemp -d)
cp /etc/nginx/conf.d/xray.conf "$bk/" ; cp "$CERT_DIR/xray.crt" "$CERT_DIR/xray.key" "$bk/"
restore(){
  cp "$bk/xray.conf" /etc/nginx/conf.d/xray.conf
  cp "$bk/xray.crt" "$bk/xray.key" "$CERT_DIR/"
  systemctl start nginx
}

systemctl stop nginx; fuser -k 80/tcp 2>/dev/null
if ! "$ACME" --issue -d "$nd" --standalone -k ec-256 \
     --pre-hook "systemctl stop nginx" --post-hook "systemctl start nginx"; then
  err "Penerbitan SSL untuk $nd gagal. Domain lama tetap dipakai."
  restore; rm -rf "$bk"; pause; exit 1
fi
"$ACME" --installcert -d "$nd" --ecc \
  --fullchainpath "$CERT_DIR/xray.crt" --keypath "$CERT_DIR/xray.key" \
  --reloadcmd "systemctl reload nginx 2>/dev/null || true"
chmod 644 "$CERT_DIR/xray.crt"; chmod 600 "$CERT_DIR/xray.key"

sed -i "s/server_name .*;/server_name $nd;/" /etc/nginx/conf.d/xray.conf
if ! nginx -t >/dev/null 2>&1; then
  err "Konfigurasi Nginx tidak valid. Mengembalikan pengaturan lama."
  restore; rm -rf "$bk"; pause; exit 1
fi

echo "$nd" > "$XM_DIR/domain"
"$ACME" --remove -d "$DOMAIN" --ecc >/dev/null 2>&1   # hentikan auto-renew domain lama
systemctl restart nginx; systemctl restart xray
rm -rf "$bk"
ok "Domain diganti ke $nd"
warn "Link akun lama memakai domain lama. Buka 'Lihat detail / link akun' untuk mengambil link baru."
pause
