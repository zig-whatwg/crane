# Spec Compliance: Raw event handlers own their source

**Date**: 2026-10-18
**Lesson**: A raw event handler is a stored body and source location, not a promise to read the element's attribute later.

**Why**: HTML's content-attribute change steps and getting-current-value steps run at different times. CSP can reject a replacement while the attribute itself changes. A body or frameset also sets handlers on its Window, which has no content attribute and can outlive that element.

**What Happened**: Crane compiled active-document handlers at attribute assignment and represented inert-document handlers with a boolean. That reported syntax errors too soon, captured an earlier document's realm, and could not retain a Window handler's raw source. A failed compile used the null IDL setter, removing the listener and losing its ordering among listeners added with addEventListener.

**Fix**: Store an owned body and location in the event-handler map. Determine the target's current document and form owner on first use. Take the raw value out of the map before compilation can report an error and re-enter the getter, but keep its listener. Release the stored source on replacement, compilation, removal and teardown, including teardown after the engine ends. Test allocation failures and measure the additional retained bytes. WebKit's JSLazyEventListener likewise stores source and location before lazy compilation.

**Takeaway**: **Retain the value the algorithm stores; reading the latest attribute later is observably different.**
