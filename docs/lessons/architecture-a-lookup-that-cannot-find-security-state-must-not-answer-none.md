# Architecture: A lookup that cannot find security state must not answer "none"

**Date**: 2026-10-18
**Lesson**: Every CSP host read a policy container lookup's null as "no policies, allow": a Window whose document (or a Document whose internal state) could not be found ran with no CSP at all. Fail closed at the lookup, with a static value, so no reader can misread it.

**Why**: `dom.policy_containers.of(document)` and a Window's settings-object hook returned `?*PolicyContainer`, and null meant two things: "this global keeps none" and "it keeps one I cannot find". The hosts wrote `orelse return false` (dom.csp_violations' inline and javascript: URL checks), `orelse return .allowed` (html.code_generation, through dom.trusted_types.cspListOf), "No document = allow" (Document.isInlineScriptAllowedByCSP), and "populate request from client" left a request on "client", which main fetch checks against no CSP. Lane leaks4's iframe OOM sweep had seen a frame's Document with no internal state.

**What Happened**: Lane leaks5 made the not-found case a value: `csp.CSPList.unavailable` (empty, unenforceable - every src/csp entry point blocks it) and `fetch.internal.PolicyContainer.unavailable` (that list, no-referrer). Both are `pub const` statics: reading or cloning them allocates nothing, and copyList keeps the flag, so a request's or a worker's clone fails closed too. Window's settings hook answers the static instead of null; dom.csp_violations.documentCspList does the same for a Document; the iframe's source and traversal snapshots stop the navigation, and an initial about:blank document that cannot inherit marks its own list unenforceable. tests/html/missing_policy_container_fails_closed_test.zig checks each host with a Window that was never given a document, against the page's own Window as the control.

**Fix**: Give the "cannot find it" case its own answer at the lookup - a static, fail-closed value of the same type - and keep null for "this kind of global keeps none".

**Takeaway**: **Never let "I cannot find the policy" share a return value with "there is no policy": answer a static fail-closed value at the lookup, and every host that reads it is closed without knowing.**
