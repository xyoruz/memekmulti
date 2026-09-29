# Multiport Xray Manager

Autoscript Xray **VLESS, VMess, Trojan (WebSocket)** + Nginx, multi-port TLS & nTLS,
dengan menu manajemen akun (masa aktif, limit IP, limit kuota) dan ganti domain.

- OS: Ubuntu 20.04/22.04, Debian 10/11/12
- Jalankan sebagai **root**, domain harus sudah mengarah ke IP VPS (Cloudflare proxy dimatikan)

## Instalasi

Ganti `USER` dan `REPO`, dan isi `REPO_RAW` di bagian atas `multiport.sh` dan `update.sh`.

```bash
wget -O multiport.sh https://raw.githubusercontent.com/xyoruz/memekmulti/main/multiport.sh && bash multiport.sh
```

Setelah selesai ketik `menu`.

## Update

```bash
xm-update
```

## Port

| Jenis | Port |
|---|---|
| TLS | 443, 8443 |
| nTLS | 80, 8080, 8880, 2086 |

| Path | Protokol |
|---|---|
| /vless-tls, /vless-ntls | VLESS |
| /vmess-tls, /vmess-ntls | VMess |
| /trojan-tls, /trojan-ntls | Trojan |

## Struktur

```
multiport.sh        installer
update.sh           updater (perintah: xm-update)
config/xray.json    konfigurasi dasar Xray
menu/               menu & manajemen akun (VPS)
├── lib.sh          fungsi bersama (dipakai menu & bot)
├── menu            menu utama
├── add.sh          buat akun
├── list.sh         daftar akun
├── show.sh         detail & link akun
├── renew.sh        perpanjang akun
├── limit.sh        ubah limit IP & kuota
├── reset.sh        reset pemakaian / buka kunci
├── del.sh          hapus akun
├── expire.sh       hapus akun expired (cron harian)
├── limiter.sh      penegak kuota & limit IP (cron tiap menit)
├── domain.sh       ganti domain
└── info.sh         info server
bot/                bot Telegram (service: xm-bot)
├── bot.sh          entry point & loop utama
├── setup.sh        menu pengaturan bot (menu utama no. 9)
├── lib/            dasar
│   ├── core.sh         config, API Telegram, kirim pesan, cek admin, lock
│   ├── keyboard.sh     inline keyboard
│   └── validate.sh     validasi protokol & username
├── cmd/            satu file per perintah
│   ├── add.sh          /add       buat akun
│   ├── del.sh          /del       hapus akun
│   ├── renew.sh        /renew     perpanjang akun
│   ├── limit.sh        /limit     ubah limit kuota & IP
│   ├── reset.sh        /reset     reset pemakaian
│   ├── detail.sh       /detail    detail & link akun
│   ├── list.sh         /list      daftar akun
│   ├── info.sh         /info      info server
│   ├── expire.sh       /expire    hapus akun expired
│   ├── restart.sh      /restart   restart Xray & Nginx
│   └── help.sh         /help      teks bantuan
└── handler/        router
    ├── text.sh         perintah teks -> cmd/*
    ├── callback.sh     tombol inline -> cmd/*
    └── update.sh       cek admin & terima update masuk
```

Menambah perintah baru: buat `bot/cmd/nama.sh` (fungsi `act_nama`), daftarkan di `BOT_FILES`
(`multiport.sh` & `update.sh`), lalu tambahkan satu baris di `bot/handler/text.sh`.

Lokasi terpasang di VPS: `/usr/local/lib/xm/` (menu) dan `/usr/local/lib/xm/bot/` (bot).

## Bot Telegram

1. Buat bot di [@BotFather](https://t.me/BotFather), salin tokennya.
2. Ketik `menu` → **9) Bot Telegram** (`bot/setup.sh`) → *Atur token & ID admin* → *Aktifkan bot*.
3. Kirim `/start` ke bot. Kalau ID admin belum diatur, bot menampilkan ID kamu; isi ID itu di menu 1.
4. Perintah: `/menu`, `/add`, `/del`, `/renew`, `/limit`, `/reset`, `/detail`, `/list`, `/info`, `/expire`, `/restart`, `/help`.
   Contoh: `/add vless budi 30 10 2` (30 hari, kuota 10 GB, 2 IP).
5. Notifikasi otomatis ke admin saat akun terkunci (kuota/IP) atau dihapus karena expired (bisa dimatikan di menu).

## Catatan

- Limit IP membaca IP klien dari header `X-Forwarded-For` yang dikirim Nginx.
  Pastikan `/var/log/xray/access.log` menampilkan IP asli klien, bukan `127.0.0.1`.
- Akun yang melebihi limit IP dikunci 15 menit; akun yang kuotanya habis dikunci
  sampai di-reset atau kuotanya dinaikkan.
- Data akun ada di `/etc/xray-manager/users.db`
  (`proto|user|uuid|exp|kuotaGB|limitIP|status`).
