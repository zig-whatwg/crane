# Security: Sanitizing a Tree Does Not Undo Parser Side Effects

**Date**: 2026-10-16
**Lesson**: A safe HTML setter requires inert parsing before its tree filter runs.

**Why**: Marking parsed script elements already-started prevents those scripts from executing. It does not prevent attribute-change hooks from compiling event handlers, scheduling image loads, or queuing custom-element work. Removing the resulting node later cannot undo a request or a callback already scheduled for it.

**What Happened**: The Sanitizer implementation reused the existing fragment parser, as its file grant required. That parser constructed nodes in the context element's live document and applied normal attribute hooks. An image's load kept the disconnected image alive. Filtering removed the image, but its queued load still fetched and dispatched to its handler. The upstream sanitizer-inert-document test exposed both script execution and a network request from removed markup. Removing an entire node did not exercise event-handler attribute deactivation at all.

**Fix**: Hold the safe API's merge until the parser owner supplies the separate inert document required by fragment parsing, with no resource loading, handler activation or registry work before survivors are inserted. Gate the combined change on the complete inert-document test. Do not substitute pre-parse attribute stripping, event cancellation or post-parse undo.

**Takeaway**: **Test parser side effects as well as the sanitized DOM. A clean tree does not establish safe parsing.**
