#!/usr/bin/env bash
# Собрать, подписать сертификатом Samsung и установить AiTV + HomeKey на ТВ.
#
# Требования:
#   * ТВ в режиме разработчика, Host PC IP = 192.168.0.10, ТВ перезагружен;
#   * сертификат Samsung "Public", привязанный к DUID этого ТВ
#     (apps2samsung-cli cert --tv 192.168.0.100 --local-ip 192.168.0.10 --prepare,
#      вход в аккаунт Samsung в браузере — один раз);
#   * профиль Tizen CLI `samsung` с этим сертификатом (см. toolchain/README.md).
#
#   ./scripts/install-launcher.sh [--launch]
set -uo pipefail
. "$(dirname "$0")/tv-env.sh"
LAUNCH=0; [ "${1:-}" = "--launch" ] && LAUNCH=1
CERTDIR="$HOME/Library/Application Support/Apps2Samsung/Certificate/<CERT_PROFILE> - Public"
OUT="$ROOT/tmp/install"; mkdir -p "$OUT"
say(){ printf '\n=== %s\n' "$*"; }

say "0) проверка ТВ"
"$SDB" connect "$TV_SDB" >/dev/null 2>&1
"$SDB" devices | sed -n '1,3p'
"$SDB" -s "$TV_SDB" shell 0 uname >/dev/null 2>&1 || { echo "sdb shell недоступен — проверьте режим разработчика"; exit 3; }

say "1) сертификат и permit"
[ -f "$CERTDIR/device-profile.xml" ] || { echo "нет $CERTDIR/device-profile.xml — сначала создайте сертификат"; exit 4; }
"$TIZEN" install-permit -s "$TV_SDB" 2>&1 | tail -2

say "2) сборка и подпись (Tizen-CLI профиль samsung, SHA-256)"
( cd "$ROOT/launcher" && ./gen_config.py && ./build.sh >/dev/null )
rm -f "$OUT"/*.wgt
"$TIZEN" package -t wgt -s samsung -o "$OUT" -- "$ROOT/launcher/AiTV"   2>&1 | grep -E "Package File"
"$TIZEN" package -t wgt -s samsung -o "$OUT" -- "$ROOT/launcher/HomeKey" 2>&1 | grep -E "Package File"

say "3) установка"
"$SDB" -s "$TV_SDB" push "$OUT/AiTV.wgt" /opt/usr/apps/tmp/AiTV.wgt >/dev/null 2>&1
"$SDB" -s "$TV_SDB" shell 0 vd_appinstall AiTVLaunch /opt/usr/apps/tmp/AiTV.wgt 2>&1 | tail -4
HK=$(ls "$OUT"/*HomeKey*.wgt 2>/dev/null | head -1)
if [ -n "$HK" ]; then
  "$SDB" -s "$TV_SDB" push "$HK" /opt/usr/apps/tmp/HomeKey.wgt >/dev/null 2>&1
  "$SDB" -s "$TV_SDB" shell 0 vd_appinstall AiTVKeyApp /opt/usr/apps/tmp/HomeKey.wgt 2>&1 | tail -4
fi

say "4) проверка"
"$SDB" -s "$TV_SDB" shell 0 applist | grep -iE "AiTV" || echo "  (не найдено в applist)"

if [ "$LAUNCH" = "1" ]; then
  say "5) запуск"
  "$SDB" -s "$TV_SDB" shell 0 was_execute AiTVLaunch.AiTV 2>&1 | tail -2
fi
say "готово. Откат: ./scripts/restore.sh"
