# Testing: Reporting an exception turns a swallowed failure into a harness ERROR

**Date**: 2026-09-22
**Lesson**: Once uncaught exceptions reach `window.onerror` (`src/html/report_exception.zig`), testharness counts every throw outside a test step as a harness ERROR.

**What Happened**: merging the scripting agent's reporting moved ~30 files in its area and 33 of 2,219 checked elsewhere from OK to ERROR, each with the same or more passing subtests. Each ERROR message names a real engine defect (Illegal invocation in form validation, `CSS.supports` missing, iframes lacking `remove`, ...).

**Takeaway**: **An OK that depended on an exception being dropped was never an OK. Triage the new ERROR by its message; do not revert the reporting.**
