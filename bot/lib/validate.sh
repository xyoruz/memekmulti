#!/bin/bash
# bot/lib/validate.sh - validasi input (protokol & username)
chk(){ # proto user
  valid_proto "$1" || { echo "❌ Protokol harus vless / vmess / trojan."; return 1; }
  [[ "$2" =~ ^[A-Za-z0-9_-]{3,20}$ ]] || { echo "❌ Username tidak valid (3-20, huruf/angka/_/-)."; return 1; }
}
