# Testing: the testdriver vendor file must reach frames and popups

**Date**: 2026-09-30
**Lesson**: A test's own testdriver calls can run in a frame or a popup, which load testdriver.js and testdriver-vendor.js themselves. A vendor file served only to the top-level document leaves those calls on upstream's empty hook.

**Why**: The WPT runner's script loader answered only the parser of the document it navigated to. An iframe's and a `window.open` popup's documents are parsed by the engine (`HTMLIFrameElement.parseHtmlForIframe`). Their `<script src="/resources/testdriver-vendor.js">` was fetched from `wpt serve`, which serves the upstream empty file. Upstream's `test_driver_internal` throws "not implemented" for `minimize_window`. For `click` and `send_keys` it waits for a real user's input, forever.

**What Happened**: pageswap-push-navigation-hidden-document.html calls `test_driver.minimize_window()` from inside the popup it opens. iframe_sandbox_allow_top_navigation_by_user_activation_with_user_gesture.html clicks from inside a cross-origin iframe in a popup. The first design covered only the test document and would have left both blocking. wptrunner does not have this problem: its server rewrites /resources/testdriver.js for every document it serves.

**Fix**: src/html/embedder_scripts.zig is the embedder's answer for frame and popup documents' scripts. It is registered once at startup and asked with the frame's realm. `parseHtmlForIframe` passes `embedder_scripts.forRealm(realm)` as its parser's script loader, which is null when nothing registered, so every other build behaves as before. The runner registers a loader that answers only /resources/testdriver-vendor.js: it defines the natives on that realm first, then returns the vendor file. Crane test crane/td-frame-vendor.html drives an iframe's and a popup's own `test_driver.click`.

**Takeaway**: **Automation hooks must reach every document a test loads, not only the one the runner navigated to; count the tests that call them from a frame or a popup before scoping the hook to the top level.**
