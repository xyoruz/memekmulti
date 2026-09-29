#!/bin/bash
# bot/cmd/info.sh - /info : info server & jumlah akun
act_info(){
  echo "<b>Info Server</b>"
  echo "Domain : $DOMAIN"
  echo "Xray   : $(systemctl is-active xray)"
  echo "Nginx  : $(systemctl is-active nginx)"
  echo "SSL exp: $(openssl x509 -enddate -noout -in /usr/local/etc/xray/xray.crt 2>/dev/null | cut -d= -f2)"
  echo "VLESS  : $(grep -c '^vless|' "$DB") akun"
  echo "VMess  : $(grep -c '^vmess|' "$DB") akun"
  echo "Trojan : $(grep -c '^trojan|' "$DB") akun"
}
