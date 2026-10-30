# Spec Compliance: Browsers inherit COOP into top-level local documents

**Date**: 2026-10-29
**Lesson**: A top-level about:blank, blob: or data: document gets its initiator's top-level document's opener policy in Chrome, Firefox and Safari, though HTML's navigation algorithm reads the opener policy only from the response's headers - implement the browsers' rule, or every same-origin blob popup of a COOP page is severed.

**Why**: HTML "create navigation params by fetching" step 21.12.1 obtains the response's opener policy from its `Cross-Origin-Opener-Policy` header. A blob: or data: response has none, so its value is "unsafe-none", and from a COOP page's popup that never matches: the popup is moved to a new browsing context group and its opener is cut. Only the initial about:blank document has a rule (19.3: the creator's top-level document's policy, when the creator is same origin with it).

**What Happened**: Lane coi1 implemented the switch by the text, then read html/cross-origin-opener-policy/blob-popup.https.html: a `Cross-Origin-Opener-Policy: same-origin` page opens a blob: popup and expects `popup.opener === window` - 1/1 in Chrome 156, Firefox 159 and Safari 27 (wpt.fyi 07ce6e987a). navigate-top-to-aboutblank.https.html states the rule in its text ("Non-initial empty documents (about:blank) should inherit their cross-origin-opener-policy from the navigation's initiator top level document, if the initiator and its top level document are same-origin") and passes 3/3 in Chrome and Safari. Chromium keeps COOP in the policy container a local document inherits (PolicyContainerPolicies), which is why the rule falls out there.

**Fix**: Snapshot the initiator's top-level opener policy (19.3's same-origin condition) with the source's policy container when a top-level traversable navigates to a local URL, and give it to the new document's container in "determine navigation params policy container" step 3. The container's clone does NOT copy the opener policy: a srcdoc or local child document never reads one, and a request never does.

The same lane met the other half of the trap: once a local document inherits a policy, the switch decision must compare it with the document's real origin - navigationParams's ("determining the origin": an about:blank document's is its initiator's) - not the origin of its URL. Reading about:blank's origin from the URL made every same-origin about:blank navigation of a COOP popup switch groups (navigate-to-aboutblank.https.html lost 3 subtests in the A/B).

**Takeaway**: **Before enforcing a navigation policy that reads only response headers, check what local-scheme documents get - the browsers inherit where the spec is silent, and the tests encode it - and compare with navigationParams's origin, never the URL's.**
