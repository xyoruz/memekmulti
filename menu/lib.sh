#!/bin/bash
XM_DIR=/etc/xray-manager
DB=$XM_DIR/users.db            # format: proto|user|uuid|exp|kuotaGB|limitIP|status
USAGE_DIR=$XM_DIR/usage        # pemakaian trafik (byte) per akun
CFG=/usr/local/etc/xray/config.json
XRAY_BIN=/usr/local/bin/xray
XRAY_LOG=/var/log/xray/access.log
API_ADDR=127.0.0.1:10085
IP_WINDOW_MIN=2                # jendela deteksi IP aktif (menit)
IP_LOCK_MIN=15                 # lama kunci jika melebihi limit IP (menit)
GB=1073741824
DOMAIN=$(cat "$XM_DIR/domain" 2>/dev/null)

R='\033[0;31m'; G='\033[0;32m'; Y='\033[0;33m'; C='\033[0;36m'; N='\033[0m'
ok(){   echo -e "${G}✔ $*${N}"; }
warn(){ echo -e "${Y}! $*${N}"; }
err(){  echo -e "${R}✘ $*${N}"; }
line(){ echo -e "${C}=================================================${N}"; }
header(){ clear; line; echo -e "${C}  $*${N}"; line; }
pause(){ echo; read -rp "Tekan Enter untuk kembali..." _; }

[[ $EUID -eq 0 ]] || { err "Jalankan sebagai root."; exit 1; }
touch "$DB"; mkdir -p "$USAGE_DIR"

# Kirim notifikasi Telegram ke admin (HTML). Diam jika bot belum diatur / notifikasi off.
tg_notify(){
  [[ -f "$XM_DIR/telegram.conf" ]] || return 0
  (
    . "$XM_DIR/telegram.conf"
    [[ -n "$TG_TOKEN" && -n "$TG_ADMIN" && "$TG_NOTIFY" != off ]] || exit 0
    for a in ${TG_ADMIN//,/ }; do
      curl -s --max-time 15 "https://api.telegram.org/bot$TG_TOKEN/sendMessage" \
        --data-urlencode "chat_id=$a" --data-urlencode "text=$1" -d parse_mode=HTML >/dev/null
    done
  ) 9>&- >/dev/null 2>&1 &
}

valid_proto(){ [[ "$1" =~ ^(vless|vmess|trojan)$ ]]; }

# ---------- config Xray ----------
cfg_edit(){
  local tmp; tmp=$(mktemp)
  if jq "$@" "$CFG" > "$tmp" && [[ -s "$tmp" ]]; then
    cat "$tmp" > "$CFG"; rm -f "$tmp"
  else
    rm -f "$tmp"; return 1
  fi
}

xray_add(){ # proto user id
  local p=$1 u=$2 id=$3 obj
  case $p in
    vless)  obj=$(jq -cn --arg id "$id" --arg e "$u@$p" '{id:$id,email:$e,level:0}') ;;
    vmess)  obj=$(jq -cn --arg id "$id" --arg e "$u@$p" '{id:$id,email:$e,alterId:0,level:0}') ;;
    trojan) obj=$(jq -cn --arg id "$id" --arg e "$u@$p" '{password:$id,email:$e,level:0}') ;;
  esac
  cfg_edit --arg p "$p" --argjson o "$obj" \
    '.inbounds |= map(if .protocol==$p then .settings.clients += [$o] else . end)'
}

xray_del(){ # proto user
  cfg_edit --arg e "$2@$1" \
    '.inbounds |= map(if .settings.clients then .settings.clients |= map(select(.email != $e)) else . end)'
}

xray_apply(){
  if "$XRAY_BIN" run -test -config "$CFG" >/dev/null 2>&1; then
    systemctl restart xray
  else
    err "Config Xray tidak valid, perubahan tidak diterapkan."; return 1
  fi
}

# ---------- database akun ----------
db_has(){  grep -q "^$1|$2|" "$DB"; }
db_line(){ grep -m1 "^$1|$2|" "$DB"; }

parse_line(){ # isi: P_PROTO P_USER P_ID P_EXP P_QUOTA P_IPLIM P_STATUS
  IFS='|' read -r P_PROTO P_USER P_ID P_EXP P_QUOTA P_IPLIM P_STATUS <<<"$1"
  P_QUOTA=${P_QUOTA:-0}; P_IPLIM=${P_IPLIM:-0}; P_STATUS=${P_STATUS:-active}
}

db_set(){ # proto user kolom nilai   (4=exp 5=kuota 6=limitIP 7=status)
  awk -F'|' -v OFS='|' -v p="$1" -v u="$2" -v i="$3" -v v="$4" \
    '$1==p && $2==u { while (NF<7) $(NF+1)=""; $i=v } { print }' "$DB" > "$DB.tmp" \
    && cat "$DB.tmp" > "$DB"
  rm -f "$DB.tmp"
}

# ---------- kuota & status ----------
usage_bytes(){ cat "$USAGE_DIR/$1_$2" 2>/dev/null || echo 0; }
usage_reset(){ echo 0 > "$USAGE_DIR/$1_$2"; }
fmt_bytes(){ awk -v b="$1" 'BEGIN{split("B KB MB GB TB",u," ");i=1;while(b>=1024&&i<5){b/=1024;i++}printf "%.2f %s",b,u[i]}'; }
lim_txt(){ (( $1 > 0 )) && echo "$1 $2" || echo "Tanpa batas"; }
st_label(){
  case $1 in
    active) echo "aktif" ;;
    quota)  echo "KUOTA HABIS" ;;
    ip:*)   echo "LOCK IP (sampai $(date -d "@${1#ip:}" +%H:%M))" ;;
    *)      echo "$1" ;;
  esac
}

lock_user(){ # proto user status  -> hapus dari config, tandai di db (panggil xray_apply setelahnya)
  xray_del "$1" "$2"; db_set "$1" "$2" 7 "$3"
}
unlock_user(){ # proto user
  parse_line "$(db_line "$1" "$2")"
  xray_add "$1" "$2" "$P_ID" && db_set "$1" "$2" 7 active
}

# Pilih akun dari daftar. Hasil: P_PROTO P_USER P_ID P_EXP P_QUOTA P_IPLIM P_STATUS
pick_user(){
  local p=$1 i=0 l n
  mapfile -t ULIST < <(grep "^$p|" "$DB")
  if ((${#ULIST[@]}==0)); then warn "Belum ada akun ${p^^}."; return 1; fi
  for l in "${ULIST[@]}"; do
    ((i++)); parse_line "$l"
    printf " %2d) %-16s exp: %s  [%s]\n" "$i" "$P_USER" "$P_EXP" "$(st_label "$P_STATUS")"
  done
  echo; read -rp "Pilih nomor (0 = batal): " n
  [[ "$n" =~ ^[0-9]+$ ]] && ((n>=1 && n<=${#ULIST[@]})) || return 1
  parse_line "${ULIST[n-1]}"
}

# ---------- link akun ----------
make_links(){ # proto id user  -> L_TLS, L_NTLS
  local p=$1 id=$2 u=$3 d=$DOMAIN j1 j2
  case $p in
    vless)
      L_TLS="vless://$id@$d:443?encryption=none&security=tls&sni=$d&type=ws&host=$d&path=%2Fvless-tls#$u-TLS"
      L_NTLS="vless://$id@$d:80?encryption=none&security=none&type=ws&host=$d&path=%2Fvless-ntls#$u-nTLS" ;;
    vmess)
      j1=$(jq -cn --arg ps "$u-TLS" --arg d "$d" --arg id "$id" \
        '{v:"2",ps:$ps,add:$d,port:"443",id:$id,aid:"0",scy:"auto",net:"ws",type:"none",host:$d,path:"/vmess-tls",tls:"tls",sni:$d}')
      j2=$(jq -cn --arg ps "$u-nTLS" --arg d "$d" --arg id "$id" \
        '{v:"2",ps:$ps,add:$d,port:"80",id:$id,aid:"0",scy:"auto",net:"ws",type:"none",host:$d,path:"/vmess-ntls",tls:""}')
      L_TLS="vmess://$(echo -n "$j1" | base64 -w0)"
      L_NTLS="vmess://$(echo -n "$j2" | base64 -w0)" ;;
    trojan)
      L_TLS="trojan://$id@$d:443?security=tls&sni=$d&type=ws&host=$d&path=%2Ftrojan-tls#$u-TLS"
      L_NTLS="trojan://$id@$d:80?security=none&type=ws&host=$d&path=%2Ftrojan-ntls#$u-nTLS" ;;
  esac
}

show_account(){ # proto user id exp
  local p=$1 u=$2 id=$3 e=$4 ql il st
  parse_line "$(db_line "$p" "$u")"; ql=$P_QUOTA; il=$P_IPLIM; st=$P_STATUS
  make_links "$p" "$id" "$u"
  line; echo -e "${C}          AKUN ${p^^}${N}"; line
  echo "Username   : $u"
  echo "Domain     : $DOMAIN"
  echo "UUID/Pass  : $id"
  echo "Expired    : $e"
  echo "Limit IP   : $(lim_txt "$il" IP)"
  echo "Kuota      : $(lim_txt "$ql" GB)"
  echo "Terpakai   : $(fmt_bytes "$(usage_bytes "$p" "$u")")"
  echo "Status     : $(st_label "$st")"
  echo "Port TLS   : 443, 8443"
  echo "Port nTLS  : 80, 8080, 8880, 2086"
  echo "Network    : WebSocket (WS)"
  echo "Path TLS   : /$p-tls"
  echo "Path nTLS  : /$p-ntls"
  line
  echo -e "${Y}Link TLS  :${N}\n$L_TLS\n"
  echo -e "${Y}Link nTLS :${N}\n$L_NTLS"
  line
}
