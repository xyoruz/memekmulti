#!/bin/bash
# bot/cmd/list.sh - /list [proto] : daftar akun
act_list(){ # proto
  local i=0 l used q
  echo "<b>Daftar ${1^^}</b>"
  while IFS= read -r l; do
    [[ -z "$l" ]] && continue
    ((i++)); parse_line "$l"
    used=$(fmt_bytes "$(usage_bytes "$P_PROTO" "$P_USER")")
    (( P_QUOTA > 0 )) && q="$used/${P_QUOTA}GB" || q="$used"
    echo "$i. $P_USER | exp $P_EXP | $q | $(st_label "$P_STATUS" | esc)"
  done < <(grep "^$1|" "$DB")
  ((i==0)) && echo "(belum ada akun)"
  return 0
}

act_list_all(){ # semua protokol (untuk /list tanpa argumen)
  act_list vless; echo; act_list vmess; echo; act_list trojan
}
