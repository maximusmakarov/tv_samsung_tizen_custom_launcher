#!/usr/bin/env bash
# Проверка лаунчера без скриншотов: REST API ТВ умеет отдавать running/visible для приложения.
. "$(dirname "$0")/tv-env.sh"
APP="AiTVLaunch.AiTV"
say(){ printf '\n=== %s\n' "$*"; }

say "1) приложение установлено?"
"$SDB" connect "$TV_SDB" >/dev/null 2>&1
"$SDB" -s "$TV_SDB" shell 0 applist 2>&1 | grep -iE "AiTV" || echo "  НЕ найдено"

say "2) состояние через REST API"
curl -s -m 5 "http://$TV_IP:8001/api/v2/applications/$APP" | python3 -c 'import json,sys; d=json.load(sys.stdin); print({k:d.get(k) for k in ("name","version","running","visible")})' 2>/dev/null || echo "  API недоступен"

say "3) запуск через sdb"
"$SDB" -s "$TV_SDB" shell 0 was_execute "$APP" 2>&1 | tail -2
sleep 3
curl -s -m 5 "http://$TV_IP:8001/api/v2/applications/$APP" | python3 -c 'import json,sys; d=json.load(sys.stdin); print("after launch:", {k:d.get(k) for k in ("running","visible")})' 2>/dev/null

say "4) кто сейчас на переднем плане (проверка плиток: нажмите плитку на ТВ, потом повторите)"
for a in "9Ur5IzDKqV.TizenYouTube" "LuOVXzgX7A.kpTizen" "FD7JrMU4L1.ivi" "O0tF3EHRuU.itv" "4uI12bRGkE.OkkoHD" "RN1MCdNq8t.Netflix"; do
  curl -s -m 3 "http://$TV_IP:8001/api/v2/applications/$a" | python3 -c "import json,sys;d=json.load(sys.stdin);print(f\"  {d.get('name','?'):20s} visible={d.get('visible')}\")" 2>/dev/null
done
