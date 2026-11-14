# Workflow: A test runner's own debug mode can be the driverless route into Crane

**Date**: 2026-11-14
**Lesson**: Before concluding that a project's browser tests need a driver protocol Crane lacks, look for the runner's own manual or debug mode: it serves the same tests to any browser by URL, and the browser only has to open the page.

**Why**: Most framework runners drive the browser through the Chrome DevTools Protocol or WebDriver BiDi (Playwright, Puppeteer), which Crane does not speak, and the user ruled out harnesses of our own that replace a project's runner (2026-11-14). A runner's manual mode is part of the project, not a replacement for it.

**What Happened**: Angular 22.2.6 runs its 44 framework web test targets with web-test-runner through Puppeteer (Chromium over CDP, Firefox over BiDi). Every target also has the project's own `<target>_debug` (angular/rules_browsers wtr/index.bzl, MANUAL_MODE=1): web-test-runner's manual mode lists the test bundle as a link, and web-test-runner-jasmine prints the whole run on the console in that mode ("N specs, M failures"). A probe on chat2 built //packages/common/http/test:test_web_debug with the project's Bazel (76 s, 2.2 GB) and opened its test page in headless Chrome and in Crane's console: 421 specs, 0 failures in both, no driver involved.

**Fix**: For each runner, read its config for a manual, debug or "open in any browser" mode before writing it off; when it exists, start the project's own target for it (`bazel run <target>_debug -- --port N`) and open the URL its own debug page links. Read the result the mode prints (here the console reporter: failures named, passes counted), and say on the report that passes are counted, not named.

**Takeaway**: **A project's own debug mode that serves its tests to any browser is the project's route, not a harness of ours: check for one before listing a suite as waiting for a driver protocol.**
