# Architecture: A request carries a clone of its client's policies, not a pointer to them

**Date**: 2026-10-02
**Lesson**: Fetch "populate request from client" step 3 gives a request a CLONE of its client's policy container; main fetch reads the request's copy. Keeping it that way is what lets a fetch outlive the document that started it.

**Why**: A request runs asynchronously, redirects (each redirect runs main fetch again: steps 5 and 7 must see the same policies), and can outlive its client - XMLHttpRequest even stores its client between open() and send(). A borrowed pointer to the document's container would dangle, and a lookup at fetch time would read policies a later meta element added.

**What Happened**: The secfeatures lane gave Documents and WorkerGlobalScopes a `fetch.internal.PolicyContainer` (referrer policy, CSP list, the inherited insecure requests policy). `RequestClient.policy_container` is borrowed for the populate call only; the request clones it (`setPolicyContainer`, freed by `deinit`, copied by `clone`); XHR's stored client keeps its own heap clone. Navigations clone the source document's container at navigate time (source snapshot params) for the request, and "determine navigation params policy container" gives the new document the response's, the parent's (srcdoc) or the initiator's (local URLs) - each a clone. A CSP list is copied by re-parsing each policy's serialization (`csp.parsing.copyPolicy`), which "parse a serialized CSP" turns back into the same directives.

**Fix**: `src/fetch/internal/policy_container.zig`, `dom.policy_containers` (Document's hook), `global_settings.Settings.policy_container` (Window: its document's; WorkerGlobalScope: its host's), and `IFrameIntegration.next_policy_container` for the document `parse_html_callback` makes - set before the parser runs, since a `<meta name=referrer>` in the new document must win over the response's header.

**Takeaway**: **Security state a request reads travels WITH the request as a clone taken when the client populates it; never as a pointer back to the document, and never as a lookup at fetch time.**
