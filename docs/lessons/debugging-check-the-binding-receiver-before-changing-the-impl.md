# Debugging: Check the binding receiver before changing the impl

**Date**: 2026-10-14
**Lesson**: A method can use its supplied instance correctly while the binding has already substituted the wrong receiver.

**Why**: A function's creation realm, its explicit JavaScript receiver, and an argument's realm are separate facts. HTML's reportError reports for its receiver's global, even when the method and the error come from another window.

**What Happened**: Implementing reportError through the existing extraction and host-reporting operations made all ten upstream window/worker checks pass. The cross-realm test still dispatched error at the top window. V8 MethodCallback's Global-interface branch in `src/runtime/engines/v8/interface.zig` recognized an explicit other global, then returned `realmWindow(method_ctx, method_global)` instead. The impl never received the requested window.

**Fix**: Keep the receiver-based impl and route the binding defect to its owner. Preserve `html/webappapis/scripting/reporterror-cross-realm-method.html` as the regression. Correcting the binding must distinguish the specified default for a missing receiver from an explicit other global. Guessing a target from the error object's realm would fail for primitives and for errors created in a third realm.

**Takeaway**: **Trace the actual receiver through the binding; an impl cannot reconstruct an argument the binding discarded.**
