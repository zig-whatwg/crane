# Architecture: A load makes a new Document and never empties the old one

**Date**: 2026-10-08
**Lesson**: Context.loadHTML parsed every load into the Document its realm was created with. It emptied that Document first by freeing its children directly (`document_internals.clearChildren`, `deinitNodeByType`). A parser of that Document still on the native stack, or script holding its nodes, was then left pointing at freed memory.

**Why**: HTML navigation never reuses a document. "Create and initialize a Document object" step 9 makes a new one for every load. Step 10 makes it the window's associated Document before the parser exists. The old document is unloaded and dropped. Browsers keep whatever might still be on the stack: Blink's HTMLTreeBuilder::Detach keeps the open-elements stack "because HTMLConstructionSite might be on the callstack", and WebKit's parser holds itself with `Ref protectedThis`. Crane's frames already made a new Document per navigation (parseHtmlForIframe), and Browser.navigate makes a new Context. The top-level load path was the one place that emptied a live document in place.

**What Happened**: The parser-holds lane found that `dom_parser.parseHTMLWithScripting(existing_document)` was the only caller of `clearChildren`. A test loader that loads a second page into the same Context while the first page's parser prepares `<script src>` reproduces it. On the base, the first page's nodes and the script element being prepared were freed under the parser. Two more consequences:
- `document` in script was still the first page's object.
- The realm-creation document stayed alive forever as `__internal.document`.

**Fix**:
1. Every load makes a new Document (`createLoadDocument`). It is linked through the hooks the owners install: `dom.window_globals.setDocument` (Window) and `dom.document_browsing_context.setWindow` (Document). `__internal.document` and `document_instance` are updated, and the current session history entry is repointed.
2. The replaced Document is only aborted (`dom.document_lifecycle.abort`), which aborts its parser and cancels its fetches. If abort listeners start a load meanwhile, that document is aborted too: the replaced document is whichever one is current once no script runs.
3. Its storage is left to its owner, its wrapper. It always has one: `setWindow` traces it from the window. While the old parser unwinds, its active call roots it (`DocumentParser.protect`). After that, script or the collector decides, or the realm's end does.
4. A document whose load event has run, and of which no parser can be on the stack, is unloaded within the load, as browsers do: pagehide, visibilitychange, unload, then destroy. Blink's Document::DispatchUnloadEvents returns early while the load event has not run (`kLoadEventNotRun`), and WebKit's FrameLoader::dispatchUnloadEvents waits for `m_didCallImplicitClose`. Otherwise no events fire, and HTML "destroy a document" (destroyed, scripts and parser discarded) runs from a task (`DestroyReplacedDocument`). That task re-queues itself while the load that made the document is still parsing. It holds the document by slab generation only, and does nothing for one already collected. Whether a document.open() parser exists is checked before the abort, because the abort ends that parser's "loading" readiness.
5. The realm-creation Document is the top-level traversable's initial about:blank document: marked, in quirks mode, and populated with html/head/body. The first load replaces it, as in browsers.
6. `existing_document` and `clearChildren` were removed.

**Takeaway**: **Never empty a document to reuse it. A parser or script may still name its nodes. Make a new document, abort the old one, leave its storage to its wrapper, and run "destroy a document" from a task once nothing of it is on the stack.**
