# AiTV — Apple TV-style launcher for a 2016 Samsung Tizen TV

A custom Tizen web app launcher for the real **Samsung UE40K6500** (Tizen 2.4, 2016,
1920×1080) in this project: a minimal tvOS-like home screen with a big clock, a
rotating nature wallpaper, a horizontal dock of favourite apps, and a full-screen
"all apps" overlay — all driven by the TV remote. Plus **HomeKey**, a tiny companion
app that makes the TV's Home button open AiTV.

The apps are **built and locally validated but not installed on the TV yet** — this
folder is app development + local preview only. Installing goes through
Apps2Samsung CLI / sdb, see [Packaging & installing](#packaging--installing).

| dock (1080p) | all apps (1080p) | 720p |
|---|---|---|
| ![dock](preview/launcher-main.png) | ![all apps](preview/launcher-allapps.png) | ![720p](preview/launcher-720p.png) |

## What it looks like

* **Clock** — large `HH:MM` (24 h, tabular figures) top-left, weekday + date in
  Russian below it (`суббота, 14 ноября`), refreshed every second.
* **Rotating wallpapers** — 6 license-free nature photos (1920×1080 JPEG q≈82,
  **2.7 MB total**), alternating two stacked layers with a 1.6 s cross-fade every
  **45 s** and a slow **Ken Burns** drift (scale 1.00 → 1.06 over 48 s). The first
  wallpaper is on screen immediately; returning to the launcher also advances it
  when possible.
* **Dock** — 7 favourite apps + an "Все" tile, horizontally centred near the bottom.
  The focused tile scales to **1.15**, gets a soft white ring + glow, its siblings
  dim slightly, and the wallpaper under the UI dims and blurs a little.
* **All apps** — `UP` from the dock (or the "Все" tile) opens a full-screen grid
  (7 columns, 13 apps) over a blurred, darkened backdrop. `BACK` closes it.
* **Hint line** top-right: `◀ ▶ выбрать · OK открыть · ← назад`.
* Everything scales linearly with the viewport: identical layout at 1920×1080 and
  1280×720 (root font-size is 0.8333333vw, all sizes are in `rem`).

## Remote / keyboard controls

| Key | keyCode | Action |
|---|---|---|
| ◀ ▶ | 37 / 39 | move focus in the dock or app grid; **wraps around** horizontally (and vertically in the grid) |
| ▲ | 38 | from the dock: open the *all apps* overlay; in the grid: previous row (wraps) |
| ▼ | 40 | from the dock: harmless no-op; in the grid: next row (wraps) |
| OK / Enter | 13 | launch the focused app; "Все" opens the overlay |
| RETURN (Tizen) | 10009 | in the overlay: close it; in the dock: harmless no-op |
| BACK (alternate) | 461 | same as 10009 |
| ESC | 27 | same as 10009 |
| Backspace | 8 | same as 10009 (also convenient in the browser preview) |

Keys are handled in `document`'s capture phase, `preventDefault()`ed, so Tizen does
not exit the app on Back. The state machine is `mode: "dock" | "grid"` with
`dockIndex` / `gridIndex`; the grid column count is measured from the layout, not
hard-coded, so a different tile size cannot desync navigation.

## Structure

```
launcher/
├── AiTV/                       # the launcher app (package AiTV, app id AiTV.Launcher)
│   ├── config.xml              # Tizen 2.4 web app manifest (privileges, profile, icon)
│   ├── index.html              # markup: wallpaper layers, clock, dock, overlay, toast
│   ├── css/app.css             # the whole UI (tvOS-like, Tizen-2.4-safe CSS)
│   ├── js/app.js               # ES5 runtime: config, dock/grid state machine, launching, wallpapers
│   ├── js/apps.json            # EVERYTHING configurable: wallpapers, dock, app library, app ids
│   ├── icons/
│   │   ├── app/*.png           # 14 locally drawn 256×256 tiles (no trademarked logos)
│   │   ├── icon_117.png        # Smart Hub / package icon (117×117, required by the TV)
│   │   └── icon_512.png        # same artwork, 512×512
│   └── wallpapers/01..06.jpg   # 6 × 1920×1080 JPEG, 2.7 MB total
├── HomeKey/                    # companion "key app" for the Home button (app id AiTV.HomeKey)
│   ├── config.xml
│   ├── index.html              # black page, no UI flash
│   ├── js/main.js              # launch AiTV.Launcher, exit after ~160 ms
│   └── icons/icon_{117,512}.png
├── preview/                    # generated screenshots + icon sheets
├── scripts/
│   ├── make_icons.py           # regenerates every icon (Pillow)
│   ├── fetch_wallpapers.sh     # re-downloads the 6 wallpapers (reproducible provenance)
│   ├── preview.sh              # rebuilds preview/*.png with headless Chrome
│   └── validate.sh             # syntax/config/asset checks + headless remote-key tests
├── build.sh                    # -> dist/AiTV.wgt, dist/HomeKey.wgt
├── dist/                       # built packages: *.wgt (unsigned) + *-signed.wgt
│                               #   (Tizen-CA signed, ready to install on the TV)
└── README.md
```

## Changing the favourites dock

Edit `AiTV/js/apps.json`. It has two arrays:

* **`dock`** — what appears in the bottom dock, left → right (6–8 works best; 7 here).
* **`library`** — everything in the "Все приложения" overlay.

The entries are independent copies (the format below), so to move an app into the
dock: copy its library entry into the `dock` array (or remove it from the dock to
take it off the home screen). An entry looks like:

```json
{
  "id": "netflix",
  "label": "Netflix",
  "appId": "11101200001",
  "altAppId": "3201907018807",
  "kind": "app",
  "icon": "icons/app/netflix.png",
  "color": "#FF2D3C",
  "idStatus": "confirmed"
}
```

* `kind: "app"` — launched with `tizen.application.launch(appId, ok, fail)`.
  `altAppId` is tried if the first id fails (old vs new Samsung ids).
* `kind: "input"` — HDMI source; tries `tizen.tvwindow.show()`, and if the API is
  unavailable it just shows the toast `HDMI-вход`. `input` holds e.g. `"HDMI1"`.
* `kind: "url"` — `tizen.application.launchAppControl()` with
  `http://tizen.org/appcontrol/operation/view` + `"url": "https://…"`; falls back
  to launching `appId` (e.g. the browser).
* `idStatus`: `"confirmed"` (known Samsung id for 2016-class TVs), `"candidate"`
  (plausible, verify on the TV), `"placeholder"` (unknown — the app shows a toast
  instead of launching, so nothing silently fails).
* `icon` is relative to `AiTV/`. `color` is the app accent (also used by the icon
  generator, see below).

If a launch fails on the TV, the launcher shows a toast — it never crashes:
`«Netflix» — приложение не найдено на телевизоре`.

> **Id caveat (read this before installing).** Samsung app ids differ by
> region/firmware/year. Only the ids marked `confirmed` below are backed by public
> community lists for pre-2020 Tizen TVs. **Always** replace them with the ids the
> TV actually reports before trusting the dock:
>
> * `tools_bin/apps2samsung-cli installed --tv 192.168.0.100` — prints every
>   installed app id (Apps2Samsung CLI, already in this workspace), or
> * `sdb shell 0 vd_applist` on a TV whose shell is open (Developer Mode), or
> * Tizen Studio → Device Manager → right click the TV → *Installed Web App List*,
>   and use the `App ID`.
>
> Then paste the ids into `js/apps.json`, keep `"idStatus": "confirmed"`, rebuild
> with `./build.sh` and reinstall.

| App | `appId` in apps.json | Status | Notes |
|---|---|---|---|
| Netflix | `11101200001` (alt `3201907018807`) | confirmed | old pre-2020 id first, new id as `altAppId` |
| YouTube | `111299001912` | confirmed | same id on all Tizen Samsung TVs |
| Prime Video | `3201512006785` (alt `3201910019365`) | confirmed | pre-2020 id first |
| Кинопоиск | `111399000037` | confirmed | Russian community list, old id |
| Spotify | `3201606009684` | candidate | 2016-era id |
| YouTube Kids | `3201611010983` | confirmed | 2016-era id |
| SmartThings | `3201710015016` (alt `3201910019378`) | candidate | 2017 id, may not be on this 2016 set |
| Браузер | `org.tizen.browser` (alt `3201907018784`) | candidate | Tizen app id first |
| Twitch | `3202203026841` | candidate | 2022 id — almost certainly **not** on a 2016 TV; expected to toast |
| IVI / Wink / Okko | — | placeholder | ids not found in public lists; the tile shows a toast until you fill them in |
| HDMI | — (`kind: "input"`) | — | uses `tizen.tvwindow`, not an app id |

Sources for the community ids: [samsung-tv-ws-api APPLICATIONSmd](https://github.com/epenet/samsung-tv-ws-api/blob/master/APPLICATIONS.md),
[tavicu homebridge-samsung-tizen app list](https://tavicu.github.io/homebridge-samsung-tizen/extra/applications.html),
[homebridge-samsung-tizen-applications](https://github.com/blog-razrabotchika/homebridge-samsung-tizen-applications).
They are community data, not a Samsung contract: verify on the actual TV.

## Replacing the wallpapers

1. Put 1920×1080 JPEGs into `AiTV/wallpapers/` (keep them ≈2.7 MB total; the
   package budget is: wallpapers **≤ 12 MB**).
2. List them in `js/apps.json` → `wallpapers` (`{"src": "wallpapers/07.jpg", …}`),
   in the order you want them shown. `settings.wallpaperIntervalSec` controls the
   cross-fade interval (default 45 s, minimum useful value ~15 s).
3. Optional: `./scripts/fetch_wallpapers.sh --force` re-downloads the originals at
   q=82; `scripts/validate.sh` re-checks sizes/dimensions and the 12 MB budget.

Wallpaper credits (both in `apps.json` and here) — all **Unsplash License**
(free to use, attribution appreciated; https://unsplash.com/license):

| file | photo | source URL |
|---|---|---|
| 01.jpg | Sunrise above the clouds | https://images.unsplash.com/photo-1506905925346-21bda4d32df4 |
| 02.jpg | Alpine lake and boathouse | https://images.unsplash.com/photo-1470770841072-f978cf4d019e |
| 03.jpg | Milky Way over snowy peaks | https://images.unsplash.com/photo-1519681393784-d120267933ba |
| 04.jpg | Sunlight in a pine forest | https://images.unsplash.com/photo-1441974231531-c6227db76b6e |
| 05.jpg | Turquoise mountain lake | https://images.unsplash.com/photo-1501785888041-af3ef285b470 |
| 06.jpg | Highland valley at sunset | https://images.unsplash.com/photo-1470071459604-3b5ec3a7fe05 |

If a download ever fails, the launcher keeps working: with no wallpapers it falls
back to a tasteful CSS gradient (`body.no-wallpaper`) instead of a black screen —
but the shipped bundle is complete, nothing is missing.

## Icons

No trademarked artwork ships with the app. Every tile is drawn programmatically by
`scripts/make_icons.py` (Pillow): a dark tinted tile (22.5 % corner radius), a soft
accent glow, a bold Avenir Next / Helvetica Neue monogram or a geometric glyph
(play triangle, equalizer bars, node graph, target rings, "▣" for HDMI, 3×3 grid for
"Все"), plus a drop shadow. Output is 256×256 PNG, supersampled 4× for clean edges.

Regenerate: `python3 scripts/make_icons.py` (also refreshes
`preview/icons-sheet.png` and the `icon_117/512` package icons). Adding an app means
adding a `dict(...)` to `TILES` (letter, colour pair, fit ratios) or a new glyph
function, then re-running the script.

## Tizen 2.4 notes (2016 TV)

The TV's web engine is Chromium-47-class, so the code is deliberately conservative:

* **ES5 only**: `var`, function declarations, no `let/const`, no arrow functions,
  no template literals, no `Promise`/`fetch`, no `class`. Modules are loaded with
  plain `<script>`, config with `XMLHttpRequest` on `js/apps.json` (plus an embedded
  mirror in `app.js` in case a `file://` preview blocks local XHR).
* **CSS**: flexbox + margins (no CSS Grid, Chrome 57+; no `var()`, Chrome 49+; no
  flex `gap`, Chrome 84+). Everything is sized in `rem` from a single
  `font-size: 0.8333333vw` rule, so 720p is a pure scale of 1080p.
* **Optional effects are feature-detected**: `@supports` gates `backdrop-filter`
  (dim/blur on focus and overlay) — on Tizen 2.4 it simply degrades to a plain dim.
  Modern Chromium (the browser preview) gets the blur.
* **`tizen.application.launch(appId, onsuccess, onerror)`** is wrapped in
  `try/catch`; a missing app id or a not-installed app becomes a toast, never an
  exception. `altAppId` is retried once.
* **HDMI**: `tizen.tvwindow.show()` is optional hardware API — called inside
  `try/catch`; when unavailable the tile shows the toast `HDMI-вход`. Its exact
  callback signature differs between Tizen/Samsung versions, which is why the call
  is defensive. (Unverified on the real TV, see TODO.)
* **Privileges** declared in `config.xml`: `http://tizen.org/privilege/application.launch`
  and (for the HDMI path) `http://tizen.org/privilege/tv.window`; profile
  `tv-samsung`; `required_version="2.4"`.
* **Background suspension**: Tizen suspends background web apps, so
  `visibilitychange`/`focus` do not always fire when returning from Netflix. The
  wallpaper therefore also rotates on its own timer; "rotate on app-return" is
  best-effort by design (the launcher re-entry goes through HomeKey).
* `config.xml` uses `widget@id` = `tizen:application@id` = `AiTV.Launcher` /
  `AiTV.HomeKey` (both contain a dot and start with a letter). HomeKey keeps a
  separate package id (`HomeKey`) so the two `.wgt` files don't replace each other —
  its app id still lives in the `AiTV.*` namespace because the TV's Home-button
  vconf value points at it.

## Local preview

```bash
cd launcher
python3 -m http.server 8765 --bind 127.0.0.1 --directory AiTV
# then open http://127.0.0.1:8765/index.html in a browser, or:

./scripts/preview.sh   # serves AiTV and regenerates the screenshots in preview/
```

Headless screenshot (the command the design was iterated with):

```bash
"/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" \
  --headless=new --disable-gpu --hide-scrollbars \
  --window-size=1920,1080 --virtual-time-budget=6000 \
  --screenshot=preview/launcher-main.png \
  "http://127.0.0.1:8765/index.html?instant=1"
```

The browser shows real navigation (arrow keys / Enter / Esc) and toasts
"Предпросмотр в браузере: «Netflix» откроется на телевизоре" instead of launching.

**QA hook** (only active with a query string, the installed app never has one):
`?instant=1` pins CSS transitions at their end state — required for deterministic
headless screenshots, because Chromium's virtual-time clock can freeze a transition
at opacity 0 and produce an almost-black capture; `&allapps=1` opens the overlay;
`&focus=N` focuses a dock tile; `&toast=text` shows a toast; `&keys=39,39,13`
replays remote keyCodes and publishes the resulting state into `document.title`.
`scripts/validate.sh` uses these for the navigation smoke test.

## Validation

```bash
./scripts/validate.sh    # node --check, JSON/XML checks, wallpaper budget,
                         # headless remote-key state machine at 1080p and 720p
```

Current result: **all checks passed** — JS syntax, valid `apps.json`, well-formed
`config.xml` with the expected app id/version/content/icon/profile, 6 wallpapers
(2.71 MB, all 1920×1080 JPEG), and 19 remote-control cases (dock wrap-around,
overlay open/close via 10009/461/27, row movement, vertical wrap, 7 columns detected
at both resolutions, browser-preview toast).

## Packaging & installing

```bash
cd launcher
./build.sh
# -> dist/AiTV.wgt    (3.2 MB, 32 files, config.xml at root, unsigned)
# -> dist/HomeKey.wgt (80 KB, unsigned)
```

A `.wgt` is a plain zip with `config.xml` at the root. `build.sh` output is
**unsigned** on purpose (signing needs this machine's certificates), and it strips
stale `author-signature.xml` / `signature1.xml` / `.manifest.tmp` so a package can
never carry a broken old signature.

This workspace's toolchain is ready for the 2016 TV (see `toolchain/README.md`):
Samsung `sdb` 4.2.36 (via Rosetta), Tizen Studio CLI 2.5.25 and the self-contained
**Apps2Samsung CLI 3.3.0**, with **Tizen-CA certificates already created offline**
— a 2016 Tizen TV accepts Tizen-CA signatures, so **no Samsung account is needed**.
(The current blocker is the TV side: Developer Mode is still OFF, port 26101 closed.)

**Path A — Apps2Samsung CLI (this is the documented route for this project):**

```bash
cd <PROJECT_ROOT>
A2S=./tools_bin/apps2samsung-cli
TV=192.168.0.100
HOST=192.168.0.10            # this Mac's en0 address; ALWAYS pass it, the VPN
                            # makes the CLI auto-detect 172.16.9.1 instead

# 0) TV: Apps > press 1 2 3 4 5 > Developer Mode = On, Host PC IP = 192.168.0.10,
#    then fully restart the TV (dev mode only activates after the restart).
$A2S tv $TV --local-ip $HOST --json     # expect ready:true, debugPortOpen:true

# 1) sign both packages with the Tizen-CA certificate (offline, no account)
$A2S sign launcher/dist/AiTV.wgt    -o launcher/dist/AiTV-signed.wgt    --tizen-cert --json
$A2S sign launcher/dist/HomeKey.wgt -o launcher/dist/HomeKey-signed.wgt --tizen-cert --json

# 2) install on the TV
$A2S install launcher/dist/AiTV-signed.wgt     --tv $TV --local-ip $HOST --tizen-cert --keep --launch --json
$A2S install launcher/dist/HomeKey-signed.wgt \
    --tv $TV --local-ip $HOST --tizen-cert --keep --json

# 3) sanity check: ids as the TV sees them, then launch the launcher by id
$A2S installed --tv $TV --local-ip $HOST
$A2S launch AiTV.Launcher --tv $TV --local-ip $HOST
```

If the TV refuses an app id (`[118, -22]`), `install … --new-id` installs under a
fresh package id (remembered per TV). `install` can also sign on the fly, but the
explicit `sign` step keeps signed artefacts reproducible.

**Path B — Tizen Studio CLI (verified offline):**

```bash
cd <PROJECT_ROOT>
# packages AND signs in one step with the tizen-sdk profile (Tizen-CA author cert)
./toolchain/tizen.sh package -t wgt -s tizen-sdk -- launcher/AiTV -o /tmp/wgt-out
./toolchain/tizen.sh package -t wgt -s tizen-sdk -- launcher/HomeKey -o /tmp/wgt-out
./toolchain/tizen.sh install -s 192.168.0.100:26101 -n AiTV.wgt -- /tmp/wgt-out
```

Note: `tizen package` writes `author-signature.xml` / `.manifest.tmp` **into the
project directory**; `build.sh` excludes those, and `git status`-style cleanliness
means you may want to delete them afterwards.

**Path C — bare sdb (fallback, retail firmware often blocks the shell):**

```bash
./toolchain/sdb.sh push launcher/dist/AiTV-signed.wgt /home/owner/share/tmp/sdk_tools/AiTV.wgt
./toolchain/sdb.sh shell 0 vd_appinstall AiTV /home/owner/share/tmp/sdk_tools/AiTV.wgt
```

Verified today without the TV: both `apps2samsung-cli sign … --tizen-cert` calls
succeeded and reported `appId: AiTV.Launcher / packageId: AiTV` and
`appId: AiTV.HomeKey / packageId: HomeKey`, and
`./toolchain/tizen.sh package -t wgt` accepted both `config.xml` files (the official
Tizen CLI parses and signs them). `toolchain/tv-ready.sh` wraps the TV readiness
checks once Developer Mode is on.

### If install complains about the app id

`AiTV.Launcher` / `AiTV.HomeKey` follow the "contains a dot, starts with a letter"
rule, and both the Apps2Samsung signer and the Tizen CLI parsed them fine. Some
Tizen builds are stricter (a 10-character package id in the app id). If the TV
rejects the id, either use `apps2samsung-cli install … --new-id`, or rename to the
10-character style and rebuild:

* `AiTV/config.xml` → package `AiTVLaunch`, id `AiTVLaunch.Launcher`
* `HomeKey/config.xml` → package `HomeKey`, id `AiTVLaunch.HomeKey`
* `HomeKey/js/main.js` → `LAUNCHER_APP_ID = "AiTVLaunch.Launcher"`
* and point the Home-button vconf value at `AiTVLaunch.HomeKey`.

### Wiring the Home button (what HomeKey is for)

Tizen's Home button opens whatever app is named in the vconf key
`db/appfw/home_appid`. Pointing it straight at a launcher is known to be unreliable
on Tizen TVs: the TV relaunches home apps with `__NO_RAISE_WINDOW`, so a paused
launcher stays hidden behind the loading screen. The working pattern (as in the
smakosh write-up this project follows) is:

* `db/appfw/home_appid` → **`AiTV.HomeKey`** — a tiny app that starts, calls
  `tizen.application.launch("AiTV.Launcher")` and exits after ~160 ms, so the
  launcher is raised by an ordinary app launch.
* `db/appfw/startup_appid` → **`AiTV.Launcher`** — direct on power-on, so a broken
  key app can never leave the TV on a black screen.

Setting those keys needs `vconftool` (toolchain agent's job — see the root
project's install/vconf scripts). HomeKey is intentionally dumb: no UI, black page,
plain ES5, feature-detected Tizen API, and it exits even if the launch fails.

## TODO / known limits

* **App ids** — IVI / Wink / Okko are placeholders; Spotify/SmartThings/Twitch/
  Browser are candidates. Fill from the real TV (`installed --tv …`), see the caveat
  above. Nothing crashes meanwhile, the tile just toasts.
* **HDMI tile** — `tizen.tvwindow.show()` behaviour on the 2016 set is unverified
  (needs the TV). It is fully guarded, so worst case is the toast.
* **Wallpaper on app return** — best-effort only, Tizen suspends background apps.
* **Twitch / SmartThings** may simply not exist on a 2016 TV — expected toast.
* No screensaver / ambient mode yet; the launcher is meant to be replaced by
  Netflix/YouTube most of the time.
