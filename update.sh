#!/bin/bash
# ==========================================================
#  Update Xray Manager (tanpa install ulang)
#  - Memperbarui semua modul menu dari repo GitHub
#  - Data akun, domain, sertifikat, dan config akun TIDAK diubah
#  - Migrasi otomatis config lama agar mendukung kuota & limit IP
#  Jalankan sebagai root:  bash update.sh   (atau perintah: xm-update)
# ==========================================================

# Isi dengan URL raw repo GitHub kamu (dipakai jika belum tersimpan dari instalasi)
REPO_RAW="https://raw.githubusercontent.com/USER/REPO/main"

R='\033[0;31m'; G='\033[0;32m'; Y='\033[0;33m'; C='\033[0;36m'; N='\033[0m'
die(){ echo -e "${R}Error: $*${N}"; exit 1; }
ok(){ echo -e "${G}✔ $*${N}"; }

XM_DIR=/etc/xray-manager
LIB_DIR=/usr/local/lib/xm
CFG=/usr/local/etc/xray/config.json
XRAY_BIN=/usr/local/bin/xray
MENU_FILES="lib.sh add.sh list.sh show.sh renew.sh del.sh expire.sh info.sh limit.sh reset.sh domain.sh limiter.sh menu"
BOT_FILES="bot.sh setup.sh lib/core.sh lib/keyboard.sh lib/validate.sh cmd/help.sh cmd/add.sh cmd/del.sh cmd/renew.sh cmd/limit.sh cmd/reset.sh cmd/detail.sh cmd/list.sh cmd/info.sh cmd/expire.sh cmd/restart.sh handler/text.sh handler/callback.sh handler/update.sh"

[[ $EUID -eq 0 ]] || die "Jalankan sebagai root."
[[ -d $XM_DIR && -f $XM_DIR/domain ]] || die "Xray Manager belum terinstal. Jalankan multiport.sh dulu."
command -v jq >/dev/null || die "jq tidak ditemukan."

saved=$(cat "$XM_DIR/repo" 2>/dev/null)
[[ -n "$saved" ]] && REPO_RAW=$saved
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)"

fetch(){ # path_di_repo  tujuan
  if [[ -n "$SCRIPT_DIR" && -f "$SCRIPT_DIR/$1" ]]; then
    cp "$SCRIPT_DIR/$1" "$2"
  else
    [[ "$REPO_RAW" != *USER/REPO* ]] || die "Isi REPO_RAW di bagian atas update.sh dengan URL raw repo GitHub kamu."
    wget -q -O "$2" "$REPO_RAW/$1" || die "Gagal mengunduh $1"
  fi
}

echo -e "${C}== Update Xray Manager ==${N}"

# 1. Unduh ke folder sementara & validasi dulu
tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/bot/lib" "$tmp/bot/cmd" "$tmp/bot/handler"
for f in $MENU_FILES; do
  fetch "menu/$f" "$tmp/$f"
  [[ -s "$tmp/$f" ]] || die "File menu/$f kosong."
  bash -n "$tmp/$f" 2>/dev/null || die "File menu/$f tidak valid (syntax error). Update dibatalkan."
done
for f in $BOT_FILES; do
  fetch "bot/$f" "$tmp/bot/$f"
  [[ -s "$tmp/bot/$f" ]] || die "File bot/$f kosong."
  bash -n "$tmp/bot/$f" 2>/dev/null || die "File bot/$f tidak valid (syntax error). Update dibatalkan."
done
fetch update.sh "$tmp/update.sh"
[[ -s "$tmp/update.sh" ]] && bash -n "$tmp/update.sh" 2>/dev/null || die "update.sh dari repo tidak valid."
ok "Semua file berhasil diunduh & divalidasi"

# 2. Backup modul lama
bk=/root/xm-backup-$(date +%Y%m%d-%H%M%S)
cp -a "$LIB_DIR" "$bk" && ok "Backup modul lama: $bk"

# 3. Pasang modul baru
for f in $MENU_FILES update.sh; do
  chmod +x "$tmp/$f"
  mv -f "$tmp/$f" "$LIB_DIR/$f"
done
mkdir -p "$LIB_DIR/bot/lib" "$LIB_DIR/bot/cmd" "$LIB_DIR/bot/handler"
for f in $BOT_FILES; do
  chmod +x "$tmp/bot/$f"
  mv -f "$tmp/bot/$f" "$LIB_DIR/bot/$f"
done
# Migrasi dari struktur lama (bot.sh & telegram.sh dulu ada di folder utama)
rm -f "$LIB_DIR/bot.sh" "$LIB_DIR/telegram.sh" "$LIB_DIR"/bot/lib/{actions,text,handler}.sh
SVC=/etc/systemd/system/xm-bot.service
if [[ -f $SVC ]] && grep -q "$LIB_DIR/bot.sh" "$SVC"; then
  sed -i "s#$LIB_DIR/bot.sh#$LIB_DIR/bot/bot.sh#" "$SVC"
  systemctl daemon-reload
fi
ln -sf "$LIB_DIR/menu" /usr/local/bin/menu
ln -sf "$LIB_DIR/update.sh" /usr/local/bin/xm-update
ok "Modul menu diperbarui"
systemctl is-active --quiet xm-bot && { systemctl restart xm-bot; ok "Bot Telegram di-restart"; }

# 4. Pastikan komponen limit (log, folder, cron) tersedia
mkdir -p "$XM_DIR/usage" /var/log/xray
touch /var/log/xray/access.log /var/log/xray/error.log
chown -R nobody /var/log/xray; chmod 755 /var/log/xray
[[ -f /etc/logrotate.d/xray ]] || cat > /etc/logrotate.d/xray <<'LR'
/var/log/xray/*.log {
    daily
    rotate 3
    missingok
    notifempty
    copytruncate
    compress
}
LR
echo "5 0 * * * root /bin/bash $LIB_DIR/expire.sh >/dev/null 2>&1" > /etc/cron.d/xm-expire
echo "* * * * * root /bin/bash $LIB_DIR/limiter.sh >/dev/null 2>&1" > /etc/cron.d/xm-limiter
chmod 644 /etc/cron.d/xm-expire /etc/cron.d/xm-limiter

# 5. Migrasi config Xray lama (tambah stats/api/log) bila belum ada
restart=0
if ! jq -e '.api' "$CFG" >/dev/null 2>&1; then
  new=$(mktemp)
  jq '. + {
        log: {access:"/var/log/xray/access.log", error:"/var/log/xray/error.log", loglevel:"warning"},
        stats: {},
        api: {tag:"api", services:["StatsService"]},
        policy: {levels:{"0":{statsUserUplink:true, statsUserDownlink:true}}}
      }
      | .inbounds |= ([{tag:"api",listen:"127.0.0.1",port:10085,protocol:"dokodemo-door",settings:{address:"127.0.0.1"}}] + map(select(.tag!="api")))
      | .routing.rules |= ([{type:"field",inboundTag:["api"],outboundTag:"api"}] + (. // []))' "$CFG" > "$new"
  if [[ -s "$new" ]] && "$XRAY_BIN" run -test -config "$new" >/dev/null 2>&1; then
    cp -a "$CFG" "$bk/config.json.bak"
    cat "$new" > "$CFG"; restart=1
    ok "Config Xray dimigrasi (kuota & limit IP aktif)"
  else
    echo -e "${Y}! Migrasi config dilewati (hasil tidak valid). Config lama tidak diubah.${N}"
  fi
  rm -f "$new"
fi
(( restart )) && systemctl restart xray

echo
ok "Update selesai. Ketik ${Y}menu${G} untuk membuka menu terbaru."
