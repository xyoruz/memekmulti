#!/bin/bash
# bot/setup/service.sh - kelola service systemd xm-bot (start, stop, restart, log)
SVC=/etc/systemd/system/xm-bot.service

install_service(){
  cat > "$SVC" <<'EOT'
[Unit]
Description=Xray Manager Telegram Bot
After=network-online.target xray.service
Wants=network-online.target

[Service]
ExecStart=/bin/bash /usr/local/lib/xm/bot/bot.sh
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOT
  systemctl daemon-reload
}

tg_start(){
  need_token || return
  install_service
  systemctl enable --now xm-bot >/dev/null 2>&1; sleep 1
  systemctl is-active --quiet xm-bot && ok "Bot aktif. Kirim /start ke bot kamu." || err "Bot gagal jalan, cek log (menu 7)."
}

tg_stop(){ systemctl disable --now xm-bot >/dev/null 2>&1 && ok "Bot dihentikan."; }

tg_restart(){ systemctl restart xm-bot && ok "Bot di-restart."; }

tg_logs(){ journalctl -u xm-bot -n 30 --no-pager; }
