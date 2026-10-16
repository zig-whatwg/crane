# Workflow: Read Gecko from mozilla-firefox/firefox, not the archived gecko-dev

**Date**: 2026-10-15
**Lesson**: github.com/mozilla/gecko-dev has been an archived mirror since July 2025; Gecko evidence read there can be months stale.

**Why**: Golden rule 2 makes browser behaviour the deciding evidence, so a stale engine source silently produces a wrong majority.

**What Happened**: Codex row 39 (ElementInternals ARIA reflection) cited gecko-dev to claim Gecko does not scope-filter internals element references. Current Gecko (mozilla-firefox/firefox dom/html/ElementInternals.cpp, bug 2077803, landed 2026-10-12) does filter, as WebKit does; only Blink does not. The review caught it and the claim was corrected in the code, the Crane test message and the row's lesson.

**Fix**: Read Gecko through https://searchfox.org (mozilla-central) or https://github.com/mozilla-firefox/firefox. When a decision rests on shipped behaviour, say which you used - shipped release (wpt.fyi stable runs) or engine head - since they can differ for weeks.

**Takeaway**: **Cite Gecko from searchfox or mozilla-firefox/firefox, and name whether the evidence is the shipped release or the engine head.**
