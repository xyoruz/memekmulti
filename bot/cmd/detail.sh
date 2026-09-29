#!/bin/bash
# bot/cmd/detail.sh - /detail <proto> <user> : detail & link akun
acct_text(){ # proto user
  db_has "$1" "$2" || { echo "❌ Akun tidak ditemukan."; return; }
  parse_line "$(db_line "$1" "$2")"
  make_links "$P_PROTO" "$P_ID" "$P_USER"
  local used st; used=$(fmt_bytes "$(usage_bytes "$P_PROTO" "$P_USER")"); st=$(st_label "$P_STATUS" | esc)
  printf '%s\n' "<b>AKUN ${P_PROTO^^}</b>" \
    "Username : $P_USER" \
    "Domain   : $DOMAIN" \
    "UUID     : <code>$P_ID</code>" \
    "Expired  : $P_EXP" \
    "Limit IP : $(lim_txt "$P_IPLIM" IP)" \
    "Kuota    : $(lim_txt "$P_QUOTA" GB)" \
    "Terpakai : $used" \
    "Status   : $st" \
    "Port TLS : 443, 8443" \
    "Port nTLS: 80, 8080, 8880, 2086" \
    "Path     : /$P_PROTO-tls , /$P_PROTO-ntls" \
    "" "Link TLS:" "<code>$(printf '%s' "$L_TLS" | esc)</code>" \
    "" "Link nTLS:" "<code>$(printf '%s' "$L_NTLS" | esc)</code>"
}
