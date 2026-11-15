# Можно ли применить root-метод из commit-regrets/samsung_tizen_tv_root к UE40K6500?

Краткий ответ: **нет, напрямую метод неприменим**. Ниже — как он устроен, какие «ворота» требует
и что измерено на нашем ТВ.

## Как рутуется ТВ в проекте (Tizen 9, 2024 Neo QLED)

```
страница в браузере ТВ ──CVE-2024-2887 (Chromium 120 + WasmGC)──▶ RCE в рендерере (uid 5001, gid video)
        │
        ▼
/dev/video40: mmap(vm_pgoff = произвольный phys page)  ← баг V4L2 (remap_pfn_range без проверки)
        │
        ▼
чтение/запись всей физической памяти → найти свой task_struct → обнулить cred → uid=0 + CapEff=0x3fffffffff
        │
        ▼
persist: замена IL у stock on-boot .NET-приложения (dotnet-inhouse) → при каждом boot root + TCP 31337
```
Ключевые зависимости: **Chromium 120 с WasmGC** (браузерный RCE), **/dev/video40** (V4L2 physmap),
**/usr/bin/dotnet** и writable /opt + app_onboot (persist), ARM32-ядро 5.4 с конкретными смещениями.

## «Ворота» портирования (docs/PORTABILITY.md проекта) и наш ТВ

| Ворота | Требуется | Наш UE40K6500 (Tizen 2.4, 2016) | Итог |
|---|---|---|---|
| Browser gate | Chromium ~120, WasmGC | **WebKit/538.1** (UA: `SMART-TV; Linux; Tizen 2.4.0 AppleWebKit/538.1 … TV Safari/538.1`), `WebAssembly` отсутствует (`wasm=0`) | ❌ |
| Physmap gate | /dev/video40 (V4L2 codec) | неизвестно; для 2016-платформы публично описан `/dev/ntksys` (другой узел, Tizen 5.5-эра) — код-исполнения для проверки нет | ❌/? |
| Carrier gate | dotnet-inhouse on-boot app на writable /opt | Tizen 2.4 — .NET отсутствует (`/usr/bin/dotnet` появился в 2019+) | ❌ |
| Kernel constants | init_task/cred offsets под ядро 5.4 | ядро 3.x/4.x неизвестной сборки; смещения иные | ❌ |
| SDB foothold (SVE-2025-50109) | `0 appinstall tpk \`cmd\`` на Tizen 5.5–9.0 | наш плагин sdbd 1.0.0: `0 appinstall` = `closed`; инъекции в `0 vd_appinstall <pkg> <path>` проверены (backtick/`$()` → `closed`, `;`/`"` → путь обрезается, команда не исполняется) | ❌ |
| sdb root | `sdb root on` | capability: `rootonoff_support:disabled`, `intershell_support:disabled` | ❌ |

## Что это значит

- **Браузерный RCE из проекта не переносится**: у 2016-х Samsung TV (по данным Samsung/Synacktiv)
  веб-движок — **WebKit**, а не Chromium; WASM/WasmGC нет вообще. Эксплойт CVE-2024-2887
  требует Chromium 120 — на этом ТВ его просто негде запускать.
- **Persist-путь через dotnet тоже недоступен** (нет .NET на Tizen 2.4).
- **SDB-путь закрыт**: шелл whitelist-only, root:on выключен, инъекция через установщик не проходит
  (проверено экспериментально на этом ТВ, см. таблицу).
- Публично известный **SamyGO K-root** рассчитан на прошивки `T-JZ*`/`T-HKMFK*` ≤ 1169.2
  (J/K 2015-2016 семейства с другими платформами). Наш ТВ — `16_HAWKM_FHD` (UE40K6500, Tizen 2.4.0);
  совместимость нужно проверять по точной версии прошивки (Menu → Support → Contact Samsung).
  Даже при совпадении это отдельный проект с риском «кирпича» и потерей dev-режима.

## Вывод

Для текущих задач (Home → AiTV, отключение предустановленных приложений, глушение рекламных
сервисов на уровне процессов) root был бы полезен, но **готового переносимого пути для этой модели нет**.
Реалистичные варианты:
1. оставить текущую конфигурацию (лаунчер + настройки приватности + DNS-блокировка) — работает и проверено;
2. исследовательский путь: искать эксплойт WebKit 538.1 / Tizen 2.4 + physmap-узел (`/dev/ntksys`)
   и собирать ARM-цепочку — это недели работы, риск брика, только с явного согласия владельца;
3. проверить точную прошивку на совместимость с SamyGO K-root (если T-JZ*/T-HKMFK* ≤1169.2 — но это
   маловероятно для UE40K6500).

## Артефакты проверки

- UA/фичи браузера: тестовое web-приложение `AiTVProbe1.Probe` (установлено, запущено, удалено),
  колбэк на `http://192.168.0.10:8765/probe?...` — лог `/tmp/dsh_http.log`:
  `ua=Mozilla/5.0 (SMART-TV; Linux; Tizen 2.4.0) AppleWebKit/538.1 … Safari/538.1&wasm=0&gc=0`
- capability: `secure_protocol:enabled, intershell_support:disabled, rootonoff_support:disabled,
  platform_version:2.4.0, sdbd_plugin_version:1.0.0`
- инъекции: см. журнал экспериментов в этом же документе (backtick/`$()` → `closed`; `;` → путь
  обрезан, исполнения нет).
