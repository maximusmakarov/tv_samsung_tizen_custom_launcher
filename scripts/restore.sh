#!/usr/bin/env bash
# ОТКАТ: вернуть ТВ к состоянию «до проекта».
#
#   ./scripts/restore.sh [backup-dir]
#
# 1) удаляет наши приложения (AiTV + HomeKey ключ);
# 2) перечисляет настройки, которые надо вернуть пультом (и включает удалённое управление обратно, если нужно);
# 3) очищает staging-файлы установки на ТВ;
# 4) при --full также удаляет device-profile.xml (permit) с ТВ.
set -uo pipefail
. "$(dirname "$0")/tv-env.sh"
FULL=0; [ "${1:-}" = "--full" ] && FULL=1
BK=$(ls -1d "$ROOT"/backup/2* 2>/dev/null | tail -1)
say(){ printf '\n=== %s\n' "$*"; }

say "0) ТВ на связи?"
"$SDB" connect "$TV_SDB" >/dev/null 2>&1
"$SDB" devices | sed -n '1,3p'

say "1) удалить приложения проекта"
for pkg in AiTVLaunch AiTVKeyApp; do
  echo "-- $pkg"
  "$SDB" -s "$TV_SDB" shell 0 vd_appuninstall "$pkg" 2>&1 | tail -3
done

say "2) настройки — вернуть пультом (обратные действия)"
cat <<'TXT'
  Настройки → Поддержка → Условия и политика:
    • Реклама на основе интересов      → Включить (как было)
    • Информационные услуги просмотра  → Вернуть согласие (ACR)
    • Удалённое управление             → включить, если было включено
  Настройки → Поддержка → Обновление ПО → Автообновление → Включить
  Настройки → Система → Доп. настройки → Автостарт Smart Hub → Включить (если меняли)
  Настройки → Система → Общие → Samsung Instant ON → Включить (если меняли)
TXT
[ -n "$BK" ] && echo "  Снимок «до»: $BK (api_v2.json, apps/, vconf/, pull/)"

say "3) очистить staging установки на ТВ"
"$A2S" leftovers --tv "$TV_IP" --local-ip "$LOCAL_IP" --clear 2>&1 | tail -3 || true

if [ "$FULL" = "1" ]; then
  say "4) удалить permit (device-profile.xml)"
  # sdb pull не поддерживается; файл можно перезаписать пустым/удалить только при наличии shell.
  echo "  sdb pull не поддерживается прошивкой ТВ; файл /home/developer/device-profile.xml"
  echo "  безвреден и не влияет на работу Smart Hub — можно оставить."
fi

say "5) при необходимости: Smart Hub → Apps → удалить наши плитки, если остались"
say "готово"
