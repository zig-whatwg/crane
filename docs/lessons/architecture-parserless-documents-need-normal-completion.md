# Architecture: Parserless documents need normal completion

**Date**: 2026-10-08
**Lesson**: A navigation fallback must complete the document's lifecycle, not merely notify its container.

**Why**: A parent's load delay depends on both its child's navigable delay and the child's ready-for-post-load state. Clearing one condition cannot release the other. A loading document can also have a suspended parser, so readiness alone does not identify a parserless fallback.

**What Happened**: Adding all three iframe load-delay predicates exposed the existing XML fallback. Crane has no navigation XML parser; the fallback created a document and directly fired container load, leaving ready-for-post-load false. The full worklist comparison then changed XML/SVG parent-load tests from OK to TIMEOUT. The same fallback could prematurely fire an HTML iframe's load while its persistent parser waited on a stylesheet.

**Fix**: Restrict the fallback to navigation's XML response classification. Give Document an owner hook that runs its existing guarded end steps only when no active parser exists and readiness is loading. Those steps transition readiness and queue DOMContentLoaded, load, and container completion in order. Keep HTML/text/media documents on their parser-owned EOF path. The regression probe covers XML, XHTML, and SVG parent completion plus a stylesheet-suspended HTML child; allocator-checked tests pin post-load readiness and preservation of an associated parser. This does not implement the missing XML parser or claim XML tree conformance.

HTML §14.2 makes XML EOF use §13.2.7's end steps. [WebKit XMLDocumentParser::end](https://github.com/WebKit/WebKit/blob/main/Source/WebCore/xml/parser/XMLDocumentParser.cpp) changes readiness to interactive, checks detachment after that observable transition, and calls Document::finishedParsing. Crane reuses its corresponding document-owned guarded completion rather than inventing an XML-only event shortcut.

**Takeaway**: **Complete the owning document's state machine before notifying its container, and never infer parser absence from loading readiness.**
