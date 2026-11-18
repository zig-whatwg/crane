# Spec Compliance: "same origin with a document" means its origin record, not the browsing context's field

**Date**: 2026-11-18
**Lesson**: When a step compares a navigable's active document's origin, read the documents' own origin records (dom.document_origin + dom.origin_record.sameOrigin); `BrowsingContext.origin` is not kept current for every navigation.

**Why**: HTML gives each Document its origin; Crane keeps it as the Document's OriginRecord (shared exactly as HTML shares origins). `BrowsingContext.origin` is an older field set at some navigations only. A frame navigated to about:blank after its initial document (`iframe.src = "about:blank"`, which inherits the initiator's origin) kept a value there that no longer matched the parent's.

**What Happened**: fullscreen/api/element-ready-allowed.html clicks in the parent and requests fullscreen in a same-origin about:blank frame. HTML's activation notification (6.4.2 step 4) extends activation to descendant navigables "whose active document's origin is same origin with document's origin"; Crane compared `descendant.isSameOrigin(context)` - the browsing contexts' fields - so the frame was skipped, had no transient activation, and the request was denied (Chrome and Safari pass). A probe showed `ua.top=true | ua.frame=false`.

**Fix**: `user_activation.activeDocumentSameOrigin(descendant, document)`: the descendant's active window's document and the activating document, each through `dom.document_origin.shareable`, compared with `dom.origin_record.sameOrigin` (opaque identity included). Lane blk2, a17389ea594.

**Takeaway**: **For any "same origin" check between documents, compare the documents' origin records; treat `BrowsingContext.origin` as stale until proven otherwise.**
