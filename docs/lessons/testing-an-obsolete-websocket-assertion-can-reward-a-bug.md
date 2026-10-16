# Testing: An obsolete WebSocket assertion can reward a bug

**Date**: 2026-10-14
**Lesson**: Check the browser runs behind a WPT assertion before treating its loss as a conformance regression.

**Why**: A test may encode obsolete behavior. The WebSockets constructor rejects repeated protocol values, while differently cased strings are distinct. An existing test still expects a SyntaxError for ["echo", "eCho"].

**What Happened**: Crane's ASCII-case-insensitive comparison passed all six variants of Create-protocols-repeated-case-insensitive.any.js. Chrome, Firefox and Safari failed all six. WebKit WebSocket::connect and Blink WebSocketCommon::Connect both use case-sensitive string sets. Correcting Crane therefore turns one worklist file into NONE-PASSED and loses six assertions, while the new case-sensitive regression passes.

**Fix**: Keep the real behavior, leave upstream WPT untouched, and report the intentional blocker and assertion losses explicitly. Preserve aligned run IDs and the raw browser response instead of relying on a products-filtered search: /api/search ignores products=.

Evidence collected 2026-10-14: Chrome 154 run 6218298311311360, Firefox 157 run 4877098740350976, Safari 27 run 5164107446878208. https://wpt.fyi/results/websockets/Create-protocols-repeated-case-insensitive.any.html?run_ids=6218298311311360,4877098740350976,5164107446878208 . Engine source: https://github.com/chromium/chromium/blob/main/third_party/blink/renderer/modules/websockets/websocket_common.cc and https://github.com/WebKit/WebKit/blob/main/Source/WebCore/Modules/websockets/WebSocket.cpp .

**Takeaway**: **A browser-aligned change can lower the WPT score; retain the evidence and report the loss without changing the test or concealing the new blocker.**
