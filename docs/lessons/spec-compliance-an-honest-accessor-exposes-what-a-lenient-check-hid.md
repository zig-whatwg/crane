# Spec Compliance: An honest accessor exposes what a lenient check hid

**Date**: 2026-09-27
**Lesson**: When a security check starts asking the right realm, the features the wrong answer was covering for stop working - find them before calling the drop a regression of the migration.

**Why**: Window.document's cross-origin check needs the accessor: the realm of the script reading `document`. It read context_manager's accessor stack, or else V8's current context. Inside the `document` getter the current context is the getter's own - the target window's - so every cross-frame read with no accessor pushed (an event handler, a message task) was judged a self-access and allowed.

**What Happened**: Moving Window.zig onto the protocol, the accessor became `engine.incumbentRealm()`. The A/B then showed dom/events/EventListener-incumbent-global-1/2 going from OK to TIMEOUT and javascript-url-security-check-same-origin-domain from 1/1 to 0/1. All three set `document.domain` on two subdomains and read each other's documents. document.domain had never done anything: its setter stored a string no check read, and its getter returned "" unless set. The old check passed them only because it compared the target with itself. After document.domain was implemented, the inheritance tests showed the next hidden gap: an about:blank document shares its creator's origin, domain included.

**Fix**: Implement the missing spec pieces rather than restore the lenient check. That meant HTML 7.1.1.2's getter and setter, with the public suffix list's "is a registrable domain suffix of or is equal to". It also meant "same origin-domain" in the check, with the origin's domain reached through a Document hook (src/dom/document_origin.zig), and the creator's domain read for a creator-origin document (05a30200a, 4797fefa0).

**Takeaway**: **A security check that suddenly fails correct pages was usually passing everything before; test it with a pair that must pass and a pair that must fail.**
