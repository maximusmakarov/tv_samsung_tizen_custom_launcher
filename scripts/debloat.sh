#!/usr/bin/env bash
# Реклама/телеметрия/лишние приложения на Samsung UE40K6500 (2016, retail Tizen 2.4).
#
# Честно о возможностях retail-прошивки без root:
#   * официальные переключатели приватности (Terms & Policy) — работают и обратимы;
#   * автообновление/Instant ON/Autorun Smart Hub — работают и обратимы;
#   * предустановленные приложения Samsung удалить нельзя (ошибка 132) — только гасить
#     процессы на время и блокировать домены рекламы на уровне сети;
#   * всё, что можно погасить командой, гасится через командный канал (если он есть).
#
#   ./scripts/debloat.sh            # показать план и сделать доступное
#   ./scripts/debloat.sh --dry-run  # только план, ничего не менять
. "$(dirname "$0")/tv-env.sh"
DRY=0; [ "${1:-}" = "--dry-run" ] && DRY=1
B="$ROOT/backup/debloat-$(ts)"; mkdir -p "$B"
CHANGES="$B/CHANGES.md"
echo "# Изменения $(date -Iseconds)" > "$CHANGES"

run() { if [ "$DRY" = 1 ]; then echo "[dry] $*"; else echo "+ $*"; "$@"; fi; }

say() { printf '\n=== %s\n' "$*"; }

say "0) проверить, что ТВ доступен"
tv_api /api/v2/ | python3 -c 'import json,sys;d=json.load(sys.stdin)["device"];print("model:",d.get("modelName"),"devMode:",d.get("developerMode"),"devIP:",d.get("developerIP"))'

say "1) проверить командный канал (backtick-инъекция через 0 appinstall tpk)"
# Безопасный read-only маркер: если канал есть — увидим файл/вывод позже; если нет — ошибка не фатальна.
PROBE_OUT="$B/injection-probe.txt"
{ echo "probe: vconftool get db/appfw/home_appid"; sdb_cmd shell '0 appinstall tpk `vconftool get db/appfw/home_appid`.tpk'; } > "$PROBE_OUT" 2>&1 || true
sed -n '1,6p' "$PROBE_OUT"

say "2) официальные переключатели (делаются пультом; скрипт только напоминает)"
cat <<'TXT'
  Home -> Настройки -> Поддержка -> Условия и политика:
    - Реклама на основе интересов      -> Отключить
    - Информационные услуги просмотра  -> Снять согласие (ACR)
    - Удалённое управление             -> Выкл.
  Настройки -> Поддержка -> Обновление ПО -> Автообновление -> Выкл.
  Настройки -> Система -> Доп. настройки -> Автостарт Smart Hub -> Выкл. (по желанию)
  Настройки -> Система -> Общие -> Samsung Instant ON -> Выкл. (по желанию)
TXT

say "3) погасить фоновые рекламные/телеметрические процессы (только если канал есть)"
# Имена намеренно осторожные: только то, что относится к рекламе/телеметрии TV Plus/ACR/рекламного плеера.
for pat in tvplus-service adplayer ADPlayer adplatform canalysis acr; do
  cmd="pkill -f $pat"
  if [ "$DRY" = 0 ]; then
    sdb_cmd shell "0 appinstall tpk \`$cmd\`.tpk" >/dev/null 2>&1 || true
  fi
  echo "- $cmd" >> "$CHANGES"
  echo "  tried: $cmd"
done

say "4) список установленных приложений (для решения, что ещё гасить)"
sdb_cmd shell 0 vd_applist > "$B/apps.txt" 2>&1 || true
sdb_cmd shell 0 applist >> "$B/apps.txt" 2>&1 || true
wc -l "$B/apps.txt"; sed -n '1,15p' "$B/apps.txt"

say "5) блок-лист рекламных доменов (для роутера, не меняет ТВ)"
cat > "$B/dns-blocklist.txt" <<'DNS'
ads.samsungads.com
samsungads.com
log-ads.samsungacr.com
acr-eu.samsungcloudsolution.com
acr-us.samsungcloudsolution.com
samsungacr.com
DNS
cat "$B/dns-blocklist.txt"

say "готово. Отчёт: $B"
echo "Откат: scripts/restore.sh (настройки — в docs/settings-before.md)"
