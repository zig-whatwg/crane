//! ECMAScript's current realm, as the V8 adapter knows it - the Engine table's
//! `currentRealm` (AGENTS.md, "The engine boundary").
//!
//! V8 enters a function's creation context while one of its API callbacks
//! runs, so inside an operation or attribute the isolate's current context is
//! the realm of the function object: the "current realm" WebIDL converts the
//! operation's result in. The runtime.Context for it is the context manager's
//! record of that context.

const runtime = @import("runtime");
const ffi = @import("ffi.zig");
const context_manager = @import("context_manager.zig");

/// The running execution context's realm, or null when no script is running
/// or the context manager does not host its context.
pub fn currentRealm() ?runtime.Context {
    const isolate = ffi.v8_Isolate_GetCurrent() orelse return null;
    // GetCurrentContext allocates a Global we own - AGENTS.md, the C++ seam.
    const context = ffi.v8_Isolate_GetCurrentContext(isolate) orelse return null;
    defer ffi.v8_Context_Dispose(context);
    return context_manager.get(context);
}
