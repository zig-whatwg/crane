# Spec Compliance: The browser's own controls are algorithms with userInvolvement "browser UI"

**Date**: 2026-11-05
**Lesson**: The console's `.reload` reached HTML "reload" through the path location.reload() takes, so the page's navigation API heard - and could cancel - the user's reload.

**Why**: HTML threads a user navigation involvement through navigate, reload and traversal. "Browser UI" (the address bar, reload and back buttons) skips what only a document's own navigation does: reload step 1's navigate event, navigate step 5's sourceDocument. A host entry point that calls the script-facing hook loses that argument (docs/lessons/architecture-a-step-reached-through-an-idl-method-loses-what-the-method-does-not-take.md).

**What Happened**: lane loadpath1's console audit. Browser.reloadTraversable called dom.history_traversal.reload(window), whose History implementation said "no navigation here is browser UI" and always fired navigate. Gecko (nsDocShell::Reload -> ReloadNavigable(BrowserUI)), Chromium (browser-initiated reloads reach no navigate dispatch) and WebKit (WebPage::reload -> FrameLoader::reload) all skip it. Popups' console navigations had the same gap (`.none` with no sourceDocument, which navigate step 5 asserts cannot be), fixed by agent 1.

**Fix**: the hook takes the involvement (reloadWithUserInvolvement), History skips step 1 for "browser UI", Browser.reloadTraversable passes it; tests/repl/loadpath1_browser_reload_test.zig pins both sides.

**Takeaway**: **Every browser-UI entry point (navigate, reload, traverse) must carry userInvolvement "browser UI" into the algorithm; a host call that reuses the script's hook silently becomes the script's navigation.**
