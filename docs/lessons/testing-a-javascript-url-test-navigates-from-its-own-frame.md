# Testing: A javascript: URL test navigates from the frame's own script, and ends in void

**Date**: 2026-10-03
**Lesson**: Two traps made a correct javascript: URL check look broken: the entry settings object decides a navigation's source document, and a javascript: URL whose code returns a string replaces the frame's document.

**Why**: `frame.contentWindow.eval("location.href = 'javascript:...'")` from the parent runs with the PARENT as the entry settings object, so the parent's CSP and policies applied. And HTML's "evaluate a javascript: URL" makes a String result the new document's body, which also replaces the target of any event the test waits for.

**What Happened**: tt-javascript-url-pre-navigation.html failed 0/3 against a check that was right: the policy ran in the wrong realm, and the report-only case lost its violation event.

**Fix**: Navigate from the frame's own script (its own setTimeout), and end such test code in `void (...)`.

**Takeaway**: **In a navigation test, make the realm that navigates the one whose policy you mean to test, and never let javascript: URL code return a string by accident.**
