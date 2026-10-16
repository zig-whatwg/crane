# Debugging: A permission query cannot repair its settings object

**Date**: 2026-10-16
**Lesson**: When a permission query reports an unexpected state, verify the relevant settings object before adding a feature-local security rule.

**Why**: Permissions, `isSecureContext`, and other powerful features share the environment's security state. Secure-context computation includes ancestors and inherited environments; checking a URL scheme inside each API would disagree with that shared state and miss those rules.

**What Happened**: Row 42's `pm-query-insecure.html` expected a non-secure HTTP window, but even `assert_false(isSecureContext)` failed. The initial explanation, trusted localhost, was wrong: the runner uses `http://web-platform.test`. At base ae6ccae2564, Window's `is_secure_context` defaulted to true, its settings hook returned that field, and `setIsSecureContext` had no callers. Permissions correctly read the same hook as the public `isSecureContext` getter.

**Fix**: Preserve the HTTP fixture as a red regression for the Window/navigation owner. Compute and install security state where the environment is created, using HTML and Secure Contexts including ancestors. Keep Permissions reading the existing settings hook, with native tests for insecure-to-denied, secure-to-prompt, and Storage Access's separate denied-to-prompt query rule. Do not weaken the fixture to hide the shared defect.

**Takeaway**: **A consumer's correct behavior cannot compensate for incorrect shared settings; repair the owner and keep the reproducer.**
