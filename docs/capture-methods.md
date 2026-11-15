# Capturing the screen of a Samsung UE40K6500 (2016, Tizen 2.4, retail) — options, evidence, confidence

Target: `192.168.0.100`, model `UE40K6500`, platform `16_HAWKM_FHD`, Tizen 2.4 class
(`msfVersion 2.1.0`, `/api/v2/` says `OS: Tizen`, `firmwareVersion: Unknown`), retail firmware, no root.
Host Mac `192.168.0.10` (`en0`, macOS 26.5.1).

Research date 2026-11-14. Three TV states were observed live: (1) Developer Mode **off**, sdb `26101`
closed — REST/websocket probes 19:43–19:48 (§0.2–0.6); (2) TV briefly off, `Host is down`, 19:52–19:54;
(3) Developer Mode **ON** (`developerMode:1`, `developerIP:192.168.0.10`), sdb connected, `26101` open —
the definitive daemon probe 19:55–19:58 (§0.9). Nothing here changes the TV; the probes are read-only
except one push of a 6-byte temp file to `/tmp` (§0.9).

Confidence tags: **[verified-live]** = probed against this TV in this session; **[verified-local]** =
read out of the binaries/docs in this repo; **[documented]** = public docs/forums with URL;
**[medium]/[low]** = inference/uncertain; **[impossible]** = excluded by protocol/hardware, with the
reason stated.

---

## TL;DR — the ranked answer

**There is no known programmatic way to capture the TV's own screen (UI, Smart Hub, dialogs, video)
from a retail 2016 Tizen TV over sdb, the LAN websocket, the REST API, MultiScreen/Smart View, DLNA,
Miracast, or the Tizen Studio tools.** The only two routes to real screen pixels are (a) a camera
pointed at the panel — fully scriptable with a cheap USB webcam or an old Android phone — and (b) root,
which on this generation means the SamyGO K-root and only if the firmware is ≤ `1169.2`; the
`chris-ritsen/samsung-tv-root` route cannot work on Tizen 2.x at all.

What *is* programmatic (verified on this TV today) is **state**, not pixels: the 8002 websocket can list
installed apps (`ed.installedApp.get`) and send remote keys, the 8001 REST API reports
`/api/v2/applications/<id>` (`running`/`visible`) and `/ms/1.0/` capabilities, and DIAL
`/ws/apps/<name>` reports app state. That is enough to verify "app installed / launched / still running"
without a human. The human phone photo is needed only for things that only exist as pixels (Home
button behaviour, Smart Hub, dialogs, boot state).

On 2026-11-14 with Developer Mode ON we probed the TV daemon directly (§0.9): every screenshot-style verb
(`0 vd_appshot`, `0 screenshot`, `0 capture`, `0 vd_appcapture`, `0 appshot`) returns `closed`;
`0 vd_applist` / `0 vd_appinstall` / `0 vd_appuninstall` are also `closed` on this build, while the
working daemon verbs are `0 applist` (45-app table), `0 was_execute` (launch app) and `0 getduid`.
`sdb shell` itself is `closed`, `sdb dlog` is `closed`, and filesync is **push-only**
(`filesync_support:push`): `sdb pull` fails with "NO support file pull" — so even a hypothetical
on-device screenshot file could not be retrieved over sdb.

| # | Option | What it can capture | Status | Confidence |
|---|---|---|---|---|
| 1 | USB webcam / old phone as IP camera aimed at the panel | **whole TV screen** (UI + video) | **WORKS** (one-time rig) | high |
| 2 | Human phone photo | whole TV screen | **WORKS** | high |
| 3 | State assertions: `/api/v2/applications/<id>`, websocket app list, `0 applist`, `0 was_execute`, `0 getduid`, DIAL state | not pixels; proves app install/launch/state | **WORKS — several verified live 2026-11-14** | high |
| 4 | Our launcher's own telemetry (heartbeat/DOM/canvas → HTTP to the Mac) | our web app's UI/content only | **WORKS** (needs app code) | high |
| 5 | Tizen Studio 1.3 + TV Extension 3.1.2 → Debug As → Web Inspector → **Rendering Debug → capture screen** | our web app's page only | **DOCUMENTED (own app page only)** — depends on Debug As/`0 debug` working on this build; verify (§3.1/§3.2) | medium-high |
| 6 | `sdb shell 0 debug <app>` → forward port → CDP `Page.captureScreenshot` (Chrome 38-era protocol) | our web app's page only | **MAYBE — probe after installing a debug build** (`0 debug` not yet confirmed on this build, §3.2) | medium |
| 7 | SamyGO K-root + `scrot` / `screenshot.sh` | whole screen, incl. video | **MAYBE — root only, fw ≤ 1169.2**, risky | medium mechanism / low applicability |
| 8 | `0 vd_appshot`, `0 screenshot`, `0 capture`, `0 vd_appcapture`, `0 appshot` | TV screen | **IMPOSSIBLE — every one returns `closed` (probed live, §0.9)** | high |
| 9 | `sdb shell` + `xwd` / `/dev/fb0` / `screencap`; `sdb pull` of any file | TV screen | **IMPOSSIBLE** — `sdb shell` is `closed`, `sdb pull` is unsupported (`filesync_support:push`), no such tools | high |
| 10 | 8002 websocket / 8001 REST "screenshot" method | TV screen | **IMPOSSIBLE — no such method/route** (enumerated) | high |
| 11 | MultiScreen (`/ms/1.0/`, ports 8001/7676/7678) / Samsung Smart View | TV→PC screen stream | **IMPOSSIBLE for us** (mobile→TV only; closed/DRM path; 2016 TV→phone live-stream was removed from the app) | high |
| 12 | DLNA / UPnP "screenshot" | TV screen | **IMPOSSIBLE — no such action** (AllShare = DMS/DMR content only) | high |
| 13 | Miracast / WiDi with the TV as the **source** | TV screen | **IMPOSSIBLE — TV is a sink only** | high |
| 14 | HDMI capture dongle | TV screen | **IMPOSSIBLE — the TV has no HDMI output** (inputs + ARC audio out only); it can only capture an HDMI source *before* the TV, not Samsung UI | high |
| 15 | Service menu "screen capture" | TV screen | **NOT FOUND / no evidence**; service menu has test patterns and option tables only | medium |
| 16 | SmartThings / Remote Access / cloud | TV screen | **IMPOSSIBLE — no screenshot API** (Remote Access is 2019+ anyway) | high |

**Single best recommendation:** build a camera rig (USB webcam or old Android phone with the "IP Webcam"
app) pointed at the panel, and pair it with a `verify.sh` that snapshots (a) TV REST/websocket/DIAL state
and (b) a camera frame after every step. Keep human phone photos for milestones only. Do **not** promise
screenshot automation of Samsung UI; do promise automated state verification + a camera frame per step.

---

## 0. Live evidence collected on this TV (2026-11-14)

### 0.1 Ports on 192.168.0.100 while the TV was on

```
8001 OPEN   REST API + MultiScreen (/api/v2/, /ms/1.0/, /ws/apps/)
8002 OPEN   secure websocket, samsung.remote.control channel (wss)
7676 OPEN   Samsung AllShare UPnP server (DMS)
7678 OPEN   Samsung AllShare UPnP server (DMS)
8080 OPEN   "WebServer" (404 on /)
9197 OPEN   DLNA DMR (from research/README.md, same session)
55000 CLOSED, 26101 CLOSED (sdb — Developer Mode is off), 26102 CLOSED
```

### 0.2 The 8002 websocket works on this 2016 set **without a token**

```
wss://192.168.0.100:8002/api/v2/channels/samsung.remote.control?name=<base64("dsh-probe")>
<- {"event":"ms.channel.connect","data":{"id":"…","clients":[{"attributes":{"name":"ZHNoLWFnZW50"},…}]}}
```

No `token` is returned and none is required (2016 behaviour; if the TV shows "Allow connection", accept
once — the existing `tv/tv_remote.py` in this repo already pairs/uses this channel).

### 0.3 App list over the websocket — **works, verified**

Request `{"method":"ms.channel.emit","params":{"event":"ed.installedApp.get","to":"host"}}`, response:

```json
{"event":"ed.installedApp.get","data":{"data":[
 {"appId":"111299001912","app_type":2,"name":"YouTube","icon":"/opt/down/webappservice/apps_icon/FirstScreen/111299001912/250x250.png"},
 {"appId":"111199000746","app_type":2,"name":"Иви", …},
 … ]}}
```

36 apps returned on this TV (Netflix, YouTube, Prime Video, Spotify, Media Station X, Web Browser, …).
This is the only way found to enumerate apps **without** sdb/Developer Mode; it gives `appId`, `name`,
`app_type`, `icon` (numeric `appId` is what `/api/v2/applications/<id>` expects).

### 0.4 Capture-method enumeration on 8002 — every capture-ish method is rejected

```
{"method":"ms.remote.control"}           -> recognized (needs Cmd/DataOfCmd/TypeOfRemote params)
{"method":"ms.channel.emit"}             -> recognized (ed.installedApp.get / ed.apps.launch / IME events)
{"method":"ms.channel.list"}             -> ms.error "unrecognized method value : ms.channel.list"
{"method":"ms.remote.screenshot"}        -> ms.error "unrecognized method value : ms.remote.screenshot"
{"method":"ms.remote.capture"}           -> unrecognized
{"method":"ms.remote.screen"}            -> unrecognized
{"method":"ms.channel.screenshot"}       -> unrecognized
{"method":"ms.channel.capture"}          -> unrecognized
{"method":"ms.channel.getScreen"}        -> unrecognized
{"method":"ms.remote.getScreenShot"}     -> unrecognized
{"method":"ms.remote.control.getScreenshot"} -> unrecognized
{"method":"ms.remote.appservice"/"ms.remote.art"/"ms.remote.browser"/"ms.remote.tv"/"ms.remote.voice"/"ms.remote.gamepad"/"ms.remote.file"/"ms.remote.system"} -> unrecognized
```

### 0.5 8001 REST API — state yes, screenshots no

```
GET /api/v2/                             200  device info (model, developerMode, …)
GET /api/v2/applications/111299001912    200  {"name":"YouTube","running":false,"version":"2.1.490","visible":false,"id":"111299001912"}
GET /api/v2/applications/3201801015538   200  {"name":"Media Station X", …}      (numeric appId works)
GET /api/v2/applications/org.tizen.browser 404                                   (non-numeric id doesn't)
GET /api/v2/applications                 404
GET /api/v2/screenshot                   404
GET /api/v2/screen /capture /picture /screencapture  404
GET /ms/1.0/                             200  MultiScreen capabilities JSON (DUID, model, "samsung:multiscreen:1")
GET /ws/apps/YouTube                     200  DIAL: <state>stopped</state>, allowStop=true, version 2.1.490
GET /ws/apps/                            200  DIAL device descriptor XML (same as nservice.xml)
```

### 0.6 7676/7678/8080 are not capture services

```
GET http://192.168.0.100:7676/  -> 400 SOAP UPnPError 402, SERVER: UPnP/1.1 Samsung AllShare Server/1.0
GET http://192.168.0.100:7678/  -> 400 SOAP UPnPError 402, same server
GET http://192.168.0.100:8080/  -> 404 "WebServer" (Samsung mini web server, /api/v2/ style REST front)
```

### 0.7 How to reproduce the live evidence (when the TV is back on)

```sh
# websocket: connect (no token on this set), handshake, app list, then a method probe
.venv/bin/python - <<'PY'
import base64, json, ssl, websocket
ws = websocket.create_connection(
    "wss://192.168.0.100:8002/api/v2/channels/samsung.remote.control?name="
    + base64.b64encode(b"dsh-probe").decode(),
    timeout=8, sslopt={"cert_reqs": ssl.CERT_NONE, "check_hostname": False})
ws.settimeout(4)
while True:                                   # skip clientConnect noise until channel ready
    if json.loads(ws.recv()).get("event") == "ms.channel.connect":
        break
ws.send(json.dumps({"method": "ms.channel.emit",
                    "params": {"event": "ed.installedApp.get", "to": "host"}}))
while True:
    m = json.loads(ws.recv())
    if m.get("event") == "ed.installedApp.get":
        print(json.dumps(m["data"]["data"][:3], ensure_ascii=False, indent=1)); break
ws.send(json.dumps({"method": "ms.remote.screenshot", "params": {}}))
print(ws.recv())                       # expect: {"event":"ms.error","data":{"message":"unrecognized method value : ms.remote.screenshot"}}
ws.close()
PY

# REST state + 404 capture probes
curl -s http://192.168.0.100:8001/api/v2/ | head -c 400
curl -s http://192.168.0.100:8001/api/v2/applications/111299001912
curl -s -o /dev/null -w '%{http_code}\n' http://192.168.0.100:8001/api/v2/screenshot   # 404
```

### 0.8 Local toolchain: nothing can take a screenshot

* `sdb 4.2.36` and `sdb 2.3.8`: `sdb help` has **no** screenshot verb; strings inside the binaries contain
  no `screenshot`/`screencap`/`vd_appshot`/`capture` TV commands **[verified-local]**.
* Tizen Studio CLI 2.5.25 `toolchain/tizen-studio/tools/tizen-core/tz` (Go binary) contains the *entire*
  TV `0 …` command set it knows, and it is exactly:
  `shell 0 vd_appinstall %s %s`, `shell 0 vd_appuninstall %s` / `%s.%s`, `shell 0 vd_applist`,
  `shell 0 debug %s.%s`, `shell 0 execute %s`, `shell 0 appinstall %s %s` (plus
  `shell /usr/bin/app_launcher --start|--kill %s`). Grep for `screenshot`, `screencap`, `screen capture`,
  `appshot`: **0 matches** in each case **[verified-local]**.
* Tizen CLI command list (`toolchain/tizen.sh --help`) is
  `build-* certificate clean cli-config create gen-coverage install install-permit list manual package
  package-cs run security-profiles trust-anchor uninstall version` — there is **no `tizen device list`**
  verb; device listing is `sdb devices` (or Tizen Studio's Connection Explorer GUI) **[verified-local]**.

---

### 0.9 DEFINITIVE daemon probe — Developer Mode ON, 2026-11-14 19:55–19:58

TV on, `developerMode:1`, `developerIP:192.168.0.10`, `sdb devices` → `192.168.0.100:26101  device  UE40K6500`.
(`backup/probe-20261114-194814/` and `backup/20261114-194852/` hold the same generation of probe output.)

```
$ sdb -s 192.168.0.100:26101 capability
secure_protocol:enabled   intershell_support:disabled   filesync_support:push      usbproto_support:enabled
sockproto_support:enabled rootonoff_support:disabled    zone_support:disabled      multiuser_support:disabled
cpu_arch:armv7            profile_name:tv               vendor_name:Samsung
can_launch:tv-samsung-public_-_tv-samsung-partner
platform_version:2.4.0    product_version:2.0           sdbd_version:2.2.31        sdbd_plugin_version:1.0.0

$ sdb -s … shell            -> closed          $ sdb -s … shell 0                -> closed
$ sdb -s … shell 0 help     -> closed          $ sdb -s … shell 0 version        -> closed
$ sdb -s … shell 0 vd_applist / 0 vd_appinfo / 0 appinfo <id>                     -> closed
$ sdb -s … shell 0 vd_appinstall … / 0 vd_appuninstall … / 0 appinstall …         -> closed
$ sdb -s … shell 0 appshot / 0 vd_appshot [path] / 0 screenshot [path] / 0 capture / 0 vd_appcapture -> closed
$ sdb -s … shell 0 was_execute 9999.Nonexistent
      launch app 9999.Nonexistent
      app_id[] launch failed[400]
      launch app failed
      spend time for wascmd is [64]ms
$ sdb -s … shell 0 getduid  -> <DUID>
$ sdb -s … shell 0 debug 9999.Nonexistent -> closed
$ sdb -s … push /tmp/dsh-probe.txt /tmp/dsh-probe.txt  -> pushed, 1 file(s) pushed (6 bytes)
$ sdb -s … pull /tmp/dsh-probe.txt /tmp/…              -> error: failed to read '…': NO support file pull
$ sdb -s … dlog                                        -> closed
```

Also: `sdb shell 0 applist` **works** and prints a 45-row app table (see §5.1); `sdb shell` and every
lower-case POSIX command (`id`, `ls /`) return `closed`. `sdb shell 0 was_execute` is the only launcher
verb that responds on this build; `0 debug` is closed with a bogus id (unresolved for a real debug app id).

Interpretation: the Tizen 2.4 retail daemon whitelists the old app-list/execute/getduid family and
refuses the `vd_*` generation outright. The legacy `0 appinstall` was refused with every argument form
tried, but a real signed `.wgt` was *not* tested — treat that as "verify before relying on it, prefer
`sdb install`/Tizen CLI". Combined with push-only filesync and closed shell/log, **there is no sdb-based
path to screen pixels on this TV**, and no file-retrieval path that could carry a screenshot off the
device.

---

## 1. SDB / Tizen debug paths — no screenshot command exists

### 1.1 What the `0 …` command set really is

`sdb shell 0 <verb>` is Samsung's privileged TV-daemon command channel, not a POSIX shell. It is
handled by the TV's sdb daemon; the host `sdb` just forwards the request and the daemon builds a real
command (a 2014-era reverse-engineering note shows `sdb shell 0 debug <appId>` becoming
`/usr/bin/app_launcher --start <appId> --web-debug` on the TV side —
<https://gist.github.com/laat/2b7107298593dca650062b7678279386> comments).

Every public, official or community source uses the same small verb family:

| Verb | Meaning | Source |
|---|---|---|
| `0 vd_applist` | dump installed apps (≈45 fields: `app_id`, `app_title`, `app_version`, `app_installed_path`, `installState`, `is_removable`, …) | Samsung TV forum/SamyGO, Tizen Studio CLI strings, agent-device |
| `0 applist` | older list verb, same idea | pre-2017 Tizen Studio `SecureCmdVer2_0`; forum reports |
| `0 vd_appinstall <pkg> <path>` / `0 appinstall <pkg> <path>` | install a pushed `.wgt` | Samsung Wits (official), Tizen Studio CLI strings, laat gist |
| `0 vd_appuninstall <id>` | uninstall | same |
| `0 debug <appId>` | launch with web debug; prints `successfully launched pid = N with debug 1 port: P` | Samsung Wits, laat gist, StackOverflow |
| `0 execute <appId>` | execute/launch app (frequently `closed` on retail) | Tizen Studio CLI strings; SO 71994887 |
| `0 was_execute <appId>` | launch app | Samsung Wits (official) |
| `0 was_kill <appId>` | kill app | agent-device plugin |

* Samsung's own open-source TV tool **(Samsung/Wits)** uses exactly `0 vd_appinstall`, `0 vd_appuninstall`,
  `0 was_execute`, `0 debug` — <https://github.com/Samsung/Wits>,
  <https://raw.githubusercontent.com/Samsung/Wits/c18cf03eced66aa66c3603c94fccf4c14d193f00/lib/appLaunchHelper.js>
  **[documented]**.
* On **this** TV the whitelist is the older, smaller subset: `0 applist`, `0 was_execute`, `0 getduid`
  work; every `vd_*` verb and every `*install*` verb is `closed` (§0.9). The tables above describe the
  family across generations; expect only the old subset on Tizen 2.4 retail.
* agent-device's Tizen plugin states it plainly: **"The restricted `sdb shell 0` has no screen-capture
  command."** — <https://github.com/callstack/agent-device/blob/d2426fffdf7829f58458ec1631bd117e6cd8cf94/packages/provider-tizen/README.md>
  **[documented]**.

### 1.2 `0 vd_appshot` / `0 screenshot` / `0 capture` — no evidence anywhere

* No reference in Samsung Wits, Tizen Studio CLI (2.5.25 strings), SamyGO Tizen threads, agent-device,
  appium drivers, or the Samsung/Tizen developer docs searched.
* GitHub issues search for `"vd_appshot"`: **0 results**
  (<https://api.github.com/search/issues?q=%22vd_appshot%22>); web searches for the literal string return
  nothing TV-related **[documented/negative]**.
* The modern Tizen Studio/Web Inspector workflow for "screenshot" of a TV app is explicitly a *page*
  capture in the Web Inspector "Rendering Debug" tab, and "it is not possible" to screenshot other apps —
  Samsung developer forum thread "Tizen TV app - taking screenshot" (Jan 2017), archived:
  <https://d2h8mbl10wxvsa.cloudfront.net/forums/web-application-development/tizen-tv-app-taking-screenshot>
  (mirrored, AI-generated summary: <https://samsungtizenos.com/knowledge-hub/tizen-tv-app-screenshot-tizen-studio-8141>)
  **[documented]**. Caveat: the archived forum URL could not be re-fetched from this network; the quote
  above comes from the search index and the matching AI mirror.
* **Live result on this TV (2026-11-14 19:55, Developer Mode ON):** `0 vd_appshot`, `0 vd_appshot /tmp/shot.png`,
  `0 screenshot`, `0 screenshot /tmp/x.png`, `0 capture`, `0 vd_appcapture`, `0 appshot`, `0 appshot /tmp/y.png`
  **all return `closed`**; raw transcript in §0.9. On this build `closed` is the daemon's generic refusal
  (the same TV returns it for plain `sdb shell`, `0 help`, `0 vd_applist`, `0 appinfo`, …), while
  `0 was_execute <id>` is accepted and returns an app-level error — so the capture verbs are genuinely
  not implemented/whitelisted here, not merely mis-called.

**Conclusion:** `0 vd_appshot` does not exist on this firmware. Confidence: high (live-probed with and
without path arguments, plus no public reference anywhere).

### 1.3 The classic Tizen screenshot recipes do not apply

* `sdb shell` + `xwd -root -out /tmp/screen.xwd` + `sdb pull` is the **Tizen 2.2/2.3 mobile/wearable**
  recipe, assuming an X server and a working sdb shell —
  <https://wiki.tizen.org/Capture_Screenshot_in_Tizen> **[documented]**. It is not a TV recipe.
* `screencap -p` is an **Android** command; pages that mention it for Tizen TV are AI-generated errors
  (e.g. the "Tizen Studio 2.0 screenshots" knowledge-hub article) — do not try it.
* On retail 2016 TVs `sdb shell` is filtered: a 2016 `UE49KU6400` in Tizen Studio 2.0 logs
  `E/sdb: sdb rejected shell command (pkgcmd -l | grep …): closed`
  (<https://samsungtizenos.com/knowledge-hub/tizen-studio-smart-tv-application-deployment-9356>, AI-generated
  but quoting the real log) **[medium-high]**. On Tizen 5.5, `sdb shell 0 execute org.tizen.volume-setting`
  also returns `closed` — <https://stackoverflow.com/questions/71994887> **[documented]**. So
  `/dev/fb0`, `xwd`, `cat`, `dd` are all out of reach; there is also no evidence `sdk_toolpath`/`sdk` user
  may read a framebuffer device, and Tizen TV's display path is composited (root tools use X11 `scrot`,
  see §1.4), not a simple `/dev/fb0` the sdk user could read.
* `sdb pull /dev/fb0` is not even possible: this TV's sdb capability says `filesync_support:push`
  (push-only), and every pull attempt fails with `NO support file pull` / `connection fails` (§0.9).

### 1.4 Every real capture tool found requires root

* **SamyGO J-root** feature list (J/K root, T-HK*/T-JZ*): `scrot` — "Screenshot: UI overlay only, FullHD
  resolution"; `screenshot.sh` — "Video+UI (J sysroot>=4.8), 960x540 resolution", with `-n` capture warning,
  `-j` jpg, `-e` channel/program in filename — <https://forum.samygo.tv/viewtopic.php?f=70&t=11720>
  (print view; verified content) **[documented]**. This proves (a) the TV can be screenshotted only from a
  root shell, (b) the TV's display stack is X11-compatible (`scrot`), which is why the root route works.
* **SamyGO K-root** ("K ROOT on T-JZ* and T-HK* fws up to 1169"): method applies to `T-JZ*` and
  `T-HKMFK*` firmwares **up to 1169.2**; "Features and addons (J posts #2 and #3) are strictly same for K";
  requires widget install via Tizen Studio, service-menu changes ("Instant On" off, Watchdog off), ExLink
  optional; **no autostart on T-HKMFK** — <https://forum.samygo.tv/viewtopic.php?p=103580> **[documented]**.
  → On *this* TV the root route is available only if `Menu → Support → Contact Samsung` shows firmware
  `T-HKMFK…` ≤ 1169.2 (unlikely for a 10-year-old set that has been updated; unknown).
* **`chris-ritsen/samsung-tv-root`** capture is a *root-agent payload*: `qn90f-probe/Qn90fScreenAnalysisDump.dll`
  executed as `/usr/bin/dotnet <dll> <out.rgb> sa-ui`, output 960×540 rgb24, capability
  `screenshot.hdmi_960x540` — local checkout `samsung-tv-root/src/samsung_tv_root/capture.py` **[verified-local]**.
  The repo's own compatibility list targets Tizen ≥5.5 and requires a capability-bearing
  `/usr/bin/dotnet`; it explicitly fails on sets without it (e.g. issue #37: "`/usr/bin/dotnet` is
  missing", issue #13 no dotnet on T-NKMAKUC) — <https://github.com/chris-ritsen/samsung-tv-root>
  **[documented]**. Tizen 2.x TVs have no `/usr/bin/dotnet` → **impossible on this generation**.
* `callstack/agent-device` can take "screenshots" of a Tizen TV only via CDP, and its docs spell out the
  limits: *"screenshot captures the app page, not the TV screen. When the app is in the background, the page
  renders no frames, so screenshot fails… System layers such as the Samsung menu never appear in
  screenshot or snapshot."* — same URL as §1.1 **[documented]**.

### 1.5 Probe results — already run on this TV (2026-11-14, Developer Mode ON)

```sh
$ . scripts/tv-env.sh
$ $SDB devices
192.168.0.100:26101   device   UE40K6500
$ $SDB -s 192.168.0.100:26101 capability
secure_protocol:enabled   intershell_support:disabled   filesync_support:push   usbproto_support:enabled
sockproto_support:enabled rootonoff_support:disabled    zone_support:disabled   multiuser_support:disabled
cpu_arch:armv7            profile_name:tv               vendor_name:Samsung
can_launch:tv-samsung-public_-_tv-samsung-partner
platform_version:2.4.0    product_version:2.0           sdbd_version:2.2.31     sdbd_plugin_version:1.0.0
```

| Probe | Result |
|---|---|
| `sdb shell` | `closed` |
| `sdb shell 0`, `0 help`, `0 version` | `closed` |
| `sdb shell 0 vd_applist` / `0 vd_applist --all` / `0 vd_appinfo` / `0 appinfo <id>` | `closed` |
| `sdb shell 0 vd_appinstall …` / `0 vd_appuninstall …` / `0 appinstall …` (all arg variants tried) | `closed` |
| `sdb shell 0 applist` | **WORKS** — 45 apps (No/Name/Version/GUID/Package ID/App ID), §5.1 |
| `sdb shell 0 appshot`, `0 vd_appshot` (± path), `0 screenshot` (± path), `0 capture`, `0 vd_appcapture` | `closed` (all 13 variants) |
| `sdb shell 0 was_execute 9999.Nonexistent` | **accepted** → `launch app 9999.Nonexistent` / `app_id[] launch failed[400]` / `launch app failed` / `spend time for wascmd is [64]ms` |
| `sdb shell 0 debug 9999.Nonexistent` | `closed` — `debug` **not** confirmed on this build (see §3.2) |
| `sdb shell 0 was_kill 9999.Nonexistent` | `closed` — kill verb not confirmed; test with our real app id |
| `sdb shell 0 getduid` | **WORKS** → `<DUID>` |
| `sdb push /tmp/dsh-probe.txt /tmp/dsh-probe.txt` | **WORKS** (6-byte file pushed) |
| `sdb pull /tmp/dsh-probe.txt …` | **FAILS** — `error: failed to read '…': NO support file pull` (filesync push-only) |
| `sdb dlog` | `closed` |

Remaining probes worth one minute (when a debug build is installed): `0 debug <our.pkg.App>` on a real
**debug-enabled** app id (see §3.2); `0 was_kill <our app id>`; `sdb install <wgt>` (all `0 *install*`
verbs are closed here, so the standard `sdb install` / Tizen CLI install path is the one to try). Use the
legacy client only if needed: `SDB_BIN=toolchain/bin/sdb-legacy-2.3.8 ./toolchain/sdb.sh …`.
**Do not** probe `0 debug`/`0 was_execute` with a real store app unless you intend to launch it.

---

## 2. Remote / LAN protocols — control and state, never pixels

### 2.1 8002 websocket API (`ms.remote.control` / `ms.channel.emit`)

The 2016+ Samsung Remote Control API exposes exactly two client methods (verified live, §0.4):

* `ms.remote.control` — `{"Cmd":"Click","DataOfCmd":"KEY_HOME","TypeOfRemote":"SendRemoteKey"}`; also
  `SendInputString`; newer sets also accept `Press`/`Release`.
* `ms.channel.emit` — the TV→client/server event bus: `ed.installedApp.get` (app list, verified),
  `ed.apps.launch` (`{"action_type":"DEEP_LINK"|"NATIVE_LAUNCH","appId":…,"metaTag":…}` — the same
  mechanism `samsungtvws` uses to launch apps), IME events.
* Events received: `ms.channel.connect`, `ms.channel.clientConnect/clientDisconnect`,
  `ms.channel.ready`, `ms.error`, `ms.voiceApp.hide`, `ms.remote.imeStart/imeEnd`,
  `ms.remote.touchEnable/touchDisable`, `ed.edenTV.update`.
* This is the complete known surface of the wrapper
  <https://github.com/xchwarze/samsung-tv-ws-api> (`samsungtvws/remote.py`, `event.py`, `rest.py`)
  **[verified-local + documented]**. **No method, event or parameter returns an image or stream.**

### 2.2 8001 REST (`/api/v2/`, `/ms/1.0/`) — state only

Documented Samsung REST surface (2016+): device info, `/api/v2/applications/<appId>` GET status /
POST launch / DELETE close / PUT install ("store install page"), IME input. `samsungtvws/rest.py`
implements exactly these **[documented + verified-local]**. Screenshot-ish routes were probed and 404
(§0.5). `/ms/1.0/` exposes MultiScreen capabilities only; `/ms/1.0/device|client|channel|screen` are 404
**[verified-live]**.

### 2.3 MultiScreen / Samsung Smart View — TV is a *receiver*, not a source

* The DIAL descriptor advertises `samsung:multiscreen:1` on port 8001, `/ms/1.0/` — that is the
  MultiScreen Framework (MSF) used by Samsung's phone→TV casting. The public MSF Android SDK supports
  **Discover / Connect / Communicate** (launch apps, cast media, messages, gamepad). Its API reference has
  **no** Screen/Capture/Mirror classes at all (checked `allclasses-noframe.html`/`index-all.html`:
  0 matches for `Screen`/`Capture`/`Mirror`) — <http://multiscreensdk.github.io/android-msf-api/apidocs/overview-summary.html>
  **[documented]**.
* Samsung's own Smart View SDK is the same direction: "stream multimedia content **from mobile devices to**
  Samsung Smart TVs" — <https://developer.samsung.com/smarttv/develop/extension-libraries/smart-view-sdk/getting-started.html>
  **[documented]**.
* Samsung's Smart View phone app covers 2011–2016 TVs, but the **TV→phone live stream was removed** from
  the app by late 2016 ("der Live-Stream der App nicht mehr möglich" — chip.de review of Smart View 1.5.5,
  Nov 2016: <https://www.chip.de/downloads/Samsung-Smart-View-Android-App_51367695.html>)
  **[documented/medium]**. Even when it existed it was a closed Samsung-phone ↔ Samsung-server path with
  DRM, not an open TV→PC stream we could record (and it mirrored content, not the TV's UI/OSD).
* Ports 7676/7678 are the **Samsung AllShare UPnP server** (DMS) — content sharing, verified live (§0.6);
  9197 is the DLNA DMR. No screenshot action exists in UPnP AV; `X_GetScreenImage`-style actions are not
  part of the Samsung TV DMR and were not found in the analyzed descriptors
  **[medium-high]**.
* Miracast / WiDi: the 2016 K-series is a **sink** ("Screen Mirroring" receives a phone/PC); there is no
  documented source mode, so you cannot capture the TV through Wi-Fi Display **[high]**.

### 2.4 SmartThings / Remote Access / service menu

* SmartThings on 2016 sets is a hub/control integration; it returns device/app state, not screenshots
  **[medium]**.
* "Remote Access" (connect the TV to a PC desktop) is a 2019+ feature; the "Remote PC" root route in
  `chris-ritsen`'s compatibility list is a *root/cifs* hack on newer sets, not a capture API **[documented]**.
* Service menu (typical 2016 sequence: `MUTE`+`1`+`8`+`2`+`POWER`; model/firmware-dependent) gives control/debug/
  option/SVC pages — test patterns, panel/ADC options, no documented screen-capture function
  **[medium/no evidence]**. Entering it is risky (calibration), don't.

---

## 3. Developer Mode extras — Web Inspector can capture *our app's page*, not the TV

### 3.1 Tizen Studio Web Inspector (TV Extension) — the only documented TV "screenshot"

* "All Samsung TVs since 2015 support the Web Inspector"; it is part of the Tizen Studio **TV Extension**
  and is based on WebKit Web Inspector + Chrome DevTools —
  <https://developer.samsung.com/smarttv/develop/getting-started/using-sdk/web-inspector.html> **[documented]**.
  On this TV the inspector launch verb `0 debug` is not yet confirmed (§3.2) — **verify the Debug As flow
  first**; if it cannot attach, this row collapses to in-app self-capture only.
* For a TV app screenshot: in Tizen Studio **Debug As** the app, then in the Web Inspector open the
  **"Rendering Debug"** tab and use its screen-capture option. "This method only works for capturing
  screenshots of your own app. It's not possible to take screenshots of other apps using this approach."
  — Samsung forum thread Jan 2017 (URLs in §1.2) **[documented]**.
* It is therefore useless for verifying Smart Hub/Home/dialogs/boot, and it is a GUI action (not a CLI
  verb). There is no "screenshot tab" for TVs in the Remote Device Manager; the Device Manager camera
  icon is a **mobile/wearable Tizen** feature, not a TV one [medium] (and the often-cited
  `sdb shell screencap` is Android).
  Tizen Studio CLI 2.5.25 has no screenshot command at all (§0.8) **[verified-local]**.
* Version caveat for a 2016 TV (Tizen 2.4): use **Tizen Studio 1.3 + TV Extension 3.1.2**; newer Studio
  2.x/3.x target TV Extension 4.x+ and can break on 2016 sets. Samsung's TV Extension archive still
  offers 3.1.2 (Nov 2017) — <https://developer.samsung.com/tv/develop/tools/tv-extension/archive>
  **[documented]**; StackOverflow "Can't install app on TV with Tizen Studio 3.2 / MacOS" comments:
  "you cannot use Tizen Studio 3.X to develop apps for Tizen 2.4, that is 2016 and previous… use Tizen
  Studio 1.3 … TV extension 3.1.2" — <https://stackoverflow.com/questions/55935074> **[documented/medium]**.

### 3.2 `0 debug` + port forward + Chrome — scriptable page capture *maybe*

Known mechanics (works on 2016+: Tizen Studio, Wits, agent-device, Appium drivers all use it):

```sh
# 1. launch the installed, debug-enabled app and get its inspector port
$SDB -s 192.168.0.100:26101 shell 0 debug <numeric-app-id-or-package-id>
#   example output from a Tizen 2.4/4 device:
#   ... successfully launched pid = 3962 with debug 1 port: 39819

# 2. forward that port to the Mac
$SDB -s 192.168.0.100:26101 forward tcp:39819 tcp:39819

# 3. ask the inspector for its pages (Chrome DevTools HTTP API)
curl -s http://127.0.0.1:39819/json
#   [{"description":"","id":"…","title":"<pkg>.<app>","type":"page","url":"file:///index.html"}]
#   (some TVs serve the inspector directly on TV_IP:<port> — Samsung's Wits launches
#    chrome at debugIP:debugPort; other reports get "page not found" direct, so use the forward)

# 4. try CDP screenshot of OUR page (Chrome 38-era protocol on Tizen 2.4)
#    ws = ws://127.0.0.1:39819/devtools/page/<id>
#    {"id":1,"method":"Page.enable"}
#    {"id":2,"method":"Page.captureScreenshot","params":{"format":"png"}}
```

> Live note (2026-11-14, §0.9): on this TV `0 debug 9999.Nonexistent` returns `closed`, while
> `0 was_execute 9999.Nonexistent` is accepted and returns the app-level failure — so on this 2016 build
> `debug` is either gated on an installed, debug-enabled app id or not available at all. Test it with our
> real launcher id immediately after installing a debug build; if `0 debug` stays `closed`, the whole CDP
> row above is unavailable on this TV and only the GUI Web Inspector (if its Debug As path uses a
> different mechanism) or in-app self-capture remain.

Sources: StackOverflow "Open Tizen Remote Web Inspector from command line" (answer 79742222, 2025) gives the
`0 debug` output format, the forward, `http://localhost:<port>/json`, the manual DevTools URL, and —
important for this TV — **"Tizen 2.4 or 2 … (Chrome 38)"**
<https://stackoverflow.com/questions/45275774> **[documented]**. `Page.captureScreenshot` has existed in
Chrome DevTools protocol since Chrome ~31 (2013), so a Chrome-38 protocol server *should* answer it —
but whether Tizen 2.4's WebKit-based inspector implements the `Page` domain that way is unproven; treat as
a **probe** (5 minutes once dev mode is on). If the raw CDP call fails, the documented fallback is the GUI
Web Inspector "Rendering Debug" tab (§3.1). Conflicts in public reports: one 2019 user saw "page not found"
on direct `TV_IP:7011` and `sdb dlog` `closed` — <https://stackoverflow.com/questions/55060322>
**[documented]** — so always forward and verify.

### 3.3 `0 debug` cannot attach to an already-running app

`0 debug` always cold-starts the app (agent-device: "cannot attach to a running app, so `open` kills it
first") — fine for capture of our launcher, not for inspecting Samsung UI **[documented]**.

---

## 4. Practical alternatives (ranked for this project)

### 4.1 Camera aimed at the panel — the only automatable source of TV-screen pixels — **RECOMMENDED**

Cheapest reliable rigs, in order:

1. **Old Android phone + "IP Webcam" app** on a tripod/stand, focused on the panel, plugged into USB power.
   Fully scriptable from the Mac with plain HTTP:
   ```sh
   curl -s "http://PHONE_IP:8080/shot.jpg" -o backup/verify/latest.jpg
   ```
   Works regardless of macOS camera permissions; the phone can sit next to the TV indefinitely.
2. **USB webcam** (e.g. Logitech C270/C920-class, or any UVC cam) + a long USB cable, taped to the TV
   stand. On this Mac:
   ```sh
   brew install ffmpeg                      # ffmpeg is NOT installed here yet (verified 2026-11-14)
   ffmpeg -hide_banner -f avfoundation -list_devices true -i ""   # find the camera index/name
   ffmpeg -y -f avfoundation -i "0" -frames:v 1 -update 1 backup/verify/latest.png
   ```
   macOS will ask for Camera permission for the terminal/agent the first time; grant it once. If the
   camera is a Continuity Camera (iPhone, macOS 13+), it appears as an avfoundation device when the
   iPhone is near/unlocked. Alternative tool: `brew install imagesnap && imagesnap -l`.
3. **Human phone photo** — always available; use for milestones and as fallback when the rig is not set up.
   Sync via iCloud/Photos to a Mac folder if you want the photos archived next to the state snapshots.

Optional OCR on the camera frame to make assertions textual:
```sh
brew install tesseract
tesseract backup/verify/latest.png - 2>/dev/null | grep -i "samsung\|smart hub\|launcher"
```

Crop the frame to the panel and use a fixed exposure/white balance so before/after diffs are meaningful.

### 4.2 Our own web app — self-capture without any TV feature — **RECOMMENDED for UI iteration**

Because we control the launcher Tizen web app, it can report its own pixels/state to the Mac:

* **State/heartbeat:** `fetch("http://192.168.0.10:8765/state", {method:"POST", body: JSON.stringify({…})})`
  every 1–2 s (needs `<access origin="http://192.168.0.10:*" subdomains="true"/>` + internet privilege in
  `config.xml`; allowed for dev-signed apps). This proves "our app is in the foreground, on screen N,
  reacting to key X" with no sdb and no camera.
* **DOM dump:** post `document.activeElement`, focused element id, visible text — enough to verify remote
  key handling.
* **Page pixels:** draw the UI into a `<canvas>` (or use a small `html2canvas`-style renderer) and POST
  `canvas.toDataURL("image/png")`. This gives *our UI's* exact pixels at 1920×1080; it does **not** include
  Samsung system layers (menu, OSD, Smart Hub), which do not exist inside our page.
* Inspector capture of the same page: §3.1/§3.2.

### 4.3 HDMI capture dongle — **does not work for this** (correction to earlier research)

The UE40K6500 is a **sink**: its HDMI ports are inputs, and the only HDMI-adjacent output is HDMI-ARC
(audio only). An HDMI capture dongle needs an HDMI *source* signal; there is nothing on the TV to plug it
into. A splitter inserted between an external source and the TV captures what the TV is being fed, not the
Samsung UI (and misses all overlays). So: **HDMI capture can verify the launcher only if the launcher is
piped out as HDMI, which it is not** — use the camera instead. UVC dongles are still useful for capturing
other boxes (console/PC) that feed the TV, but not the TV itself.

### 4.4 Root — last resort, not for this project

* If (and only if) `Menu → Support → Contact Samsung` shows `T-HKMFK…` firmware ≤ **1169.2**, SamyGO
  K-root exists: widget install via Tizen Studio, service-menu Instant-On/Watchdog changes, USB sysroot;
  then `scrot` (UI overlay, FullHD) and `screenshot.sh` (video+UI, 960×540) work — see §1.4. It requires
  physical USB access, service-menu changes, and carries brick/warranty risk; SamyGO itself warns about
  watchdog/Instant-On settings. For a project whose goal is a launcher, this is disproportionate risk.
* The `chris-ritsen` root chain (the modern, maintained one) **cannot** run on Tizen 2.x: it needs
  `/usr/bin/dotnet`, absent on this generation (§1.4). Don't plan around it.

### 4.5 Phone-photo workflow (when no camera rig)

Minimum human burden: photos only at checkpoints that are inherently visual —
(1) baseline Smart Hub, (2) after Developer Mode enable/reboot, (3) after installing the launcher,
(4) after the Home-button/vconf change, (5) after any reboot/restore, (6) any unexpected black screen.
Everything else is covered by §0.3/REST/WS state + the app's own telemetry.

---

## 5. What we *can* capture programmatically for verification (commands)

### 5.1 List installed apps (this generation)

| Command | Output | Confidence |
|---|---|---|
| `sdb -s 192.168.0.100:26101 shell 0 applist` | **the app-list command on this generation — WORKS live**: ASCII table, 45 apps, columns `No`, `Name`, `Version`, `GUID`, `Package ID`, `App ID` (e.g. `9Ur5IzDKqV.TizenYouTube`) | **[verified-live]** |
| `sdb … shell 0 vd_applist` (and `--all`, `0 vd_appinfo`) | `closed` on this TV — the `vd_*` generation is not whitelisted on Tizen 2.4 retail | **[verified-live]** |
| `sdb … shell 0 getduid` | **WORKS** → `<DUID>` (the DUID used for certificates) | **[verified-live]** |
| websocket `ed.installedApp.get` | JSON `appId`, `name`, `app_type`, `icon` — **verified live on this TV, no sdb needed** | [verified-live] |
| `sdb -s … capability` | `profile_name:tv`, `vendor_name:Samsung`, `can_launch:tv-samsung-public_-_tv-samsung-partner`, `platform_version:2.4.0`, `product_version:2.0`, `sdbd_version:2.2.31`, `secure_protocol:enabled`, `intershell_support:disabled`, `filesync_support:push`, … | [verified-live] |
| `tizen device list` | **does not exist** in Tizen Studio CLI 2.5.25; use `sdb devices` / Tizen Studio Connection Explorer | [verified-local] |

For provenance, save both list forms: `backup/applist.txt` (sdb `0 applist`) and `backup/apps-ws.json`
(websocket). Note the counts differ on this TV (36 via websocket vs 45 via `0 applist`) — the websocket
list omits some system/hidden apps, so use `0 applist` as ground truth.
Neither contains a foreground-app field; `sdb shell 0` has no foreground-app command (agent-device
README), and `/api/v2/applications/<id>.visible` is reported `false` even when the app is in front on
modern sets — test on this TV before relying on `visible`; `running:true` right after launch is a good
signal **[medium]**.

### 5.2 Launch / close / detect our app

```sh
# launch our installed app (works on this TV: 0 was_execute is accepted, 0 debug is NOT confirmed)
# <app-id>: on this TV `0 applist` shows both "Package ID"/GUID and "App ID" (GUID.Name);
# `0 debug` is documented with "<pkg>.<app>" (Tizen Studio) — try that and capture the exact reply.
$SDB -s 192.168.0.100:26101 shell 0 was_execute <app-id>        # VERIFIED accepted on this TV
$SDB -s 192.168.0.100:26101 shell 0 was_kill <app-id>           # UNCONFIRMED: closed with bogus id
$SDB -s 192.168.0.100:26101 shell 0 debug <app-id>              # UNCONFIRMED on this build (closed with bogus id)

# install path: `0 vd_appinstall` is closed on this TV and `0 appinstall` was refused with bogus args
# (§0.9) -> try the sdb package install verb / Tizen CLI first, not the `0 vd_appinstall` recipe of
# 2020+ sets (and note the `0 appinstall tpk \`vconftool …\`` injection trick is a Tizen 5.5+ bug):
$SDB -s 192.168.0.100:26101 install /path/to/app.wgt
$TIZEN install -s 192.168.0.100:26101 -n app.wgt -- /path/to   # Tizen Studio CLI (needs working sdb install)

# state checks, no sdb:
curl -s http://192.168.0.100:8001/api/v2/applications/<numeric-app-id>   # {"running":true,"visible":…,"version":…}
curl -s -X POST   http://192.168.0.100:8001/api/v2/applications/<id>    # launch via REST (documented)
curl -s -X DELETE http://192.168.0.100:8001/api/v2/applications/<id>    # close via REST (documented)
# websocket alternative: {"method":"ms.channel.emit","params":{"event":"ed.apps.launch","to":"host",
#   "data":{"action_type":"NATIVE_LAUNCH","appId":"<id>","metaTag":""}}}
```

`0 was_execute` / `0 getduid` / `sdb push` are **[verified-live]** on this TV; `0 debug`, `sdb dlog`,
`sdb pull` and all `0 *install*` verbs are not available. REST POST/DELETE and `ed.apps.launch` are
documented for modern Tizen TVs (implemented in `samsungtvws`) — they are **probes** on this 2016 set (the
GET worked; POST/DELETE untested to avoid changing TV state). DIAL `/ws/apps/<name>` reports
`stopped`/`running` for DIAL-registered apps only (YouTube was `stopped`).

### 5.3 Version / device facts (for logs)

* `curl -s http://192.168.0.100:8001/api/v2/` — model, `msfVersion`, `developerMode`, `developerIP`,
  resolution, countryCode, `OS: Tizen`; **not** the firmware version (`firmwareVersion: Unknown`).
* `curl -s http://192.168.0.100:8001/ms/1.0/` — DUID, model, capabilities.
* `http://192.168.0.100:9197/dmr` — serial number `<SERIAL>`, `sec:ProductCap … FHD_SCREEN`.
* Firmware version: only `Menu → Support → Contact Samsung` (human, once).
* `sdb version`, `sdb -s … get-serialno`, `sdb -s … capability` once dev mode is on.

### 5.4 What remains unverifiable without a camera

Samsung UI pixels: Smart Hub appearance, the Home-button destination, dialogs, boot/loading screens,
system OSD, whether a remote key produced the expected Samsung UI change, "black screen" issues.
Those are exactly the milestones that need a (scripted) camera frame or a human photo.

---

## 6. Recommended verification workflow (given a user who can take phone photos)

Goal: every automated step gets (a) machine-checkable state, (b) a camera frame; the human takes photos
only at milestones.

**One-time setup**

1. Mount an old Android phone running "IP Webcam" (or a USB webcam) aimed at the panel; test
   `curl -s http://PHONE_IP:8080/shot.jpg -o /tmp/frame.jpg`; crop to panel; fix exposure.
2. On the Mac: `brew install ffmpeg tesseract` (only needed for the USB-cam path; `ffmpeg` is currently
   absent).
3. Keep `scripts/tv-env.sh` sourced (TV_IP, SDB paths). Confirm 8002 websocket control works:
   `tv/tv_remote.py --name dsh-agent key KEY_INFO` (this set accepts that client name without a token).
4. Baseline: `curl /api/v2/` + websocket app list + DIAL states + one camera frame + one phone photo,
   saved under `backup/verify/<timestamp>/`.

**Per step (fully scriptable)**

```sh
#!/bin/sh
# sketch: state snapshot + camera frame + optional OCR, one folder per step
set -eu
IP=192.168.0.100; OUT=backup/verify/$(date +%Y%m%d-%H%M%S); mkdir -p "$OUT"
curl -s "http://$IP:8001/api/v2/" > "$OUT/api-v2.json"
curl -s "http://$IP:8001/api/v2/applications/${APP_ID:-111299001912}" > "$OUT/app.json"
curl -s "http://$IP:8001/ws/apps/YouTube" > "$OUT/dial-youtube.xml"
.venv/bin/python - "$OUT" <<'PY'
import base64,json,ssl,sys,websocket
out=sys.argv[1]
ws=websocket.create_connection(
 "wss://192.168.0.100:8002/api/v2/channels/samsung.remote.control?name="+base64.b64encode(b"verify").decode(),
 timeout=8, sslopt={"cert_reqs":ssl.CERT_NONE,"check_hostname":False})
while True:                                    # wait for channel ready
    if json.loads(ws.recv()).get("event")=="ms.channel.connect": break
ws.send(json.dumps({"method":"ms.channel.emit",
                    "params":{"event":"ed.installedApp.get","to":"host"}}))
while True:
    m=json.loads(ws.recv())
    if m.get("event")=="ed.installedApp.get":
        json.dump(m,open(out+"/apps-ws.json","w"),ensure_ascii=False,indent=1); break
ws.close()
PY
ffmpeg -y -loglevel error -f avfoundation -i "${CAM:-0}" -frames:v 1 -update 1 "$OUT/screen.png" || true
tesseract "$OUT/screen.png" - 2>/dev/null > "$OUT/screen.txt" || true
```

* When our app is installed: also capture `0 applist` (with sdb; `vd_applist` is closed on this TV), the app's own heartbeat/DOM POST, and
  (after `0 debug` + forward) an inspector page screenshot of our page if the CDP probe works.
* Compare: did the app list change? did `running` flip? did the camera frame change (pixel diff)? did OCR
  find the expected text ("Samsung", "Smart Hub", our launcher's title)?
* Human phone photo only when a step is visual/irreversible: Developer Mode enable, each reboot, the
  Home-button takeover, a black screen, a restore.

**Promised deliverable quality:** "every step is verified" = every step has a state assertion + a camera
frame; human photos are a subset, not the mechanism.

---

## 7. What would change this verdict (cheap things to revisit later)

1. **A `0 …` verb that returns data instead of `closed`** — already probed for all capture names and the
   `vd_*` family (§1.5); the only unresolved verb is `0 debug` with a real, installed debug build (§3.2).
2. **Firmware ≤ 1169.2** on `Menu → Support → Contact Samsung` → SamyGO K-root becomes possible
   (root-only screenshots; high effort/risk).
3. **CDP works on the `0 debug` port** for our app page (§3.2) → automatable *page* pixels (never TV UI).
4. A future discoverable capture endpoint in the 8002/8001 surface (none in five years of public tooling;
   the surface in `samsungtvws` is the community's complete knowledge).

---

## 8. Sources

**Samsung / Tizen official**
* Web Inspector (TV Extension, "all Samsung TVs since 2015") — https://developer.samsung.com/smarttv/develop/getting-started/using-sdk/web-inspector.html
* Smart View SDK (mobile→TV) — https://developer.samsung.com/smarttv/develop/extension-libraries/smart-view-sdk/getting-started.html
* TV Extension archive (3.1.2 still downloadable) — https://developer.samsung.com/tv/develop/tools/tv-extension/archive
* Samsung/Wits (official TV dev tool; `0 vd_appinstall`, `0 vd_appuninstall`, `0 was_execute`, `0 debug`) — https://github.com/Samsung/Wits · https://raw.githubusercontent.com/Samsung/Wits/c18cf03eced66aa66c3603c94fccf4c14d193f00/lib/appLaunchHelper.js
* Tizen wiki, screenshot (mobile Tizen 2.x `xwd`) — https://wiki.tizen.org/Capture_Screenshot_in_Tizen
* Tizen Studio TV screenshot Q&A (Jan 2017, archived; "only your own app, other apps not possible") — https://d2h8mbl10wxvsa.cloudfront.net/forums/web-application-development/tizen-tv-app-taking-screenshot (AI mirror: https://samsungtizenos.com/knowledge-hub/tizen-tv-app-screenshot-tizen-studio-8141)
* Tizen Studio on 2016 TV (`sdb … closed` log; Tizen Studio 1.3 + TV Extension 3.0/3.1.2) — https://samsungtizenos.com/knowledge-hub/tizen-studio-smart-tv-application-deployment-9356 · https://stackoverflow.com/questions/55935074

**Community tooling / reference implementations**
* `callstack/agent-device` Tizen plugin (CDP page screenshots; "restricted sdb shell 0 has no screen-capture command") — https://github.com/callstack/agent-device/blob/d2426fffdf7829f58458ec1631bd117e6cd8cf94/packages/provider-tizen/README.md · https://github.com/callstack/agent-device/blob/d2426fffdf7829f58458ec1631bd117e6cd8cf94/website/docs/docs/tizen.md
* `samsungtvws` (complete known 8001/8002 API surface) — https://github.com/xchwarze/samsung-tv-ws-api
* `0 debug` + forward + inspector/Chrome 38 for Tizen 2.4 — https://stackoverflow.com/questions/45275774
* `sdb capability` fields; `0 execute` → `closed` — https://stackoverflow.com/questions/71994887
* `sdb dlog` closed / direct inspector port page-not-found — https://stackoverflow.com/questions/55060322
* `0 …` command set reverse-engineering thread (laat gist + comments) — https://gist.github.com/laat/2b7107298593dca650062b7678279386
* MultiScreen (MSF) Android SDK API (no capture classes) — http://multiscreensdk.github.io/android-msf-api/apidocs/overview-summary.html

**Root-only capture (for completeness; needs root)**
* SamyGO J-root features: `scrot` (UI overlay FullHD), `screenshot.sh` (video+UI 960×540) — https://forum.samygo.tv/viewtopic.php?f=70&t=11720 (print view)
* SamyGO K-root (applies to `T-HKMFK*` ≤ 1169.2; same features as J) — https://forum.samygo.tv/viewtopic.php?p=103580
* `chris-ritsen/samsung-tv-root` (root-agent capture; Tizen ≥5.5 + `/usr/bin/dotnet`) — https://github.com/chris-ritsen/samsung-tv-root · local: `samsung-tv-root/src/samsung_tv_root/capture.py`

**Local evidence from this session (repository files)** — `backup/probe-20261114-194814/` (probe.sh:
capability, closed-shell matrix, `0 applist`, pull logs), `backup/20261114-194852/` (backup.sh: app list,
vconf attempts, API dump), plus the §0.9 raw probes. Tizen Studio CLI 2.5.25 TV command strings:
`toolchain/tizen-studio/tools/tizen-core/tz`.

**Background / privacy (not a usable API)**
* Researcher claims Samsung TVs collect screenshots/audio telemetry for ads (2025 model, required root to inspect) — https://tech.yahoo.com/cybersecurity/articles/cybersecurity-bounty-hunter-says-samsung-100000390.html
* Smart View 1.5.5 (Nov 2016) review noting the TV→phone live stream was removed — https://www.chip.de/downloads/Samsung-Smart-View-Android-App_51367695.html
