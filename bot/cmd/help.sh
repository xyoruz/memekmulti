#!/bin/bash
# bot/cmd/help.sh - /help : teks bantuan
HELP_TXT=$'<b>Perintah</b>\n/menu - menu tombol\n/add &lt;proto&gt; &lt;user&gt; &lt;hari&gt; [kuotaGB] [limitIP]\n/del &lt;proto&gt; &lt;user&gt;\n/renew &lt;proto&gt; &lt;user&gt; &lt;hari&gt;\n/limit &lt;proto&gt; &lt;user&gt; &lt;kuotaGB&gt; &lt;limitIP&gt;\n/reset &lt;proto&gt; &lt;user&gt;\n/detail &lt;proto&gt; &lt;user&gt;\n/list [proto]\n/info\n/expire\n/restart\n\nproto = vless | vmess | trojan\nContoh: <code>/add vless budi 30 10 2</code>\n(kuota 0 / limit IP 0 = tanpa batas)'
