# Spec Compliance: A WPT flip is not a spec update

**Date**: 2026-10-17
**Lesson**: Under golden rule 2, date the spec TEXT a deviation departs from, not the test that asserts it: a decade-old step the browsers never implemented is "no newer spec", even when WPT was flipped to it last month.

**Why**: The refined rule 2 (the user, 2026-10-17) switches Crane to the spec only when the spec was UPDATED and a browser ships it (B) or the browsers merely lag with implementation commitments (C). A recent WPT change looks like that kind of movement - the expected values change, all three browsers start failing - but it can be a test catching up with text the browsers have ignored for years. That is the "browsers simply differ from the spec text" branch, where the browsers decide.

**What Happened**: The gr2audit lane re-audited 108 browser deviations. The first case, CSP reports for WebSocket URLs, had WPT flipped from ws:/wss: to http(s) by wpt PR 58737 (2026-04-02), and all three browsers went to 0/4 on blockeduri-ws-wss-scheme.html. The http(s) conversion itself is whatwg/fetch ce16adc5 from 2016-03-07, unchanged since; no engine filed a bug, Chrome argued on w3c/webappsec-csp#735 (still open) for keeping ws/wss. The integrator classified it "(A*) contested" and Crane keeps ws/wss. The same audit found the reverse trap twice: deviation comments made stale because the SPEC moved to the browsers (whatwg/dom PR #1488 for replace's adoption order; XHR send() gaining URLSearchParams), so the "deviation" was by then the spec.

**Fix**:
1. For each deviation, find the commit that gave the spec text its current form (`gh api 'search/commits?q=repo:whatwg/<spec>+<keywords>'`, or the spec PR the comment cites) and its date.
2. Separately find when WPT changed (`gh api 'repos/web-platform-tests/wpt/commits?path=<file>'`) and why (the PR body names the issue).
3. Only a spec change after the browsers' behaviour was set, with a shipping browser or open implementation bugs, is (B) or (C). An old step plus an open upstream issue is (A*): keep the browsers and re-check when the issue closes.
4. When the spec text now matches what Crane does, delete the deviation comment.

**Takeaway**: **Date the spec change, not the test change - and re-read the current text before trusting an old deviation comment.**
