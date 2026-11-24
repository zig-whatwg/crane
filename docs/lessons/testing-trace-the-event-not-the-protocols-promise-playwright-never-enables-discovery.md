# Testing: Trace the event, not the protocol's promise - Playwright never enables discovery

**Date**: 2026-11-23
**Lesson**: Before a test pins a CDP event, see that event come from Chrome in a trace of the same steps; a protocol log from a client that never asked for the event says nothing about it.

**Why**: Many CDP events go only to clients that asked for them. Target.targetInfoChanged goes only to a session that called Target.setDiscoverTargets, and Playwright never calls it. Its log carries titles only in attachedToTarget's targetInfo, which agrees with Target.getTargets. A plausible reading of the protocol ("targetInfoChanged: issued when some information about a target has changed"), or of Chromium's observer names (WebContents TitleWasSet), filled the gap.

**What Happened**: Two tests pinned an event Chrome never sends. cdpt2's G15 (tests/devtools/cdpt2_target_lifecycle_test.zig) waited for a targetInfoChanged carrying the document's `<title>`, citing the vue-e2e Playwright log, which has no targetInfoChanged at all. Lane mcp1's batch 1 (mcp1_title_test.zig, b1b62b815) made Crane send one for every title script set. The premise was that Chrome sends one per title. In batch 2, a comparison test run against Chrome for Testing 157 (tests/devtools/mcp1_target_title_test.zig: discovery on, every event recorded from each step to a second after it) showed what Chrome actually does:
- one targetInfoChanged per commit, after Page.frameNavigated, titled with the URL as a titleless page shows it ("127.0.0.1:<port>/path", without http://);
- none for a parsed title, document.title, the title's text node or its removal. Target.getTargets alone shows those.

Crane had sent two events for a parsed title (the first before frameNavigated), two for document.title, and kept http:// in the placeholder.

**Fix**: The comparison test drives either browser through one code path (CRANE_CDP_TRACE_CHROME_PORT), records the events in order, and asserts Chrome's behaviour. It ran red on Crane. Crane then changed to match: a title change updates the target with no event (server.zig), a commit's URL is posted after the sessions' frameNavigated (browser_side.zig), and the placeholder follows GetTitleForDisplay (targets.zig displayUrl). G15 and mcp1_title_test now pin getTargets and the absence of the event.

**Takeaway**: **Pin an event only after seeing it in a Chrome trace of the same steps, with the subscription the test makes. A client log that never subscribed (Playwright never calls setDiscoverTargets) is evidence about the answers it shows, never about events it could not receive.**
