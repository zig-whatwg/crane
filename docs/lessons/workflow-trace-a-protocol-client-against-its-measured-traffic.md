# Workflow: Trace a protocol client against its measured traffic, not the protocol's schema

**Date**: 2026-11-21

**Lesson**: Before a protocol implementation is first run, walk each real client's RECORDED session through the code message by message - every result field it reads, every event it waits for and their order - because the blockers live in what the client actually sends and what the reference browser actually does, which the schema does not say.

**Why**: CDP part 1 was built from devtools-protocol's JSON and the design's 72 commands and 52 events, and every handler matched the schema. But the punted suites' runners depend on Chrome's behaviour beyond the schema, and a handler written from the schema cannot see that. Lane cdpr's trace walked the recorded traffic (tmp/plans/cdp1-evidence/, Chrome for Testing 157 driven by each runner) through cdp/main's code. It found five blockers and fourteen shape and order differences before any test ran (tmp/plans/cdp-conformance-trace.md).

**What Happened**: Each of these was invisible from the protocol text:
- Vitest's `cdp().send()` sends `"params": null`. The schema says params is an object, so Crane refused it with -32600. Chrome's crdtp takes a null as no params (vue-e2e-browser log, 190 calls).
- Puppeteer attaches to TAB targets. Chrome reports the tab `waitingForDebugger: true` and its page child `false`, and the tab session's runIfWaitingForDebugger releases the page. Crane held the page and told nobody it was waiting, so every `goto` hung.
- Chrome's loaderId IS the navigation request's requestId: the same token in frameNavigated, lifecycleEvent and Network.requestWillBeSent. Crane's Page and Network minted it two ways, so Playwright's `goto` returned a null response.
- Chrome's createBrowserContext is off-the-record and never opens `--user-data-dir`. Crane copied the console's profile directory into it and the profile lock refused it, failing every Playwright `newContext()` over the pipe.
- Plain code reading found the fifth, a list walk whose removal takes two entries (an out-of-bounds read on every disposeBrowserContext). A replay test would have hit it on its first run.

**Fix**:
1. Extract the shapes from the logs: for each command, the union of its params' key paths and of its result's (with JSON types), plus every event's; and a per-session sequence with params wide enough to read (scratch scripts over the `.protocol.log.gz` files).
2. Walk each runner's sequence through the handlers: path (file:function), verdict (ok / gap / wrong), note. Check the CLIENT's code for what it reads (Playwright frames.ts, Puppeteer LifecycleWatcher) - a field Chrome sends but no client reads is a shape note, not a blocker.
3. Report gaps to the integrator in batches, owner by owner, before fixing.
4. Pin each finding with a replay test that sends the runner's commands pipelined, in its order, and checks arrival order and fields (tests/devtools/cdpr_*_replay_test.zig): the first test pass then proves the fixes.

**Takeaway**: **The schema says what a message may hold; the measured traffic says what the client sends and needs. Trace against the recording, and read the client's source for what it actually depends on.**
