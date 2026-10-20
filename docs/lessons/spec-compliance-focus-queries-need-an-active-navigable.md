# Spec Compliance: Focus queries need an active navigable

**Date**: 2026-10-19
**Lesson**: Check that a document is fully active before asking whether it appears in the focused document chain.

**Why**: A helper that climbs from a document to its top-level document can return its input when no browsing context exists. Comparing that result with the original document then answers true, although there is no navigable whose focus could reach it.

**What Happened**: Wiring Document.hasFocus to the existing HTML focus helper exposed this precondition. An unfocused iframe must return false, but so must new Document(), createHTMLDocument() and DOMParser documents. The helper's first candidate equality would incorrectly accept the latter three. The upstream document-level-apis.html assertion passes in Chrome, Firefox and Safari.

**Fix**: Document.hasFocus first uses its existing activity classification to reject inactive or gone documents, then calls the shared has-focus steps. This keeps focus descent and system-focus policy in their existing owner. Native and Crane tests cover both entry conditions: documents without navigables, and focus moving into and out of an iframe while its ancestor remains focused. The focus owner's helper precondition is recorded separately for follow-up.

**Takeaway**: **A tree-walking helper's fallback identity does not establish that the root exists. Test disconnected inputs as well as connected descendants.**
