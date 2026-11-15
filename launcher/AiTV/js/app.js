/* ============================================================================
 * AiTV — launcher runtime
 * ----------------------------------------------------------------------------
 * Target: Samsung Tizen 2.4 TV web engine (2016, Chromium ~47 class).
 * Therefore: plain ES5 (var / function / no arrow / no template literals / no
 * Promise), classic <script>, XMLHttpRequest for the config, and every modern
 * browser API is feature-detected (tizen.application, tizen.tvwindow,
 * visibilitychange, backdrop-filter via CSS @supports).
 * ========================================================================== */
(function () {
    "use strict";

    /* ------------------------------------------------------------------ *
     * Fallback config.
     * js/apps.json is the authoritative, editable configuration. This
     * mirror is only used when the launcher runs from file:// where XHR on
     * local files can be blocked (browser preview). Keep it in sync when
     * you edit apps.json — or simply always preview over http://.
     * ------------------------------------------------------------------ */
    var FALLBACK_CONFIG = {
        settings: {
            wallpaperIntervalSec: 45,
            launcherAppId: "AiTV.Launcher",
            homeKeyAppId: "AiTV.HomeKey",
            allAppsTitle: "Все приложения",
            allAppsTileLabel: "Все",
            allAppsTileIcon: "icons/app/allapps.png"
        },
        wallpapers: [
            { src: "wallpapers/01.jpg" }, { src: "wallpapers/02.jpg" },
            { src: "wallpapers/03.jpg" }, { src: "wallpapers/04.jpg" },
            { src: "wallpapers/05.jpg" }, { src: "wallpapers/06.jpg" }
        ],
        dock: [
            { id: "netflix", label: "Netflix", appId: "11101200001", altAppId: "3201907018807", kind: "app", icon: "icons/app/netflix.png", idStatus: "confirmed" },
            { id: "youtube", label: "YouTube", appId: "111299001912", kind: "app", icon: "icons/app/youtube.png", idStatus: "confirmed" },
            { id: "prime", label: "Prime Video", appId: "3201512006785", altAppId: "3201910019365", kind: "app", icon: "icons/app/prime.png", idStatus: "confirmed" },
            { id: "kinopoisk", label: "Кинопоиск", appId: "111399000037", kind: "app", icon: "icons/app/kinopoisk.png", idStatus: "confirmed" },
            { id: "ivi", label: "IVI", appId: "0000000000000", kind: "app", icon: "icons/app/ivi.png", idStatus: "placeholder" },
            { id: "wink", label: "Wink", appId: "0000000000000", kind: "app", icon: "icons/app/wink.png", idStatus: "placeholder" },
            { id: "okko", label: "Okko", appId: "0000000000000", kind: "app", icon: "icons/app/okko.png", idStatus: "placeholder" }
        ],
        library: [
            { id: "netflix", label: "Netflix", appId: "11101200001", altAppId: "3201907018807", kind: "app", icon: "icons/app/netflix.png", idStatus: "confirmed" },
            { id: "youtube", label: "YouTube", appId: "111299001912", kind: "app", icon: "icons/app/youtube.png", idStatus: "confirmed" },
            { id: "prime", label: "Prime Video", appId: "3201512006785", altAppId: "3201910019365", kind: "app", icon: "icons/app/prime.png", idStatus: "confirmed" },
            { id: "kinopoisk", label: "Кинопоиск", appId: "111399000037", kind: "app", icon: "icons/app/kinopoisk.png", idStatus: "confirmed" },
            { id: "ivi", label: "IVI", appId: "0000000000000", kind: "app", icon: "icons/app/ivi.png", idStatus: "placeholder" },
            { id: "wink", label: "Wink", appId: "0000000000000", kind: "app", icon: "icons/app/wink.png", idStatus: "placeholder" },
            { id: "okko", label: "Okko", appId: "0000000000000", kind: "app", icon: "icons/app/okko.png", idStatus: "placeholder" },
            { id: "browser", label: "Браузер", appId: "org.tizen.browser", altAppId: "3201907018784", kind: "app", icon: "icons/app/browser.png", idStatus: "candidate" },
            { id: "kids", label: "YouTube Kids", appId: "3201611010983", kind: "app", icon: "icons/app/kids.png", idStatus: "confirmed" },
            { id: "twitch", label: "Twitch", appId: "3202203026841", kind: "app", icon: "icons/app/twitch.png", idStatus: "candidate" },
            { id: "spotify", label: "Spotify", appId: "3201606009684", kind: "app", icon: "icons/app/spotify.png", idStatus: "candidate" },
            { id: "smartthings", label: "SmartThings", appId: "3201710015016", altAppId: "3201910019378", kind: "app", icon: "icons/app/smartthings.png", idStatus: "candidate" },
            { id: "hdmi", label: "HDMI", appId: "", kind: "input", input: "HDMI1", icon: "icons/app/hdmi.png", idStatus: "confirmed" }
        ]
    };

    var CONFIG = null;
    var settings = {};
    var dockItems = [];
    var libraryItems = [];
    var dockTiles = [];
    var gridTiles = [];
    var el = {};
    var wallpaperList = [];
    var toastTimer = null;
    var clockTimer = null;
    var lastClockText = "";
    var lastDateText = "";

    var state = {
        mode: "dock",       /* "dock" | "grid" */
        dockIndex: 0,
        gridIndex: 0,
        gridCols: 7,
        booted: false
    };

    var wp = {
        layers: [],
        active: 0,
        index: 0,
        lastRotateAt: 0,
        timer: null,
        preload: null
    };

    var WEEKDAYS = ["воскресенье", "понедельник", "вторник", "среда",
        "четверг", "пятница", "суббота"];
    var MONTHS = ["января", "февраля", "марта", "апреля", "мая", "июня",
        "июля", "августа", "сентября", "октября", "ноября", "декабря"];

    /* ------------------------------------------------------------ helpers */
    function byId(id) {
        return document.getElementById(id);
    }

    function hasClass(node, name) {
        return (" " + (node.className || "") + " ").indexOf(" " + name + " ") > -1;
    }

    function addClass(node, name) {
        if (!node || hasClass(node, name)) { return; }
        node.className = node.className ? node.className + " " + name : name;
    }

    function removeClass(node, name) {
        if (!node) { return; }
        var parts = (node.className || "").split(/\s+/);
        var out = [];
        for (var i = 0; i < parts.length; i++) {
            if (parts[i] && parts[i] !== name) { out.push(parts[i]); }
        }
        node.className = out.join(" ");
    }

    function mod(n, m) {
        return ((n % m) + m) % m;
    }

    function pad2(n) {
        return n < 10 ? "0" + n : "" + n;
    }

    function now() {
        return new Date().getTime();
    }

    function hasTizen() {
        return !!(window.tizen && window.tizen.application);
    }

    /* --------------------------------------------------------------- clock */
    function updateClock() {
        var d = new Date();
        var hhmm = pad2(d.getHours()) + ":" + pad2(d.getMinutes());
        if (hhmm !== lastClockText) {
            lastClockText = hhmm;
            if (el.clock) { el.clock.textContent = hhmm; }
        }
        var dateText = WEEKDAYS[d.getDay()] + ", " + d.getDate() + " " + MONTHS[d.getMonth()];
        if (dateText !== lastDateText) {
            lastDateText = dateText;
            if (el.date) { el.date.textContent = dateText; }
        }
    }

    /* --------------------------------------------------------------- toast */
    function toast(text, duration) {
        if (!el.toast || !text) { return; }
        el.toast.textContent = text;
        addClass(el.toast, "show");
        if (toastTimer) { clearTimeout(toastTimer); }
        toastTimer = setTimeout(function () {
            removeClass(el.toast, "show");
            toastTimer = null;
        }, duration || 2800);
    }

    /* -------------------------------------------------------------- config */
    function loadConfig(cb) {
        var finished = false;

        /* On a Tizen 2.4 TV the app runs from file://, where XHR to a local
         * file is blocked: /js/config.js ships the same JSON as an embedded
         * object, so the TV never depends on the request below. */
        if (window.AITV_CONFIG) { cb(window.AITV_CONFIG); return; }

        function done(cfg) {
            if (finished) { return; }
            finished = true;
            cb(cfg || FALLBACK_CONFIG);
        }

        try {
            var xhr = new XMLHttpRequest();
            xhr.open("GET", "js/apps.json", true);
            xhr.onreadystatechange = function () {
                if (xhr.readyState !== 4) { return; }
                if (xhr.status >= 200 && xhr.status < 300) {
                    try {
                        done(JSON.parse(xhr.responseText));
                        return;
                    } catch (e) {
                        /* fall through to the mirror */
                    }
                }
                done(FALLBACK_CONFIG);
            };
            xhr.onerror = function () { done(FALLBACK_CONFIG); };
            xhr.send();
            /* safety timer: never leave the TV on a black screen if the config
             * request hangs (observed once on a slow USB-mounted web app). */
            setTimeout(function () { done(FALLBACK_CONFIG); }, 6000);
        } catch (e) {
            done(FALLBACK_CONFIG);
        }
    }

    /* ------------------------------------------------------------------ UI */
    var TRANSPARENT_PX = "data:image/gif;base64,R0lGODlhAQABAIAAAAAAAP///yH5BAEAAAAALAAAAAABAAEAAAIBRAA7";

    function buildTile(entry, kind, lazy) {
        var tile = document.createElement("div");
        tile.className = "tile";

        var icon = document.createElement("div");
        icon.className = "tile-icon";

        var img = document.createElement("img");
        var src = entry.icon || "icons/app/allapps.png";
        if (lazy) {
            /* grid tiles: decode only when the overlay is opened (cold start
             * stays light on the 2016 SoC) */
            img.setAttribute("data-src", src);
            img.src = TRANSPARENT_PX;
        } else {
            img.src = src;
        }
        img.alt = "";
        img.setAttribute("draggable", "false");
        icon.appendChild(img);

        var label = document.createElement("div");
        label.className = "tile-label";
        label.textContent = entry.label || "";

        tile.appendChild(icon);
        tile.appendChild(label);
        tile.setAttribute("data-app-id", entry.id || "");

        /* TV has no pointer, but clicks keep the browser preview honest. */
        tile.onclick = function () {
            if (kind === "dock") {
                focusDock(tile.getAttribute("data-index") - 0);
            } else {
                focusGrid(tile.getAttribute("data-index") - 0);
            }
            activate();
        };
        return tile;
    }

    function buildDock() {
        el.dock.innerHTML = "";
        dockTiles = [];
        var i;
        for (i = 0; i < dockItems.length; i++) {
            var tile = buildTile(dockItems[i], "dock");
            tile.setAttribute("data-index", i);
            el.dock.appendChild(tile);
            dockTiles.push(tile);
        }

        var allApps = {
            id: "__allapps",
            label: settings.allAppsTileLabel || "Все",
            kind: "allapps",
            icon: settings.allAppsTileIcon || "icons/app/allapps.png"
        };
        var allTile = buildTile(allApps, "dock");
        allTile.setAttribute("data-index", i);
        el.dock.appendChild(allTile);
        dockTiles.push(allTile);
        dockItems.push(allApps);
    }

    function buildGrid() {
        el.grid.innerHTML = "";
        gridTiles = [];
        for (var i = 0; i < libraryItems.length; i++) {
            var tile = buildTile(libraryItems[i], "grid", true);
            tile.setAttribute("data-index", i);
            el.grid.appendChild(tile);
            gridTiles.push(tile);
        }
    }

    /* Measure how many tiles the CSS actually puts on one row. */
    function detectGridCols() {
        if (!gridTiles.length) { return 7; }
        var firstTop = gridTiles[0].offsetTop;
        var cols = 0;
        for (var i = 0; i < gridTiles.length; i++) {
            if (gridTiles[i].offsetTop !== firstTop) { break; }
            cols++;
        }
        return cols > 0 ? cols : 7;
    }

    function setFocus(tiles, index, container) {
        if (container) { addClass(container, "has-focus"); }
        for (var i = 0; i < tiles.length; i++) {
            if (i === index) {
                addClass(tiles[i], "focused");
            } else {
                removeClass(tiles[i], "focused");
            }
        }
    }

    function focusDock(index) {
        if (!dockTiles.length) { return; }
        state.dockIndex = mod(index, dockTiles.length);
        setFocus(dockTiles, state.dockIndex, el.dock);
    }

    function focusGrid(index) {
        if (!gridTiles.length) { return; }
        state.gridIndex = mod(index, gridTiles.length);
        setFocus(gridTiles, state.gridIndex, el.grid);
    }

    function rowLength(row) {
        var remaining = libraryItems.length - row * state.gridCols;
        return Math.max(1, Math.min(state.gridCols, remaining));
    }

    function gridRows() {
        return Math.max(1, Math.ceil(libraryItems.length / state.gridCols));
    }

    /* ------------------------------------------------------------ movement */
    function moveHorizontal(dx) {
        if (state.mode === "dock") {
            focusDock(state.dockIndex + dx);
            return;
        }
        var row = Math.floor(state.gridIndex / state.gridCols);
        var col = state.gridIndex % state.gridCols;
        var len = rowLength(row);
        col = mod(col + dx, len);
        focusGrid(row * state.gridCols + col);
    }

    function moveVertical(dy) {
        if (state.mode === "dock") {
            /* UP from the dock opens the full app grid; DOWN stays put. */
            if (dy < 0) { openOverlay(); }
            return;
        }
        var rows = gridRows();
        var row = Math.floor(state.gridIndex / state.gridCols);
        var col = state.gridIndex % state.gridCols;
        var newRow = mod(row + dy, rows);
        var len = rowLength(newRow);
        if (col > len - 1) { col = len - 1; }
        focusGrid(newRow * state.gridCols + col);
    }

    /* -------------------------------------------------------------- overlay */
    function loadGridIcons() {
        if (state.iconsLoaded) { return; }
        state.iconsLoaded = true;
        for (var i = 0; i < gridTiles.length; i++) {
            var img = gridTiles[i].getElementsByTagName("img")[0];
            if (!img) { continue; }
            var src = img.getAttribute("data-src");
            if (src) { img.src = src; }
        }
    }

    function openOverlay() {
        loadGridIcons();
        state.mode = "grid";
        addClass(el.overlay, "open");
        el.overlay.setAttribute("aria-hidden", "false");
        addClass(document.body, "overlay-open");
        removeClass(document.body, "dock-focused");
        focusGrid(state.gridIndex);
    }

    function closeOverlay() {
        state.mode = "dock";
        removeClass(el.overlay, "open");
        el.overlay.setAttribute("aria-hidden", "true");
        removeClass(document.body, "overlay-open");
        addClass(document.body, "dock-focused");
        focusDock(state.dockIndex);
    }

    function handleBack() {
        if (state.mode === "grid") {
            closeOverlay();
        }
        /* From the dock Back is a harmless no-op: the TV's Home button and
         * the HomeKey companion app are what bring you here. */
    }

    /* ------------------------------------------------------------- launching */
    function pressTile(tile) {
        if (!tile) { return; }
        addClass(tile, "pressed");
        setTimeout(function () { removeClass(tile, "pressed"); }, 260);
    }

    function activate() {
        if (state.mode === "dock") {
            var entry = dockItems[state.dockIndex];
            if (!entry) { return; }
            if (entry.kind === "allapps") {
                openOverlay();
                return;
            }
            pressTile(dockTiles[state.dockIndex]);
            launchEntry(entry);
            return;
        }
        var app = libraryItems[state.gridIndex];
        if (!app) { return; }
        pressTile(gridTiles[state.gridIndex]);
        launchEntry(app);
    }

    /* Spec v3.2: after handing over to a player, quit this web app so the TV
     * has the whole memory for the player (Wink starts noticeably faster with
     * no background launcher on this 2016 set). Returning afterwards is manual:
     * Home -> Smart Hub -> APPS -> AiTV. The feature is optional and disabled by
     * default (no "heavy" flags in apps.json), because without an external
     * relauncher a heavy player leaves the TV on a black screen when it exits. */
    var exitWhenBlurred = false;

    function doSelfExit() {
        if (hasFocus) { return; } /* the user already came back */
        exitWhenBlurred = false;
        try {
            var app = tizen.application.getCurrentApplication();
            if (app && typeof app.exit === "function") { app.exit(); }
        } catch (e) { /* method missing on some 2.4 builds */ }
    }

    function releaseForPlayer() {
        /* The blur that follows a launch does not arrive with a fixed delay on
         * this set, so handle both orders: fire on blur if it comes first, and
         * keep a fallback timer for the case blur already happened. */
        exitWhenBlurred = true;
        setTimeout(function () {
            if (!hasFocus) { doSelfExit(); }
            /* otherwise onLauncherBlur will do it as soon as we go background */
        }, 2000);
    }

    function launchTizenApp(entry, allowAlt) {
        var primary = entry;
        var settled = false;
        function ok() {
            settled = true;
            if (primary.heavy) { releaseForPlayer(); }
        }
        function fail() {
            if (settled) { return; }
            settled = true;
            stopWatch();
            if (allowAlt && entry.altAppId && entry.altAppId !== entry.appId) {
                launchTizenApp({ appId: entry.altAppId, label: entry.label }, false);
                return;
            }
            toast("Не удалось открыть «" + entry.label + "» — приложение не найдено на телевизоре");
        }
        try {
            window.tizen.application.launch(entry.appId, ok, fail);
        } catch (e) {
            fail();
        }
    }

    function showInput(entry) {
        var label = entry.label || "HDMI";
        try {
            if (hasTizen() && window.tizen.tvwindow &&
                    typeof window.tizen.tvwindow.show === "function") {
                window.tizen.tvwindow.show(
                    function () { /* TV window is showing */ },
                    function () { toast("HDMI-вход: " + label + " недоступен"); }
                );
                return;
            }
        } catch (e) {
            /* fall through to the toast */
        }
        toast("HDMI-вход — " + label + " (tizen.tvwindow недоступен на этом ТВ)");
    }

    function openUrl(entry) {
        try {
            if (hasTizen() && window.tizen.application.launchAppControl &&
                    window.tizen.ApplicationControl) {
                var ctrl = new window.tizen.ApplicationControl(
                    "http://tizen.org/appcontrol/operation/view",
                    entry.url, null, null, null
                );
                window.tizen.application.launchAppControl(ctrl, entry.appId || null,
                    function () { },
                    function () { toast("Не удалось открыть ссылку"); },
                    null);
                return;
            }
            if (entry.appId) {
                launchTizenApp(entry, false);
                return;
            }
        } catch (e) { /* fall through */ }
        toast("Не удалось открыть ссылку");
    }

    function launchEntry(entry) {
        if (!entry) { return; }
        /* Spec I6: the Smart Hub tile cannot launch a native system app from a
         * public-level web app (SecurityError). It pauses the Home reclaim for
         * three minutes and shows the instruction panel instead. */
        if (entry.kind === "samsunghome") {
            /* Launching a native system app is allowed once the manifest asks for
             * appmanager.launch (verified on this TV: tizen.application.launch
             * ("org.tizen.menu") opens Samsung Smart Hub). */
            if (!hasTizen()) {
                toast("Smart Hub откроется на телевизоре");
                return;
            }
            /* Launch from a timer, not from inside the key handler: calling
             * launch() for a native app synchronously from a keydown wedges the
             * web runtime on this set (verified), a deferred call works. */
            setTimeout(function () {
                try {
                    tizen.application.launch("org.tizen.menu",
                        function () {},
                        function () {
                            try {
                                tizen.application.launch("org.volt.apps", function () {}, function () {
                                    toast("Не удалось открыть Smart Hub");
                                });
                            } catch (e) { toast("Не удалось открыть Smart Hub"); }
                        });
                } catch (e) {
                    toast("Не удалось открыть Smart Hub");
                }
            }, 350);
            return;
        }
        if (entry.kind === "input") { showInput(entry); return; }
        if (entry.kind === "url") { openUrl(entry); return; }

        if (!hasTizen()) {
            toast("Предпросмотр в браузере: «" + entry.label + "» откроется на телевизоре");
            return;
        }
        if (!entry.appId || entry.idStatus === "placeholder") {
            toast("«" + entry.label + "»: ID приложения не настроен. Впиши appId в js/apps.json");
            return;
        }
        /* Spec I1/I4/I5: remember the launch so the blur that follows is not
         * mistaken for the Home key, and watch that app from now on. */
        launchedAt = now();
        launchTizenApp(entry, true);
    }


    /* --------------------------------------------------- Samsung panel --- */
    function showSamsungPanel() {
        var p = byId("samsungPanel");
        if (!p) {
            p = document.createElement("div");
            p.id = "samsungPanel";
            p.className = "samsung-panel";
            p.innerHTML = '<div class="samsung-panel-inner">' +
                '<div class="samsung-panel-title">Samsung Smart Hub</div>' +
                '<div class="samsung-panel-text">Нажмите кнопку <b>Home</b> на пульте — откроется Samsung Smart Hub.' +
                '<br>Возврат в AiTV — сам через 3 минуты (или кнопка Back).</div>' +
                '<div class="samsung-panel-hint">OK / любая кнопка — закрыть подсказку</div></div>';
            document.body.appendChild(p);
        }
        addClass(p, "open");
        if (samsungPanelTimer) { clearTimeout(samsungPanelTimer); }
        samsungPanelTimer = setTimeout(hideSamsungPanel, 9000);
    }

    function hideSamsungPanel() {
        var p = byId("samsungPanel");
        if (!p) { return; }
        removeClass(p, "open");
        if (samsungPanelTimer) { clearTimeout(samsungPanelTimer); samsungPanelTimer = null; }
    }

    /* ------------------------------------------------------------ wallpapers */
    function srcOf(item) {
        if (!item) { return ""; }
        return typeof item === "string" ? item : (item.src || "");
    }

    function setLayerBackground(layer, src) {
        if (layer && src) {
            layer.style.backgroundImage = 'url("' + src + '")';
        }
    }

    function restartKenBurns(layer) {
        removeClass(layer, "kb");
        /* read a layout property to force a reflow so the animation restarts */
        if (layer.offsetWidth === -1) { return; }
        addClass(layer, "kb");
    }

    function preloadWallpaper(index) {
        if (!wallpaperList.length) { return; }
        var src = srcOf(wallpaperList[mod(index, wallpaperList.length)]);
        if (!src) { return; }
        try {
            var img = new Image();
            img.src = src;
            wp.preload = img; /* keep a reference so the engine keeps it hot */
        } catch (e) { /* ignore */ }
    }

    function initWallpapers() {
        wp.layers = [el.wpLayerA, el.wpLayerB];
        wp.active = 0;
        wp.index = 0;
        if (!wallpaperList.length) {
            addClass(document.body, "no-wallpaper");
            return;
        }
        setLayerBackground(wp.layers[0], srcOf(wallpaperList[0]));
        restartKenBurns(wp.layers[0]);
        wp.layers[0].style.opacity = "1";
        wp.lastRotateAt = now();
        setTimeout(function () { preloadWallpaper(1); }, 1500);

        var interval = parseInt(settings.wallpaperIntervalSec, 10);
        if (!interval || interval < 15) { interval = 45; }
        wp.timer = setInterval(function () { rotateWallpaper(false); }, interval * 1000);
    }

    function rotateWallpaper(onReturn) {
        if (wallpaperList.length < 2) { return; }
        var next = mod(wp.index + 1, wallpaperList.length);
        var incoming = wp.layers[1 - wp.active];
        var outgoing = wp.layers[wp.active];

        setLayerBackground(incoming, srcOf(wallpaperList[next]));
        restartKenBurns(incoming);
        incoming.style.opacity = "1";
        outgoing.style.opacity = "0";

        wp.active = 1 - wp.active;
        wp.index = next;
        wp.lastRotateAt = now();
        preloadWallpaper(next + 1);
        if (onReturn) { /* nothing extra: the cross-fade already signals it */ }
    }

    function onAppReturn() {
        /* Return from an app must be instant: refresh the clock and show the
         * frame that is already decoded. Do NOT decode/rotate a wallpaper here
         * (a 1280x720 decode + 1.6 s cross-fade on the 2016 SoC is exactly the
         * "launcher comes back slowly" the owner sees). */
        updateClock();
        showCurrentFrame();
    }

    function showCurrentFrame() {
        if (!wp.layers || !wp.layers.length) { return; }
        for (var i = 0; i < wp.layers.length; i++) {
            wp.layers[i].style.opacity = (i === wp.active) ? "1" : "0";
        }
    }

    /* ------------------------------------------------------- sleep / wake --- */
    /* This TV kills a background web app when a heavy player (Wink) starts, so
     * on blur the launcher gives its memory back: decoded wallpapers and the
     * lazily loaded library icons are the big allocations (~2 MB per 960x540
     * frame decoded, ~120 KB per icon). A lighter background app has a real
     * chance of surviving until the user presses Back. */
    function releaseBackgroundMemory() {
        try {
            if (wp.layers) {
                for (var i = 0; i < wp.layers.length; i++) {
                    wp.layers[i].style.backgroundImage = "none";
                }
            }
            wp.preload = null;
            if (wp.timer) { clearInterval(wp.timer); wp.timer = null; }
            if (state.iconsLoaded) {
                for (var j = 0; j < gridTiles.length; j++) {
                    var img = gridTiles[j].getElementsByTagName("img")[0];
                    if (img && img.getAttribute("data-src")) { img.removeAttribute("src"); }
                }
                state.iconsLoaded = false;
            }
            addClass(document.body, "asleep");
        } catch (e) { /* never break the launcher */ }
    }

    function restoreAfterSleep() {
        try {
            removeClass(document.body, "asleep");
            if (wp.layers && wallpaperList.length) {
                setLayerBackground(wp.layers[wp.active], srcOf(wallpaperList[wp.index]));
                wp.layers[wp.active].style.opacity = "1";
                restartKenBurns(wp.layers[wp.active]);
            }
            var interval = parseInt(settings.wallpaperIntervalSec, 10);
            if (!interval || interval < 15) { interval = 45; }
            if (!wp.timer && wallpaperList.length > 1) {
                wp.timer = setInterval(function () { rotateWallpaper(false); }, interval * 1000);
            }
        } catch (e) { /* ignore */ }
    }


    /* ------------------------------------------------ Home-button reclaim --- */
    /* Tizen never hands the Home key to a third-party app, and vconf is closed
     * on this 2.4 set. But the page keeps running in the background
     * (background-support="enable"), the web runtime has focus/blur events and
     * tizen.application.launchAppControl supports Samsung's "eden_resume"
     * operation (verified on this TV). So: when the launcher loses focus
     * without us launching an app, that was the Home key — bring ourselves
     * back a moment later. Exiting an app we launched is handled by the TV
     * returning to us anyway; the watch below also catches Home pressed while
     * inside that app. */
    var APP_ID = "AiTVLaunch.AiTV";
    var HOME_SUPPRESS_MS = 180000;
    var homeSuppressUntil = 0;
    var samsungPanelTimer = null;
    var homeReturnTimer = null;
    var hasFocus = true;
    var launchedApp = null;
    var launchedAt = 0;
    var watchTimer = null;
    var watchMisses = 0;
    var watchStartedAt = 0;
    var watchSeenVisible = false;

    function bringBack() {
        try {
            var ac = new tizen.ApplicationControl("http://samsung.com/appcontrol/operation/eden_resume");
            tizen.application.launchAppControl(ac, APP_ID, function () {}, function () {
                try { tizen.application.launch(APP_ID); } catch (e) {}
            });
        } catch (e) {
            try { tizen.application.launch(APP_ID); } catch (e2) {}
        }
    }

    function cancelHomeReturn() {
        if (homeReturnTimer) { clearTimeout(homeReturnTimer); homeReturnTimer = null; }
    }

    function stopWatch() {
        if (watchTimer) { clearInterval(watchTimer); watchTimer = null; }
        watchMisses = 0;
        watchSeenVisible = false;
        launchedApp = null;
    }

    /* Poll the TV's own status service (answers tokenless to the TV itself):
     * when the app we opened stops being visible, either it was exited (the TV
     * brings us back anyway) or Home was pressed inside it — resume ourselves,
     * guarded by the focus flag so a normal return is untouched. */
    function startWatch(appId) {
        stopWatch();
        if (!appId) { return; }
        launchedApp = appId;
        watchMisses = 0;
        watchSeenVisible = false;
        watchStartedAt = now();
        watchTimer = setInterval(function () {
            if (!launchedApp) { return; }
            if (now() < homeSuppressUntil) { stopWatch(); return; }
            if (now() - watchStartedAt > 180000) { stopWatch(); return; }
            if (hasFocus) { stopWatch(); return; }
            var xhr;
            try { xhr = new XMLHttpRequest(); } catch (e) { stopWatch(); return; }
            xhr.onreadystatechange = function () {
                if (xhr.readyState !== 4) { return; }
                /* Spec I5 (v1.1): a fresh app can take many seconds to become
                 * visible on this 2016 SoC, so nothing counts during the first
                 * 8 s; a miss only counts after we have once seen the app
                 * visible; and a response that is not exactly HTTP 200 with a
                 * boolean field is "unknown" and never triggers a return. */
                if (now() - watchStartedAt < 8000) { return; }
                if (xhr.status !== 200) { return; }
                var data;
                try { data = JSON.parse(xhr.responseText); } catch (e) { return; }
                if (!data || typeof data.visible !== "boolean") { return; }
                if (data.visible === true) { watchSeenVisible = true; watchMisses = 0; return; }
                if (!watchSeenVisible) { return; }
                watchMisses++;
                if (watchMisses >= 3 && !hasFocus) { stopWatch(); bringBack(); }
            };
            try {
                xhr.open("GET", "http://127.0.0.1:8001/api/v2/applications/" + launchedApp, true);
                xhr.send();
            } catch (e) { stopWatch(); }
        }, 2000);
    }

    function onLauncherBlur() {
        /* Spec v3.1: no Home reclaim (Home stays Samsung's). Going to the
         * background, give the decoded images back so the TV keeps us alive
         * while a heavy player is running. */
        hasFocus = false;
        if (exitWhenBlurred) {
            exitWhenBlurred = false;
            setTimeout(doSelfExit, 1200);
        }
    }

    function onLauncherFocus() {
        hasFocus = true;
        exitWhenBlurred = false;
        cancelHomeReturn();
        stopWatch();
    }

    /* ---------------------------------------------------------- resume --- */
    /* Returning from an app (e.g. Back in Kinopoisk) must show the launcher at
     * once, never a stale/black frame: on every visibility/focus/pageshow we
     * repaint the scene, refresh the clock and drop the boot veil if it is
     * still up. Tizen 2.4 only fires these sometimes, so they are best effort
     * on top of the light assets (decoding a 1280x720 frame is fast). */
    function forceRepaint() {
        try {
            if (el.clock) { updateClock(); }
            if (document.body && el.dock && document.body.offsetWidth === -1) { /* reflow */ }
            if (state.mode === "grid") { closeOverlay(); }
            removeClass(document.documentElement, "prelayout");
            removeClass(document.body, "booting");
            addClass(document.body, "ready");
            addClass(document.body, "revealed");
            showCurrentFrame();
            var layer = wp.layers && wp.layers[wp.active];
            if (layer) {
                addClass(layer, "kb");
                if (layer.offsetWidth === -1) { return; }
            }
        } catch (e) { /* never let a repaint break the launcher */ }
    }

    function bindResume() {
        window.addEventListener("blur", onLauncherBlur, false);
        window.addEventListener("focus", onLauncherFocus, false);
        document.addEventListener("visibilitychange", function () {
            if (document.visibilityState !== "hidden") { forceRepaint(); }
        }, false);
        window.addEventListener("focus", forceRepaint, false);
        window.addEventListener("pageshow", forceRepaint, false);
        window.addEventListener("orientationchange", forceRepaint, false);
        /* Tizen app status: resume/foreground notifications where supported */
        try {
            if (window.tizen && tizen.application && tizen.application.getCurrentApplication) {
                var app = tizen.application.getCurrentApplication();
                if (app && typeof app.addAppStatusChangeListener === "function") {
                    app.addAppStatusChangeListener(function (st) {
                        if (st === "APP_STATUS_RUNNING" || st === "APP_STATUS_RESUMED") {
                            forceRepaint();
                        }
                    }, function () {});
                }
            }
        } catch (e) { /* optional API on 2.4 */ }
    }

    /* ---------------------------------------------------------------- keys */
    function onKeyDown(ev) {
        var code = ev.keyCode || ev.which || 0;
        hideSamsungPanel();
        var handled = true;

        switch (code) {
        case 37: /* LEFT  */
            moveHorizontal(-1);
            break;
        case 39: /* RIGHT */
            moveHorizontal(1);
            break;
        case 38: /* UP    */
            moveVertical(-1);
            break;
        case 40: /* DOWN  */
            moveVertical(1);
            break;
        case 13: /* ENTER / OK */
            activate();
            break;
        case 10009: /* Tizen RETURN */
        case 461:   /* Tizen BACK alternate */
        case 27:    /* ESC */
        case 8:     /* BACKSPACE, some remotes/preview */
            handleBack();
            break;
        default:
            handled = false;
        }

        if (!handled) { return true; }
        if (ev.preventDefault) { ev.preventDefault(); }
        if (ev.stopPropagation) { ev.stopPropagation(); }
        ev.returnValue = false;
        return false;
    }

    /* ---------------------------------------------------------------- boot */
    function bindElements() {
        el.clock = byId("clock");
        el.date = byId("date");
        el.hint = byId("hint");
        el.dock = byId("dock");
        el.grid = byId("grid");
        el.overlay = byId("overlay");
        el.overlayTitle = byId("overlayTitle");
        el.overlayHint = byId("overlayHint");
        el.toast = byId("toast");
        el.wpLayerA = byId("wpLayerA");
        el.wpLayerB = byId("wpLayerB");
    }

    function start(cfg) {
        CONFIG = cfg;
        settings = cfg.settings || {};
        wallpaperList = cfg.wallpapers || [];
        dockItems = (cfg.dock || []).slice(0);
        libraryItems = (cfg.library || []).slice(0);

        if (el.overlayTitle && settings.allAppsTitle) {
            el.overlayTitle.textContent = settings.allAppsTitle;
        }

        buildDock();
        buildGrid();
        state.gridCols = detectGridCols();

        initWallpapers();
        focusDock(0);
        addClass(document.body, "dock-focused");
        state.booted = true;
        bindResume();
        previewHooks();

        /* Reveal in two steps: first hand transitions back to the browser
         * (the UI is already in its settled state), then fade the boot veil
         * out. Without the first step the focused tile would animate its ring
         * in from nothing on every cold start. */
        setTimeout(function () {
            removeClass(document.documentElement, "prelayout");
            if (document.body.offsetWidth === -1) { return; } /* reflow */
            setTimeout(function () {
                removeClass(document.body, "booting");
                addClass(document.body, "ready");
                addClass(document.body, "revealed");
            }, 60);
        }, 90);
    }

    /* Preview / QA hooks on a TV set-top: ?focus=3, ?allapps=1, ?toast=text
     * They are inert unless the page is opened with a query string, which the
     * installed TV app never is. */
    function dispatchKey(code) {
        var ev;
        try {
            ev = document.createEvent("Event");
            ev.initEvent("keydown", true, true);
        } catch (e) {
            ev = document.createEventObject ? document.createEventObject() : null;
            if (!ev) { return; }
        }
        try {
            Object.defineProperty(ev, "keyCode", { get: function () { return code; } });
            Object.defineProperty(ev, "which", { get: function () { return code; } });
        } catch (e) {
            ev.keyCode = code;
            ev.which = code;
        }
        document.dispatchEvent(ev);
    }

    /* ?keys=39,39,13 — replay a remote-control sequence, then publish the
     * resulting navigation state into document.title for smoke tests. */
    function replayKeys(spec) {
        var codes = [];
        var parts = spec.split(",");
        for (var i = 0; i < parts.length; i++) {
            var n = parseInt(parts[i], 10);
            if (!isNaN(n)) { codes.push(n); }
        }
        var step = 0;
        function next() {
            if (step >= codes.length) {
                setTimeout(function () {
                    var scope = state.mode === "grid" ? ".grid" : ".dock";
                    var focused = document.querySelector(scope + " .tile.focused .tile-label");
                    document.title = "QA|mode=" + state.mode +
                        "|dock=" + state.dockIndex +
                        "|grid=" + state.gridIndex +
                        "|cols=" + state.gridCols +
                        "|focus=" + (focused ? focused.textContent : "-") +
                        "|toast=" + (el.toast ? el.toast.textContent : "");
                }, 260);
                return;
            }
            dispatchKey(codes[step]);
            step++;
            setTimeout(next, 140);
        }
        setTimeout(next, 200);
    }

    function previewHooks() {
        var q = "";
        try { q = window.location.search || ""; } catch (e) { q = ""; }
        if (!q) { return; }
        var keys = /[?&]keys=([0-9,]+)/.exec(q);
        if (keys) { replayKeys(keys[1]); }
        var focus = /[?&]focus=(\d+)/.exec(q);
        if (focus) { focusDock(parseInt(focus[1], 10)); }
        if (/[?&]allapps=1/.test(q)) { openOverlay(); }
        var msg = /[?&]toast=([^&]+)/.exec(q);
        if (msg) {
            try { toast(decodeURIComponent(msg[1]).replace(/\+/g, " ")); }
            catch (e) { toast(msg[1]); }
        }
    }

    /* QA switch: ?instant=1 pins every transition/animation at its end state.
     * Handy for deterministic headless screenshots; never present on the TV. */
    function parseInstantMode() {
        try {
            if (/[?&]instant=1/.test(window.location.search || "")) {
                addClass(document.documentElement, "instant-mode");
            }
        } catch (e) { /* ignore */ }
    }

    function boot() {
        bindElements();
        parseInstantMode();
        document.addEventListener("keydown", onKeyDown, true);
        updateClock();
        clockTimer = setInterval(updateClock, 1000);

        if ("hidden" in document) {
            document.addEventListener("visibilitychange", function () {
                if (!document.hidden) { onAppReturn(); }
            }, false);
        }
        window.addEventListener("focus", function () { onAppReturn(); }, false);

        loadConfig(function (cfg) {
            try {
                start(cfg);
            } catch (e) {
                /* Last-resort safety: show something rather than a black TV. */
                addClass(document.body, "no-wallpaper");
                removeClass(document.body, "booting");
                addClass(document.body, "ready");
                toast("Ошибка запуска AiTV: " + (e && e.message ? e.message : e), 8000);
            }
        });
    }

    if (document.readyState === "loading") {
        document.addEventListener("DOMContentLoaded", boot, false);
    } else {
        boot();
    }
}());
