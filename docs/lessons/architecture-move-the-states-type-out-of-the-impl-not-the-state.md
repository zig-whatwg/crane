# Architecture: Move the state's type out of the impl, not the state

**Date**: 2026-09-30
**Lesson**: When another subsystem works on an object's non-IDL state, move the state's TYPE to where both can see it and hook a typed pointer to it; the impl keeps the state itself, with the same lifetime.

**Why**: The impls boundary forbids script_execution from naming HTMLScriptElement's impl, and it made 40 calls there, one accessor per field (`getParserDocument`, `setAlreadyStarted`, `getResult`, ...), plus 33 into Document's. Replacing each accessor with a hook function would have built a forwarding facade of ~40 function pointers, which is a second copy of the impl's API. Moving the state itself out of the impl, into a side table the other subsystem owns, would have changed who allocates and frees it. That is exactly the kind of lifetime change this engine has shipped use-after-frees from.

**What Happened**: The scriptimpls lane (2026-09-30) moved only the definitions:

- `src/html/script_element.zig` defines `State` (the script element's parser document, already started, result, ...) and its types. `HTMLScriptElement.zig` says `pub const InternalState = script_element.State` and keeps creating it in its registry block in `init` and freeing it in `deinit`. The only new code in the impl is `script_element.install(.{ .state = &getInternal })`. script_execution calls `script_element.of(el)` and works on the fields.
- `src/dom/document_scripts.zig` defines `Scripts` (the script lists, the pending parsing-blocking script, currentScript, the ignore-destructive-writes counter). Document's InternalState embeds one by value in place of six fields and installs `of`. Document's 17 script-list accessors, and document_internals' 17 forwarders to them, were deleted rather than wrapped.
- Things that are really operations on other Document state (the CSP checks, the import map, the module map) stayed as function pointers bound to Document's existing functions. Only state that is plain data became a struct.

The drain of the in-order script list could then leave its head in place (`firstInOrder`, then `removeFirstInOrder` once the head is ready) instead of popping it and putting every script back. 123 references into impls went, and nothing's lifetime moved.

**Fix**:
1. Put the type where every party can import it. If the type uses src/html types (a module script), that is src/html, and the hook goes with it: the lint does not care where a hook lives, and src/dom cannot see html.
2. Leave ownership where it is. The owner's InternalState becomes the moved type, or embeds it by value, so there is one block, one deinit and no copy.
3. The hook is one accessor, `of(object) ?*State`, installed by the owner from its `init`.
4. Delete the old accessors, and grep for the fields as well as the functions before you do.

**Takeaway**: **Move the state's type out of the impl, not the state: one typed `of()` hook replaces a facade of accessors, and ownership never moves.**
