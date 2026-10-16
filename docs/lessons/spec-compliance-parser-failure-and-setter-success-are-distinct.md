# Spec Compliance: Parser failure and setter success are distinct

**Date**: 2026-10-12
**Lesson**: Preserve a parser's failure result even when its usual caller ignores that failure.

**Why**: The URL port state is used both by forgiving URL setters and by URLPattern's validating encoding callback. Making the parser itself report success for invalid input silently weakens other callers.

**What Happened**: The state-override port parser returned success for an overflowing port or a value with no digits. URL setter WPT stayed green because setters deliberately ignore the parse result; URLPattern consequently accepted invalid ports. Crane applies parsed components to the target URL at the end, so returning failure also needed to preserve a host already parsed before the bad port.

**Fix**: Report the port-state failure and apply the already-parsed host inside those failure branches. Existing URL and Location setters already ignore parse failures. Native tests pin both the error and the preserved host/old port; URL and Location WPT check the observable setter behavior.

**Takeaway**: **Test the parser result and each caller's error policy independently; identical setter behavior does not prove that the parser returned the right result.**
