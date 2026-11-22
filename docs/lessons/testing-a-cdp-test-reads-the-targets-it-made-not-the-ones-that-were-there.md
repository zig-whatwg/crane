# Testing: A CDP test reads the events of the targets it made, not of the ones already there

**Date**: 2026-11-22
**Lesson**: Chrome reports the targets that already exist before it answers Target.setAutoAttach and Target.setDiscoverTargets, so a test that waits for "the next attachedToTarget" or "the next targetCreated" after one of those calls reads the Browser's first page's event, not the target it is about to make.

**Why**: Chrome's TargetHandler attaches (or announces) every existing target synchronously inside the command, before the response (vue-e2e protocol log, Chrome for Testing 157: the startup tab's attachedToTarget, waitingForDebugger false, comes before setAutoAttach's answer). Crane does the same. A Browser always has a first page, and every tab has a TAB target and a PAGE target; Target.getTargets lists them all, the first page and tab targets included. A client that picks "the first page target", or the first event of a kind, picks one of those.

**What Happened**: In lane tpg's CDP test pass, cdpt2's PuppeteerTab and G15, and cdpt's Puppeteer and Playwright launches, timed out or asserted on the wrong session: they took the first page's attachment (not waiting) for the new tab's (waiting), or the first page target's session, which never saw the test's requests (G3 waited for a requestWillBeSent that went to another tab).

**Fix**: After setAutoAttach / setDiscoverTargets, drop the queued events of that kind (`cdp_client.Client.dropQueued`), then wait for the event of the target the test made - by session (`waitEventOn`) or by type ("tab" before its "page" child). From Target.getTargets take the newest page target, the one the test created.

**Takeaway**: **Chrome's target commands report what already exists before they answer; a CDP test filters by the target it made - its id, its session, its type - never by "the next event of this kind".**
