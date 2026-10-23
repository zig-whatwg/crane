# Debugging: Private JS Adapters Must Not Steal Source Locations

**Date**: 2026-10-21
**Lesson**: Moving a native adapter into JavaScript can change which script an embedding hook attributes an operation to, even when all constructor tests pass.

**Why**: A native callback leaves the application's JavaScript frame at the top of the stack. A JavaScript wrapper adds a frame of its own. CSP's creation of a violation object (2.4.1, step 2) asks for the running script's source location while the native operation is executing, so an unfiltered top-frame capture can report the wrapper instead of its caller.

**What Happened**: The WebAssembly constructor fast path passed 142 functional Crane subtests, including constructor descriptors, subclasses, cross-realm prototypes and `instanceof`. A separate CSP control caught a regression: BASE reported `https://wj1-source.test/caller.js` for blocked Module construction, while both the construct-Proxy and bound-class candidates reported an empty source URL. The existing four eval attribution controls remained green; checking only those would have missed it.

**Fix**: Keep the private adapter's compiled ScriptId in its realm-owned intrinsic array, using `Script::GetUnboundScript()->GetId()`. When collecting the running script location, compare `StackFrame::GetScriptId()` with that exact ID and skip the adapter frame. Keep the ordinary one-frame capture for unrelated calls. No native owning handle or registry is needed. Verify both the Wasm regression and the unchanged eval controls.

**Takeaway**: **A transparent JavaScript adapter must preserve attribution as well as values, arguments and prototypes. Identify private frames by engine identity; never discard a user frame merely because its URL is empty or resembles an internal name.**
