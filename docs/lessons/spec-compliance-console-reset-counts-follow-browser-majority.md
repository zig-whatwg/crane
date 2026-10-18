# Spec Compliance: Repeated Console Resets Follow the Browser Majority

**Date**: 2026-10-18
**Lesson**: A passing test that counts between resets cannot establish what a second consecutive reset does.

**Why**: Console 1.2.2 says to retain an existing counter with value zero. Chrome and Firefox instead remove it; Safari retains it. Both algorithms make the next count produce one, but only removal makes a second reset issue the missing-counter warning.

**What Happened**: Row 71 initially identified Crane's removal as a spec defect. The current upstream `console-countReset-logging.html` counts between resets, so its assertions do not distinguish the algorithms. Its aligned browser results were Chrome 1/1, Firefox 0/1 and Safari harness error; those results do not establish repeated-reset behavior either. Reading the engines before implementation caught the split. The liaison withdrew the proposed change. The spec's zero-setting step dates to its [2018 introduction](https://github.com/whatwg/console/commit/40ec790b96f50e9bf78a47985556d803d3d9712a), so the newer-spec exception does not apply.

**Fix**: Keep the browser-majority removal, document the deviation, and pin it in a native test. Source evidence checked 2026-10-18: [V8 `V8ConsoleMessageStorage::countReset`](https://github.com/v8/v8/blob/main/src/inspector/v8-console-message.cc) erases the entry; [Firefox `Console::ResetCounter`](https://github.com/mozilla-firefox/firefox/blob/main/dom/console/Console.cpp) removes it; [WebKit `InspectorConsoleAgent::countReset`](https://github.com/WebKit/WebKit/blob/main/Source/JavaScriptCore/inspector/agents/InspectorConsoleAgent.cpp) assigns zero. Keep the unrelated label-allocation rollback fix: neither algorithm permits a borrowed key to survive a failed insertion.

**Takeaway**: **Check the exact distinguishing operation in each engine before treating aggregate browser passes as evidence for an algorithm change.**
