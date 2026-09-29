#!/bin/bash
# bot/cmd/restart.sh - /restart : restart Xray & Nginx
act_restart(){
  systemctl restart xray nginx && echo "🔄 Xray & Nginx di-restart." || echo "❌ Gagal restart layanan."
}
