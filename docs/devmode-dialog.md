# Developer-mode dialog driven by synthetic keys — Samsung UE40K6500 (2016, Tizen 2.4, RU)

How the `Apps → 12345` "Developer mode" popup behaves with the LAN websocket remote-control
API (`ws://<tv>:8002/api/v2/channels/samsung.remote.control`, `SendRemoteKey`), and the exact
key sequences that work on this unit.

Evidence tags: **[V]** = verified live on this exact TV (2026‑11‑14, this session's logs +
phone photos); **[S]** = documented in Samsung docs / community sources (URLs in §9);
**[U]** = unknown or inferred, not yet tested.

## 1. Dialog layout

```
Developer mode : On          [ Вкл. ]  [ Выкл. ]      ← row 1, focus starts on the "Вкл." button
Host PC IP :   [ 192 ] . [ 168 ] . [ 0 ] . [ 9 ]      ← row 2, four separate octet boxes
               [ OK ]   [ Отмена ]                     ← row 3
```

- Russian build keeps the English labels `Developer mode`, `Host PC IP`, `OK`; the buttons are
  localised `Вкл.` / `Выкл.` / `Отмена`. **[V, photo]**
- Empty boxes may show `0` placeholders on some firmwares; on this unit they are empty and the
  digits simply overwrite them. **[V, photo]** + **[S]** Samsung forum thread #7065.
- The state word after the colon (`On`/`Off`) is the current *editor* state, not the applied state.

## 2. Reconstructed state machine (all transitions below are **[V]**)

```
                  12345 (fast) on Apps panel
Apps panel ─────────────────────────────────► Dialog (Dev=Off, IP blank)
     ▲                                              │
     │  RETURN / Отмена                             │ ENTER on "Вкл." (or if focus already on it: no-op)
     └──────────────────────────────────────────────┤
                                                    ▼
                                   Dialog (Dev=On, IP blank)
                                                    │ DOWN  → octet 1
                                                    │ digits fill the focused octet (max 3, extra dropped)
                                                    │ RIGHT → next octet (×3)
                                                    │ DOWN  → OK / Отмена row
                                                    │ ENTER on OK
                                                    ▼
                                   Dialog CLOSED — config staged, NOT applied
                                   (REST /api/v2/ still developerMode=0, developerIP="")
                                                    │ full restart of the TV
                                                    ▼
                                   Applied: REST developerMode=1, developerIP=192.168.0.10,
                                   TCP 26101 open, Apps panel shows the "Develop Mode" tag [S]
```

Key facts:

1. **The four octets are four separate fields.** Focus starts on the toggle (`Вкл.`) and moves
   rows with `UP`/`DOWN` (one press per row) and inside the IP row with `LEFT`/`RIGHT`. **[V]**
2. **Number keys write into the focused octet directly — there is no on-screen keypad inside
   this dialog.** **[V]** Same conclusion for another 2016 Tizen set from a Stack Overflow
   report: the host IP is typed "using the same procedure — clicking 123 on the remote", i.e.
   number-key codes. **[S]**
3. **There is NO auto-advance.** After the 3rd digit the box stays focused and further digits
   are dropped; you must send `KEY_RIGHT` to move to the next octet — including after 1‑digit
   octets. `192.168.0.10` = `192` `RIGHT` `168` `RIGHT` `0` `RIGHT` `9`. No zero padding. **[V]**
4. **`OK` closes the dialog silently** — no "restart now?" prompt was shown. The setting is only
   staged at this point. **[V]** (the "Restart" popup in Samsung's current doc, Figure 5, is
   from a newer Tizen UI — see §7).
5. **`KEY_RETURN` closes/cancels the dialog; partially entered data is discarded** — reopening
   with `12345` shows empty fields. **[V]**
6. **The REST API is not live-updated by the dialog.** While the dialog was being edited and for
   ~70 s after `OK` (before the reboot) `/api/v2/` kept `developerMode: 0`, `developerIP: ""`;
   it flipped to `1` / `192.168.0.10` only after the TV came back from the restart. **[V]**

## 3. The exact key sequence (primary — verified end-to-end on this TV)

Preconditions: TV on the Apps panel, dialog visible, label `Developer mode : On`, focus on
`Вкл.` (as in the photo). Keys are sent via the websocket remote-control channel
(`tv/tv_remote.py`; `Cmd: Click`, `DataOfCmd: KEY_*`). Pace: **0.5–1.5 s per key**.

```
# 0) only if a stale/partially-filled dialog is open — close it and re-open cleanly
KEY_RETURN
KEY_1 KEY_2 KEY_3 KEY_4 KEY_5      # Apps panel: 12345 re-opens the popup

# 1) make sure developer mode is On (focus is on Вкл.; ENTER on already-selected Вкл. is a no-op)
KEY_ENTER

# 2) toggle row → first octet
KEY_DOWN

# 3) type 192.168.0.10 — RIGHT is required between octets (no auto-advance)
KEY_1 KEY_9 KEY_2
KEY_RIGHT
KEY_1 KEY_6 KEY_8
KEY_RIGHT
KEY_0
KEY_RIGHT
KEY_9

# 4) IP row → buttons row (OK is the left button), activate OK
KEY_DOWN
KEY_ENTER

# 5) full restart (see §4), then verify (§5)
```

Result on this unit: photo showed `192.168.0.10` in the four boxes before `OK`; after the restart
the TV exposed `developerMode=1`, `developerIP=192.168.0.10` and TCP 26101. **[V]**

**Pacing gotcha [V]:** one `KEY_RIGHT` was silently swallowed when sent in a fast burst —
the dialog ignored it and the next digits landed in the previous octet. If a `RIGHT` seems to
have no effect, pause ≥1 s and send it again before typing the next octet.

### Fallbacks (try in this order)

| # | Trigger | Action |
|---|---|---|
| F1 | label shows `Off`, focus on `Вкл.` | `KEY_ENTER` (label becomes `On`), then continue from step 2. |
| F2 | `DOWN` from the toggle does not visibly reach octet 1 | send `KEY_DOWN` again; or `KEY_RIGHT` (to `Выкл.`) then `KEY_DOWN`; or `KEY_UP` then `KEY_DOWN` to re-enter the row. **[U]** |
| F3 | digits do not appear / are ignored | some Samsung IP editors need `KEY_ENTER` on the field to enter edit mode first: `KEY_ENTER`, then digits. Also retry at 1.5 s spacing. **[S]** (older Samsung TV manual pattern), **[U]** here |
| F4 | octets filled wrongly (leftover `0`s, shifted digits) | `KEY_RETURN`, re-open with `12345`, redo from step 2. There is no delete key; a clean re-open is faster. **[V]** |
| F5 | cannot reach/activate `OK` | from octet 4: `KEY_DOWN`, then `KEY_LEFT`/`KEY_RIGHT` until `OK` is highlighted, `KEY_ENTER`. If `OK` was accepted but REST stays `0` after the restart, redo the whole dialog. **[U]** |
| F6 | all keys ignored | check the websocket session (`ms.channel.unauthorized` → re-pair in `tv/tv_remote.py`); the dialog needs keys only, no extra pairing. |
| F7 | number keys rejected entirely | try `SendInputString` with `"192.168.0.10"` while octet 1 is focused (`tv/tv_remote.py send_text`) — unverified on Tizen 2.4. **[U]** |

## 4. Restart (required for the setting to take effect)

- Dev mode is not active until the TV has fully restarted; a plain standby/on may not start
  `sdbd`. Samsung's own docs: "Reboot the TV"; Smart View SDK doc: "Reboot TV. (Unplug and
  Plug the TV)". Community guides: hold power until the `Smart TV Powered by Tizen` boot logo
  (≈5 s), or disconnect power for 30–60 s. **[S]**
- Verified method here: long-press over websocket (`Cmd: Press` `KEY_POWER`, wait ~5 s,
  `Cmd: Release`) → TV left the network at 19:47:15, came back at 19:47:52 with dev mode
  applied. **[V]**
- **Caution [V]:** the trailing `Release` was interpreted as a *second* power toggle — the TV
  rebooted, applied dev mode, then went back to standby at 19:49:18. If you replay the long
  press, expect to send one `KEY_POWER` click afterwards to wake the TV; dev mode survives it
  (verified: after a manual wake at 19:53:31 the TV still reported `developerMode=1`,
  `developerIP=192.168.0.10`). Alternatively just ask the owner to hold the physical power
  button / unplug the TV for a minute.
- Do not re-open the dialog after a successful restart; dev mode persists across power cycles
  until it is turned `Off`. **[V]**

## 5. How to verify without a photo

Run from the Mac (TV = `192.168.0.100`, host PC IP = `192.168.0.10`):

| # | Check | Command | Expected |
|---|---|---|---|
| 1 | REST state — the authoritative applied state | `curl -s http://192.168.0.100:8001/api/v2/ \| python3 -c 'import json,sys;d=json.load(sys.stdin)["device"];print(d["developerMode"], repr(d["developerIP"]))'` | before restart `0 ''`; after restart `1 '192.168.0.10'` **[V]** |
| 2 | sdbd port | `nc -z -G 2 192.168.0.100 26101 && echo open` | open only after the restart **[V]** |
| 3 | sdb device | `sdb devices` | `192.168.0.100:26101  device  UE40K6500` **[V, backup 20261114-194852]** |
| 4 | Apps2Samsung readiness | `tools_bin/apps2samsung-cli tv 192.168.0.100 --local-ip 192.168.0.10 --json` | `"developerMode": true, "developerIp": "192.168.0.10", "debugPortOpen": true, "ready": true`, no `notReadyReason` (before: `"problem": "DeveloperModeOff"`) |
| 5 | project readiness | `toolchain/tv-ready.sh` | 26101 open + sdb lists the TV |
| 6 | `sdb capability` | `sdb -s 192.168.0.100:26101 capability` | `secure_protocol:enabled`, `intershell_support:disabled` (expected on this unit) **[V]** |

Boot-timing note **[V]**: after a restart TCP 26101 can accept connections ~30 s *before* the
HTTP API on 8001 answers (observed 19:47:23 open vs 19:47:52 API up). Poll both for up to
~90 s; an `ERR`/timeout on 8001 right after boot is not a failure.

Do **not** trust the dialog's own labels as proof, and do not use `/api/v2/` as proof while the
dialog is open — it shows the last applied state, not the staged one. Last resort (needs a
human): Apps panel shows a `Develop Mode` tag at the top after the reboot. **[S]**

## 6. Pitfalls on 2015–16 J/K series

- **Host PC IP shows `0.0.0.0` / "field not editable"** (mostly newer models, reported on
  Tizen 5.5+): the zeros are placeholders; use a remote whose keys send digits and type the
  address — the boxes change as you press. **[S]** Samsung forum #7065; Jellyfin issue #16.
- **Fields blank again when the dialog is re-opened before the restart** — normal: nothing is
  saved until `OK` + restart. **[S]** Samsung dev forum (M5500/SDB thread); **[V]** here.
- **RTL (Arabic/Hebrew UI) mirrors the octets** → the IP must be entered reversed
  (`192.168.0.10` → `9.0.168.192`); the known fix is to switch the TV UI language to English,
  re-enter the IP and restart. **[S]** TizenTube guide, moonlight-tizen wiki, install-wgt-tizen
  README, Samsung dev forum #18287. Not applicable to this RU (LTR) unit. **[U]**
- **Host PC IP must be this Mac's LAN address (`192.168.0.10`, `en0`)**. This Mac has VPN
  interfaces; Apps2Samsung auto-detects `172.16.9.1` — always pass `--local-ip 192.168.0.10`.
  If the TV stores the wrong address, sdb connect fails even with dev mode on. **[S + local docs]**
- **Standby is not a restart**: some sets need a power-cycle/unplug for `sdbd` to start. **[S]**
- **Dev mode can switch itself off** after a day on some sets — re-enable, re-enter IP, reboot. **[S]**
- **Digits beyond 3 per octet are dropped; no auto-advance** — always `KEY_RIGHT`. **[V]**
- **`KEY_RETURN` cancels and discards** the typed IP. **[V]**
- If REST reports `developerMode=1` but 26101 is still closed, the TV has not really restarted —
  reboot again (or check you entered the right host IP).

## 7. Confidence / unknowns

- Focus order, digit entry, no-auto-advance, OK behaviour, reboot requirement, REST timing:
  **[V]** on this TV (key sequence produced the expected result; photos confirmed octets).
- After `OK` no restart prompt was displayed on this 2016 set — the dialog just closed. **[V]**
  Samsung's current online doc shows a "Reboot popup" (Information: *Develop Mode is in Off
  status. To enable developer mode on a TV, turn it off and then restart it. You can turn the
  TV off by holding the power button for 2 seconds.*) but that screenshot is a newer Tizen UI;
  it is what you may see if the Apps panel is opened before the restart. **[S]**
- Whether the staging is written anywhere before the restart is unknown; empirically the REST
  API does not see it. **[V/U]**
- RTL behaviour untested here. **[U]**

## 8. sdb notes on this unit (post dev-mode)

`sdb capability` **[V]**: `secure_protocol:enabled`, `intershell_support:disabled`,
`rootonoff_support:disabled`, `platform_version:2.4.0`, `sdbd_plugin_version:1.0.0`,
`can_launch: tv-samsung-public_-_tv-samsung-partner`.
`sdb shell 0 applist` works; the other `0 …` daemon verbs tried (`vd_applist`, `appinstall`,
`appuninstall`, `debug`, `execute`, `applaunch`, `screenshot`) answer `closed`.

Install paths still to try now that dev mode is on (not verified yet): Tizen CLI
(`toolchain/tizen.sh install -s 192.168.0.100:26101 -n <app>.wgt -- <dir>`), the in-process
Apps2Samsung CLI (`apps2samsung-cli install … --local-ip 192.168.0.10`, optionally
`--via tvstore`), and bare `sdb install <app>.wgt`. Inspect
`~/Library/Application Support/Apps2Samsung/cli/logs/` to see which SDB verbs the CLI actually
issues; that log is the fastest way to tell whether the TV accepts an install method at all.

What the local Tizen Studio 10.0 tooling actually sends (strings extracted from the binaries,
for reference):

- `tools/sdb` hard-codes `shell:0 appinstall %s %s` for its `install` command.
- Tizen CLI (`tools/tizen-core/tz`) has templates `shell 0 applist`, `shell 0 appinstall %s %s`,
  `shell 0 appuninstall %s`, `shell 0 vd_applist`, `shell 0 vd_appinstall %s %s`,
  `shell 0 vd_appuninstall %s`, `shell 0 execute %s` and switches on `secure_protocol` /
  `intershell_support` capabilities.
- Device Manager (`device-manager/bin/sdblib.jar`) uses a *different* path: `0 uname`,
  `0 getvmname`, `0 getappinstallpath` ("Tizen Application Installation Path: …"), `0 getduid`,
  plus an install/uninstall "service" over the SDB sync channel; its
  **"Permit to install applications"** action is a certificate upload, and its error strings
  require a *Samsung* certificate profile whose DUID list contains this TV
  ("No DUID for selected device was found in the certificate profile"). So on a retail 2016
  set the refusal may be the missing permit/certificate step, not the verb spelling.

Cheap probes that are safe to run next: `sdb -s 192.168.0.100:26101 shell 0 uname`,
`… shell 0 getappinstallpath`, `… shell 0 getduid` (they show whether the plugin allows more
than `applist`, and give the DUID for a certificate profile); then `sdb -s … install <wgt>`;
then Tizen Studio Device Manager → right-click TV → "Permit to install applications" (needs a
Samsung-account certificate) and retry the install.

## 9. Sources

- Samsung Developer, *TV Device* (developer-mode steps, dialog figure, reboot) —
  <https://developer.samsung.com/smarttv/develop/getting-started/using-sdk/tv-device.html>
  · dialog figure: <https://d3unf4s5rp9dfh.cloudfront.net/SmartTV_doc/4.developer.mode.png>
  · "Reboot popup" figure: <https://d3unf4s5rp9dfh.cloudfront.net/SmartTV_doc/5.reboot.pop.up.png>
- Samsung Developer, *Smart View SDK — Debugging* (`/api/v2/` `developerMode`/`developerIP`,
  "Reboot TV. (Unplug and Plug the TV)") —
  <https://developer.samsung.com/smarttv/develop/extension-libraries/smart-view-sdk/receiver-apps/debugging.html>
- Samsung Developer Forum, *Dev Mode Host PC IP is 0.0.0.0 — can't change it* ("the zeros on the
  slots don't matter… use a remote control that has numbers… they will change as you press") —
  <https://forum.developer.samsung.com/t/detail?id=7065-Dev-Mode-Host-PC-IP-is-0.0.0.0-cant-change-it>
- Samsung Developer Forum, *Can't get logs… UE32H5000F* (RTL Hebrew: switch UI language to
  English and re-enter the Host PC IP) — <https://forum.developer.samsung.com/t/detail?id=18287-Can't-get-any-logs-from-my-UE32H5000F-(Tizen-8.0)-even-though-sdb-connects.-Is-that-normal?>
- Stack Overflow, *Enable Developer mode on Tizen TV 2016 [KU6300]* (IP typed with the "123"
  number keypad, no separate keypad) — <https://stackoverflow.com/questions/41110953/enable-developer-mode-on-tizen-tv-2016-ku6300>
- flutter-tizen, *configure-device.md* (dialog screenshot: `Developer mode: Off [On][Off]`,
  `Host PC IP` four boxes with `0`, `OK`/`Cancel`) —
  <https://github.com/wscho77/flutter-tizen/blob/master/doc/configure-device.md>
- moonlight-tizen wiki, *Installation Guide* (registering the IP; reboot by holding power ≥5 s
  until the `Smart TV Powered by Tizen` logo; RTL reverse-IP; `DEVELOP MODE` tag) —
  <https://github.com/brightcraft/moonlight-tizen/wiki/Installation-Guide>
- install-wgt-tizen, *Generic Tizen WGT Installer* (123/on-screen keypad; RTL reverse IP;
  on-screen-keyboard problems on later models) — <https://github.com/gardner/install-wgt-tizen>
- reisxd/tizentube, *Installation Guide* (RTL reverse IP; reboot by holding power) —
  <https://github.com/reisxd/tizentube/blob/main/docs/README.md>
- AeroTizen (check all four octets; power off 60 s; `status` must show `developerMode=1`) —
  <https://github.com/helalaou/aerotizen>
- chris-ritsen/samsung-tv-root, *QUICKSTART* (full reboot; some models need unplug≈1 min; dev
  mode can switch off again) — <https://github.com/chris-ritsen/samsung-tv-root/blob/main/QUICKSTART.md>
- Samsung TV user manuals for the IP-entry convention "number keys type, arrow keys move between
  fields" (older E/F-series platform, same UX family) —
  <https://downloadcenter.samsung.com/content/UM/201201/20120128143940069/UX5DVBAS4A_UX9DVBAS4A-ENG_0106.pdf>
  and <https://downloadcenter.samsung.com/content/UM/201201/20120112151140457/[ENG_US]PX5ATSCA-1020.pdf>
- Live evidence on this unit: REST/port poll 19:44:31–19:53:31 on 2026‑11‑14 (§2/§4 timings) and
  `backup/20261114-194852/{api_v2.json,device_summary.txt,sdb_state.txt}`.
