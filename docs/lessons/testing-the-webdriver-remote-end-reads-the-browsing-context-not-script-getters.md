# Testing: The WebDriver remote end reads the browsing context, not script's getters

**Date**: 2026-10-12
**Lesson**: The runner's testdriver commands must take a window's document and cookie store from its browsing context, because the IDL getters check the accessor's origin and the raw fields hold only a top-level context's state.

**Why**: `interfaces.Window.get_document` is script's `window.document`: it compares the incumbent (or current) realm's window with the target and throws SecurityError cross-origin. A command's steps run from a timer task, where that realm is not the command's caller, so the getter refused a cross-origin popup's own document. And `BrowsingContext.cookie_jar` is set on top-level contexts only; a frame reaches the Browser's jar through `cookieJar()`, which walks to its top, as `document.cookie` does.

**What Happened**: Codex row 24 (cookies, Q10) saw `frame.contentWindow.test_driver.get_all_cookies()` miss the frame's path cookie, and every cookie command in a cross-origin popup reject "no such window: the window is gone". The suspicion was window selection (nativeSteps / windowOfRealm / startCommand), but that was right: the frame's command found the frame's window, then read `context.cookie_jar` (null for a frame) and answered as if no store existed - [] / "no such cookie" / nothing deleted, so cookie cleanup silently left the frame's cookies behind and contaminated cookies/name, value and size. The popup's command found the popup's window, then `Window.get_document` threw, and the null became "no such window".

**Fix**: In `Command.resolveCookies` (tests/wpt_runner/test_driver.zig), the document is `context.getActiveDocument()` (WebDriver's "current browsing context's active document") and the store is `context.cookieJar()`. A temporary per-step reject message ("no doc", "no bc") located the failing step in one run.

**Takeaway**: **Remote-end code is not script: reach a window's state through its browsing context, never through an IDL getter that checks the accessor, and through the inherited accessor (`cookieJar()`), never the top-level-only field.** `Command.keyDocument` still reads `Window.get_document` and has the same exposure for key actions in a cross-origin popup.
