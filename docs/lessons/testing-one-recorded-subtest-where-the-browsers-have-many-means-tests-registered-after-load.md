# Testing: One recorded subtest where the browsers have many means the tests were registered after load

**Date**: 2026-11-20
**Lesson**: When Crane records only the first of a file's subtests (status OK, nothing failing) while the browsers record all of them, the file registers its tests in a callback that Crane runs after the window load event - testharness completed as soon as the first one finished.

**Why**: testharness.js completes once the window has loaded and every registered test is done. Tests registered in a promise callback (`document.fonts.load(...).then(() => { test(...); test(...) })`) all run only if that callback runs before load: then the harness waits for them. If the callback runs after load, the first `test()` finishes, the harness sees all (one) tests done and completes, and every later `test()` is ignored. The cause is whatever should have delayed the load event and did not.

**What Happened**: Lane maj6, css/css-text-decor/parsing/text-decoration-inset-computed.html: generation 234 recorded 1 subtest (PASS), Chrome 157 16/16, Firefox 160 10/16. The file registers its 16 tests in `document.fonts.load("20px Ahem").then(...)`. Gecko's FontFaceSet blocks onload while a font loads and Blink's font fetch is a load-blocking request of the document's fetcher; Crane's FaceLoad fetched the font without delaying the load event, so load fired first.

**Fix**: Find what the callback waits on and make it delay the load event the way the browsers do (here dom.document_lifecycle.delayLoadEvent at the face's first fetch, undelayLoadEvent on every path the load ends by), then check the file records all its subtests.

**Takeaway**: **A file with an OK status and far fewer subtests than the browsers' is a harness that completed early - look for the load-event delay its test registration depended on, not for failing assertions.**
