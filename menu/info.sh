#!/bin/bash
. /usr/local/lib/xm/lib.sh
header "INFO SERVER & LAYANAN"
st(){ systemctl is-active --quiet "$1" && echo -e "${G}running${N}" || echo -e "${R}stopped${N}"; }
echo "Domain     : $DOMAIN"
echo "IP Publik  : $(curl -4s --max-time 5 https://ifconfig.me)"
echo -n "Xray       : "; st xray
echo -n "Nginx      : "; st nginx
echo -n "Cron       : "; st cron
echo "SSL exp    : $(openssl x509 -enddate -noout -in /usr/local/etc/xray/xray.crt 2>/dev/null | cut -d= -f2)"
echo "Akun VLESS : $(grep -c '^vless|' "$DB")"
echo "Akun VMess : $(grep -c '^vmess|' "$DB")"
echo "Akun Trojan: $(grep -c '^trojan|' "$DB")"
pause
