# Spec Compliance: Origin keying uses group isolation

**Date**: 2026-10-20
**Lesson**: Diagnose the state feeding an origin getter, and distinguish group isolation from a document's permission to use isolation-gated APIs.

**Why**: HTML gives a browsing context group a cross-origin isolation mode: none, logical, or concrete. Both logical and concrete imply origin-keyed agent clusters. An environment settings object's cross-origin isolated capability instead controls access to gated APIs; logical isolation does not grant that capability. These facts are related, but one boolean cannot represent both.

**What Happened**: Row 104's remaining origin blocker was `origin-keyed-agent-clusters/getter-special-cases/cross-origin-isolated.sub.https.html`. Both parent and child reported false. The origin-keying helper already returned true when passed isolation. The caller obtained that argument from `BrowsingContext.isCrossOriginIsolated`, whose COOP and COEP fields remained at their defaults: the setters had no production callers. Changing the Origin API, document.domain comparison, or the getter's return value would bypass the missing navigation and group-state work.

The test supplies COOP same-origin and COEP require-corp to the parent, but only COEP to the child. Requiring every child to supply the top-level COOP header would still fail the group's inheritance rule. Conversely, granting a document's isolated capability solely to make originAgentCluster true would overstate what the group and platform provide.

**Fix**: Route the change to the navigation and agent-group owner. Process and enforce the response policies, represent the group's isolation mode, and derive the agent cluster key from that mode. Keep the environment capability's separate restrictions. Preserve the getter's delegation through the owning state rather than adding an Origin-specific header shortcut. Pin parent and cross-origin child cases independently and then run the whole file. This row records the dependency; it does not implement that state or claim the blocker fixed.

HTML references, checked against the 16 October 2026 cache:

- [Origin-keyed agent clusters](https://html.spec.whatwg.org/multipage/browsers.html#origin-keyed-agent-clusters): non-none isolation implies origin keying.
- [Browsing context groups](https://html.spec.whatwg.org/multipage/document-sequences.html#cross-origin-isolation-mode): logical and concrete modes, and their capability distinction.
- [Environment settings objects](https://html.spec.whatwg.org/multipage/webappapis.html#concept-settings-object-cross-origin-isolated-capability): capability governs gated API access.

Aligned wpt.fyi revision `0f26972422b15f587e2afbd38dbb6ea2397fded0`: Chrome 155 and Firefox 158 pass both keying assertions; Safari 27 lacks originAgentCluster. [Per-file results](https://wpt.fyi/results/html/browsers/origin/origin-keyed-agent-clusters/getter-special-cases/cross-origin-isolated.sub.https.html?run_ids=6244794098778112,5917475882663936,5156841570172928). Safari's absent getter is not evidence against group isolation.

**Takeaway**: **Fix the owner of the missing isolation state; origin keying and isolation-gated API permission are separate decisions.**
