# Как повторить «умный» минималистичный лаунчер на Samsung Tizen TV — инструкция для ИИ-агента

> **Где что лежит.** Этот репозиторий — методичка: пошаговый план (`PLAN.md`), инструкция для
> ИИ-агента (этот файл) и технические документы (`docs/`), снятые с рабочего проекта. Команды ниже
> ссылаются на структуру полного рабочего проекта (`toolchain/`, `launcher/`, `scripts/`, `backup/`,
> `tv/`). Её можно воссоздать по шагам `PLAN.md`; если у вас уже есть такая папка — просто выполняйте
> команды из её корня.

Это пошаговое руководство для другого ИИ-агента (или человека), который должен повторить
результат проекта **tele_samsung**: взять старый Samsung Smart TV на Tizen, безопасно
разобраться с рекламой/телеметрией, поставить свой лаунчер в стиле Apple TV и доказать
каждый шаг проверкой. Все пути и команды — относительно корня проекта.

> **Главное правило.** Ничего не удалять и не отключать без явного согласия владельца.
> Перед любым изменением — резервная копия и зафиксированный путь отката. Каждый шаг
> проверяется фактами (снимок экрана/лог/статус API), а не предположением.

---

## 0. Целевое состояние (definition of done)

1. ТВ найден в сети, определена модель/прошивка/платформа, зафиксирована возможность root.
2. Включён режим разработчика, работает SDB-канал и (при желании) websocket-пульт.
3. Снят baseline-бэкап: список приложений, `/api/v2/`, фото экранов настроек, план отката.
4. Реклама/телеметрия/OTA выключены **официальными настройками** (без удаления приложений),
   для рекламы дополнительно подготовлен DNS-блоклист для роутера.
5. Установлен собственный лаунчер (Tizen web app) со своим доком, обоями и навигацией пультом.
6. Поведение клавиш зафиксировано формальной спецификацией (`docs/launcher-spec.md`).
7. Каждый шаг проверен кадром с камеры и/или статусом API; отчёт и restore-скрипт готовы.

---

## 1. Что понадобится

| Что | Зачем |
|---|---|
| Mac (или Linux) с сетью в той же подсеть, что ТВ | сборка/подпись/установка, диагностика |
| Samsung-аккаунт **не нужен**, но нужен сертификат Samsung Public, привязанный к DUID ТВ | установка сторонних web-приложений |
| Пульт (или websocket-пульт с Mac) | навигация по диалогам ТВ |
| Телефон с камерой **или** камера Mac | визуальная проверка экрана (скриншотов по сети у Tizen 2.4 нет) |
| `sdb` (Samsung Smart Development Bridge) + Tizen CLI | установка/запуск приложений |
| Опционально: роутер под управлением | DNS-блокировка рекламы |

Установленный на Mac инструментарий этого проекта: `toolchain/bin/sdb`, `toolchain/tizen-studio`,
обёртки `toolchain/sdb.sh`, `toolchain/tizen.sh`, `toolchain/tv-ready.sh`.

---

## 2. Фаза 0 — безопасность и обратимость

1. Создать рабочую копию проекта и каталог `backup/<YYYYMMDD-HHMMSS>/`.
2. **До любых изменений** выполнить `scripts/backup.sh` (сохраняет `/api/v2/`, попытки
   `applist`, `vconf/*`), сделать фото всех экранов настроек.
3. Проверить, что `scripts/restore.sh` запускается и умеет вернуть состояние (прочитать, а не
   только написать).
4. Записать в `backup/<ts>/CHANGES.md` каждое изменение: что, где, «было → стало», как откатить.
5. Не удалять приложения из системы: на retail-прошивке это невозможно без root
   (`error 132`), а попытки ломают доверие владельца. Только штатные переключатели и свой UI.

---

## 3. Фаза 1 — найти ТВ и снять «паспорт»

```bash
# ARP/скан подсети: ищем MAC Samsung и открытые порты 8001/8002/26101
arp -a | grep -i samsung
for ip in 192.168.0.{1..254}; do nc -z -G1 $ip 8001 2>/dev/null && echo "$ip REST"; done
```

```bash
# Паспорт устройства (REST, без авторизации)
curl -s http://<IP>:8001/api/v2/ | tee backup/<ts>/api_v2.json
```

Зафиксировать: `modelName`, `model`, `firmwareVersion`, `DUID`, `developerMode`, `developerIP`,
`networkType`, поддержку AirPlay/Smart View. Ключевой вывод — **точная платформа**
(например, `Tizen 2.4.0`, `16_HAWKM_FHD`, ARMv7): от неё зависит, возможен ли root и какие
API поддерживает WebKit.

Проверить по портам:

| Порт | Сервис | Использование |
|---|---|---|
| `26101` | SDB | установка/запуск приложений, `applist` |
| `8001` | REST API (`/api/v2/`) | паспорт ТВ, статусы приложений |
| `8002` | websocket remote-control (`samsung.remote.control`) | эмуляция пульта |

---

## 4. Фаза 2 — режим разработчика и SDB

Порядок на этом поколении ТВ (RU-прошивка), подробности и фото — `docs/devmode-dialog.md`:

1. ТВ → **Apps** → набрать `12345` пультом → откроется диалог `Developer mode`.
2. `ENTER` (кнопка `Вкл.`), затем `DOWN` → строка `Host PC IP`.
3. Ввести IP Mac по октетам: цифры → `KEY_RIGHT` между октетами (автоперехода нет!):
   `192` `RIGHT` `168` `RIGHT` `0` `RIGHT` `9`.
4. `DOWN` → `OK` → `ENTER`. Диалог закрывается, настройка **только застолблена**.
5. **Перезагрузить ТВ** (питание) и подождать: REST должен показать `developerMode: 1`,
   `developerIP: "<IP Mac>"`, порт `26101` — открытым.
6. Подключиться:

```bash
./toolchain/sdb.sh connect <IP>:26101
./toolchain/sdb.sh -s <IP>:26101 shell 0 applist    # список установленных приложений
```

Важно: диалог управляется только клавишами; если он «залип», `KEY_RETURN` его закрывает,
`12345` открывает заново. Сам диалог REST не обновляет — только после перезагрузки.

---

## 5. Фаза 3 — проверить, что вообще разрешено (gates)

Перед планированием работ обязательно проверить три вещи — они определяют весь маршрут.

### 5.1. Возможности SDB
```bash
./toolchain/sdb.sh -s <IP>:26101 capability
# на UE40K6500: secure_protocol=enabled, intershell_support=disabled,
# rootonoff_support=disabled, sdbd_plugin_version=1.0.0, filesync_support=push
```
Протестировать безопасные shell-команды (`0` = shell-уровень):
```bash
./toolchain/sdb.sh -s <IP>:26101 shell 0 applist
./toolchain/sdb.sh -s <IP>:26101 shell 0 uname
```
Если всё, кроме узкого набора (`applist`, `vd_appinstall`, `vd_appuninstall`, `was_execute`,
`getduid`, `getappinstallpath`, `uname`), отвечает `closed` — прямого shell/root-пути нет.

### 5.2. Браузер ТВ (важно для root-методов)
Открыть на ТВ встроенный браузер на локальной странице, которая печатает
`navigator.userAgent` и `typeof WebAssembly`. Пример: слушать `python3 -m http.server` на Mac
и отправить с ТВ запрос.
- `Tizen 2.4.0 ... AppleWebKit/538.1` и `WebAssembly` **отсутствует** → Chromium/WasmGC
  эксплойты невозможны; root-методы, которым нужен Chromium 120+, не применимы.

### 5.3. Root: быстро отсечь невозможное
Прочитать `docs/root-assessment.md`. Минимальные проверки:
- наличие `/usr/bin/dotnet`, `/dev/video40`, Chromium (обычно отсутствуют);
- модель/прошивка подходит под SamyGO K-root? (только старые `T-JZ*`/`T-HKMFK*` ≤ 1169.2);
- поддержка USB-root (Kant-M2 и подобные) — только 2018+/Tizen 4.0+;
- работает ли инъекция через SDB (`;`, `$()`, backtick) — на 2.4 не работает.

**Если root невозможен** (типично для 2016 retail) → маршрут: штатные настройки + свой
web-лаунчер. Если root возможен → другой проект, но правило «бэкап и обратимость» сохраняется.

---

## 6. Фаза 4 — baseline-бэкап

```bash
./scripts/backup.sh          # backup/<ts>/: api_v2.json, applist, vconf (если пустят), фото
./scripts/snapshot.sh        # снимок состояния после каждого этапа
```

Сохранить в `backup/<ts>/`:
- `api_v2.json`, вывод `applist` (id, имя, версия, установщик);
- фото экранов настроек «до» (`backup/<ts>/photos/…`);
- текущие значения переключателей конфиденциальности (`docs/settings-before.md`);
- черновик restore: какие действия и в каком порядке откатываются.

---

## 7. Фаза 5 — реклама и телеметрия без удаления приложений

Порядок (проверено на UE40K6500, фото в `backup/photos/`):

1. **Home → Настройки → Параметры конфиденциальности → «Условия, политика конфиденциальности»**:
   - снять согласие Interest Based Advertisement (персонализированная реклама);
   - снять согласие Viewing Information Services (ACR, телеметрия просмотра);
   - голосовые сервисы — отключить/не соглашаться;
   - Online Remote Management / Удалённое управление → **Выкл.**
2. **Обновление ПО → Автообновление → Выкл.** (чтобы прошивка не вернула рекламные сервисы).
3. Рекомендуемые для владельца пункты (спросить!): `Автостарт Smart Hub` → Выкл.,
   `Samsung Instant ON` → Выкл.
4. Реклама в Smart Hub полностью не выключается настройками → подготовить **DNS-блоклист**
   для роутера (`scripts/debloat.sh` формирует `backup/<ts>/dns-blocklist.txt`), например:
   `samsungads.com`, `ads.samsungads.com`, `*.samsungacr.com`, `acr*.samsungcloudsolution.com`.
   Осторожно с `*.samsungcloudcdn.com` — он также возит обновления приложений.
5. **Не удалять и не отключать приложения** (на retail нельзя, `error 132`); ничего не теряется,
   всё возвращается теми же переключателями.

Проверка: фото экрана с пустым чекбоксом, REST/`vconf` (если доступен), запись в `CHANGES.md`.

---

## 8. Фаза 6 — установка своего Tizen web-приложения

### 8.1. Сертификат
Установка на телевизор требует сертификата **Samsung Public**, привязанного к DUID ТВ
(Tizen-CA/self-signed дают `install failed[118]`). Инструмент Apps2Samsung CLI создаёт профиль:

```bash
apps2samsung-cli cert --prepare --tv <IP> --local-ip <IP Mac>
# артефакты: ~/Library/Application Support/Apps2Samsung/Certificate/<...>/author.p12,
#            distributor.p12, device-profile.xml
```

Tizen CLI-профиль `samsung` прописать в `toolchain/tizen-studio-data/profile/profiles.xml`
(в этом проекте уже сделано). На Tizen 2.4 подпись принимается только **SHA-256** —
сигнер пропатчен (`org.tizen.common.sign_*.jar`, класс `TizenIncrementalSigner`), иначе
получите ошибку подписи.

### 8.2. Манифест приложения (`config.xml`)
- `tizen:application id="<Package>.<App>"` — **package id ровно 10 символов**, иначе
  `install failed[118]`;
- `required_version="2.3"` (не выше, чем реальная платформа), `tizen:profile name="tv-samsung"`;
- привилегии: `internet`, `application.launch`, для HDMI — `tv.window`, для ключей — `tv.inputdevice`;
- `tizen:setting screen-orientation="landscape" context-menu="disable" background-support="enable" hwkey-event="enable"`;
- иконка `icon.png` в корне пакета.

### 8.3. Сборка → подпись → установка → запуск

```bash
# 1) собрать wgt (package)
./toolchain/tizen.sh package -t wgt -s samsung -o "$(pwd)/tmp/final" -- launcher/AiTV

# 2) закинуть и установить через SDB
./toolchain/sdb.sh -s <IP>:26101 push tmp/final/AiTV.wgt /opt/usr/apps/tmp/AiTV.wgt
./toolchain/sdb.sh -s <IP>:26101 shell 0 vd_appinstall AiTVLaunch /opt/usr/apps/tmp/AiTV.wgt

# 3) запустить
./toolchain/sdb.sh -s <IP>:26101 shell 0 was_execute AiTVLaunch.AiTV
```

Типовые ошибки: `install failed[118]` — не тот сертификат/длина package id/подпись SHA-512;
`download failed[16]` — неверный путь к .wgt при `push`; «файл не найден» после перезагрузки —
переустановить; остатки в `/opt/usr/apps/tmp` безвредны.

---

## 9. Фаза 7 — устройство лаунчера (что внутри и почему)

Структура проекта: `launcher/AiTV` (сам лаунчер), `launcher/HomeKey` (маленькое приложение
«домашняя кнопка»/запуск при включении), `launcher/build.sh`, `launcher/gen_config.py`,
`launcher/scripts/make_icons.py`, `launcher/scripts/fetch_wallpapers.sh`,
`launcher/scripts/validate.sh`.

Ключевые решения (проверены на этом ТВ):

| Проблема | Решение |
|---|---|
| На `file://` в WebKit 2.4 заблокирован XHR к локальным `js/apps.json` | `gen_config.py` генерирует `js/config.js` с `window.AITV_CONFIG = {...}` — конфиг встроен |
| Конфиг должен пережить перезагрузку ТВ | всё в пакете, никаких сетевых зависимостей |
| Возврат из приложения должен быть мгновенным | `background-support="enable"`, на `focus` только перерисовка, без декодирования обоев |
| Обои 1280×720 дорого декодировать | 6 обоев 960×540 JPEG q60, два `<div>`-слоя, смена 45 с |
| Иконки тяжёлые для памяти | 176 px PNG, ленивая загрузка иконок сетки |
| ТВ убивает фоновое web-приложение при тяжёлом плеере | флаг `"heavy": true` у Wink/Okko → после запуска лаунчер сам вызывает `getCurrentApplication().exit()` |
| Возврат после тяжёлого плеера (ТВ не знает, куда возвращаться) | по умолчанию лаунчер память не отдаёт; если включить `heavy`, возврат — вручную: Home → Smart Hub → APPS → AiTV |
| Нет скриншотов по сети | камера Mac (`TeleCam.app`) или телефон + `tv/snap.py` |

Поведение и инварианты зафиксированы в **`docs/launcher-spec.md`** (v3.3): состояния, клавиши,
действия плиток, правила Home, приёмочные тесты T1–T6. Изменяя лаунчер, меняйте спеку и тесты вместе.

Что нельзя на Tizen 2.4 (не тратьте время):
- **Home перехватить нельзя**: нет API, `vconf home_appid` закрыт; нажатие Home всегда открывает
  Samsung Smart Hub. Возврат лаунчера после Back из приложения делает сама платформа.
- **Системные приложения (Smart Hub `org.tizen.menu`, настройки) нельзя ни запустить, ни поднять**
  из public-приложения: `launch()` возвращает success, но экран не меняется; с привилегиями
  `appmanager.*` — то же; `launchAppControl(eden_resume/default)` — то же. Плитку «Smart Hub»
  делать бессмысленно.
- `visible` в REST `/api/v2/applications/<id>` **не отражает передний план** (у приложения на
  экране `visible:false`); `getAppsContext()` не даёт foreground; `document.visibilityState`
  при уходе в фон не меняется — надёжны только `focus`/`blur`.
- root недоступен: см. `docs/root-assessment.md`.

---

## 10. Фаза 8 — визуальная самопроверка (обязательно)

На Tizen 2.4 нет сетевых скриншотов, поэтому проверка — только камера. В проекте есть два пути:

**A. Камера Mac (лучше):** `TeleCam.app` — собранный Swift/AVFoundation агент, каждые 2 с пишет
`backup/live/tv-latest.jpg`. Запуск: `open TeleCam.app`, остановка: `pkill -f TeleCam`.
Проверка кадра — визуально (ИИ смотрит картинку).

**B. Альтернатива без Swift:** `python3 tv/snap.py` на OpenCV (`pip install opencv-python-headless`),
если у процесса есть доступ к камере (`NSCameraUsageDescription` у хоста).

Плюс дистанционное управление: `tv/tv_remote.py` (websocket `wss://<IP>:8002`, отправка `KEY_*`).

Методика:
1. Включить камеру, сфокусировать её на экран ТВ.
2. Пультом/через `tv_remote.py` пройти сценарий, сохраняя кадры в `backup/live/<шаг>.jpg`.
3. Сверить с приёмочной таблицей; при расхождении смотреть не «кажется», а кадр и лог.
4. Кадры-доказательства — в `backup/photos/` с подписями в `README.md`.

---

## 11. Фаза 9 — документация и передача

Обязательный минимум:
- `README.md` — статус, что сделано, как откатить, ограничения;
- `docs/launcher-spec.md` — поведение лаунчера (инварианты + тесты);
- `docs/final-report.md` — что/как/доказательства и таблица ловушек;
- `docs/settings-before.md` — какие настройки менялись и как вернуть;
- `scripts/restore.sh` — проверенный откат;
- `backup/<ts>/CHANGES.md` и логи выполненных команд — история действий.

---

## Приложение A. Шпаргалка команд

```bash
# связь
./toolchain/sdb.sh connect <IP>:26101
./toolchain/sdb.sh -s <IP>:26101 shell 0 applist
curl -s http://<IP>:8001/api/v2/

# пульт
.venv/bin/python tv/tv_remote.py --name agent key KEY_RIGHT KEY_ENTER --delay 0.6
.venv/bin/python tv/tv_remote.py --name agent key KEY_RETURN
.venv/bin/python tv/tv_remote.py --name agent key KEY_HOME

# сборка/установка лаунчера
cd launcher && ./build.sh && ./scripts/validate.sh
cd .. && ./scripts/install-launcher.sh --launch

# доказательства
open TeleCam.app                      # камера → backup/live/tv-latest.jpg
./scripts/snapshot.sh                 # снимок состояния
cp backup/live/tv-latest.jpg backup/photos/NN-opisanie.jpg
```

## Приложение B. Ловушки Tizen 2.4 (проверено на UE40K6500)

| Ловушка | Как обойти |
|---|---|
| XHR с `file://` заблокирован | конфиг встроить в `config.js` |
| `document.hidden`/`visibilitychange` не работают | использовать `focus`/`blur` |
| `visible` в REST всегда `false` | не использовать для определения foreground |
| `sdb pull` не поддерживается | только `push` + `vd_appinstall` |
| `sdb install` не работает | `push` + `vd_appinstall` |
| package id ≠ 10 символов → `118` | ровно 10 символов |
| SHA-512 подпись отклоняется | патч сигнера на SHA-256 |
| `tizen package -o rel_path` пишет в `tools/ide/bin/tmp` | передавать абсолютный `-o` |
| Клавиша Home не перехватывается | принять штатное поведение Samsung |
| Системные приложения не запускаются | не пытаться, делать своё UI |
| Тяжёлый плеер убивает фоновое приложение | не отдавать память (по умолчанию) или `exit()` + ручной возврат через Smart Hub |
| Диалог dev mode: 4 отдельных октета, нет автоперехода | `KEY_RIGHT` между октетами |
| Долгое удержание `KEY_POWER` → standby | короткие нажатия |

## Приложение C. Тупиковые пути (не повторять)

1. Chromium/WasmGC-эксплойты (CVE-2024-2887 и подобные) — в TV WebKit 538.1 нет `WebAssembly`.
2. Root-методы SamyGO K-root — только для `T-JZ*`/`T-HKMFK*` ≤ 1169.2, не для этого SoC.
3. USB-root Kant-M2 и подобные — 2018+/Tizen 4.0.
4. SDB-инъекции (`;`, `$()`, backtick) — исполнение не происходит.
5. Перехват Home / запуск Smart Hub и системных настроек — невозможно из public-приложения.
6. Подмена «домашнего приложения» через `vconf` — закрыто на retail.

## Приложение D. Факты этого экземпляра (UE40K6500)

- Модель: Samsung UE40K6500, 2016, Tizen **2.4.0**, платформа `16_HAWKM_FHD`, ARMv7, 1920×1080.
- Сеть: ТВ `192.168.0.100` (провод), Mac `192.168.0.10` (Wi-Fi, VPN не должен перехватывать маршрут).
- DUID: `<DUID>`; сертификат: `~/Library/Application Support/Apps2Samsung/Certificate/<CERT_PROFILE> - Public/`.
- Установлены: `AiTVLaunch.AiTV` (AiTV), `AiTVKeyApp.HomeKey` (AiTVHomeKey).
- App id: RUTUBE `6M0RIAD0Nz.Rutube`, Кинопоиск `LuOVXzgX7A.kpTizen`, IVI `FD7JrMU4L1.ivi`,
  Wink `O0tF3EHRuU.itv`, Okko `4uI12bRGkE.OkkoHD`, HDMI — через `tizen.tvwindow`.
- Управление яркостью/подсветкой и прочие глубокие настройки — только штатным меню Samsung.

## Приложение E. Чеклист завершения

- [ ] Бэкап снят и лежит в `backup/<ts>/`; restore проверен.
- [ ] Dev mode включён, SDB работает, REST-паспорт сохранён.
- [ ] Root-возможность проверена и зафиксирована в `docs/root-assessment.md`.
- [ ] Реклама/телеметрия/OTA выключены настройками; изменения записаны в `CHANGES.md`.
- [ ] Лаунчер собран, установлен, запускается; спецификация обновлена.
- [ ] Приёмка T1–T6 пройдена по кадрам камеры; доказательства в `backup/photos/`.
- [ ] README/отчёт/спека актуальны; владелец знает, как откатить и что делать при сбое.
