/* ============================================================================
 * HomeKey — the tiny "key app" for the TV's Home button.
 * ----------------------------------------------------------------------------
 * Starts AiTV with a normal tizen.application.launch (which raises a paused
 * launcher, unlike the TV's __NO_RAISE_WINDOW relaunch path), then exits itself
 * after ~160 ms. No UI, no timers that matter, no state.
 *
 * Plain ES5 for Tizen 2.4.
 * ========================================================================== */
(function () {
    "use strict";

    /* Must match launcherAppId in AiTV/js/apps.json and the tizen:application
     * id in AiTV/config.xml. If the TV refuses that id format, see README. */
    var LAUNCHER_APP_ID = "AiTVLaunch.AiTV";
    var EXIT_DELAY_MS = 160;

    var exitScheduled = false;

    function exitSelf() {
        if (exitScheduled) { return; }
        exitScheduled = true;
        try {
            var app = window.tizen && window.tizen.application &&
                window.tizen.application.getCurrentApplication();
            if (app) { app.exit(); }
        } catch (e) {
            /* nothing to do: the TV will reap the app anyway */
        }
    }

    function launchLauncher() {
        if (!(window.tizen && window.tizen.application &&
                typeof window.tizen.application.launch === "function")) {
            return false;
        }
        try {
            window.tizen.application.launch(LAUNCHER_APP_ID,
                function () { /* launcher is coming to the front */ },
                function () { /* it failed; still get out of the way */ });
            return true;
        } catch (e) {
            return false;
        }
    }

    function run() {
        launchLauncher();
        /* The launcher is a foreground app by now; leave the stage. */
        setTimeout(exitSelf, EXIT_DELAY_MS);
        /* Safety net in case something above swallowed the timer. */
        setTimeout(exitSelf, EXIT_DELAY_MS + 600);
    }

    if (document.readyState === "complete") {
        run();
    } else {
        window.addEventListener("load", run, false);
    }
}());
