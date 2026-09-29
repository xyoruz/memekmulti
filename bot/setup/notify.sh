#!/bin/bash
# bot/setup/notify.sh - nyalakan/matikan notifikasi kunci akun & expired
tg_notify(){
  [[ "$TG_NOTIFY" == on ]] && TG_NOTIFY=off || TG_NOTIFY=on
  need_token && save_conf
  ok "Notifikasi: $TG_NOTIFY"
}
