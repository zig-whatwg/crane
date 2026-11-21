//! HTML "create a new realm" step 5, for every realm the V8 adapter makes - a
//! Window's (protocol_realms.createWindowRealm), a worker's
//! (worker_realm.createWorkerRealm) and a worklet's
//! (worklet_realm.createWorkletRealm):
//!
//! 5. If agent's agent cluster's cross-origin isolation mode is "none":
//!    1. Let global be realm's global object.
//!    2. Let status be ! global.[[Delete]]("SharedArrayBuffer").
//!    3. Assert: status is true.
//!
//! The host passes the mode as `agent_cluster_cross_origin_isolated` (false:
//! "none"). The property is the one ECMA-262 puts on every global object
//! (SetDefaultGlobalBindings: writable, configurable, not enumerable), so the
//! delete succeeds - on a context restored from the snapshot as on a new one,
//! since both are made with it.
//!
//! Chrome and Firefox expose no SharedArrayBuffer global to a page that is
//! not cross-origin isolated (Blink decides per context at its creation, by
//! V8's Isolate::SetSharedArrayBufferConstructorEnabledCallback: bindings/
//! core/v8/v8_initializer.cc SharedArrayBufferConstructorEnabledCallback
//! answers the execution context's SharedArrayBufferTransferAllowed - the
//! same outcome as the spec's delete); Safari shares the
//! decision with its process (html/cross-origin-opener-policy/noopener-popup-
//! cross-origin-isolation.https.html: C157 4/4, F160 4/4, S27.2 2/4 - its two
//! same-site failures read typeof SharedArrayBuffer "function" in a popup
//! sharing the isolated opener's process).
//!
//! Spec: https://html.spec.whatwg.org/multipage/webappapis.html#creating-a-new-javascript-realm

const std = @import("std");
const ffi = @import("ffi.zig");

const name = "SharedArrayBuffer";

/// Step 5 for the realm whose context is `context` (entered, a HandleScope
/// open): delete the global's SharedArrayBuffer when the agent cluster's
/// cross-origin isolation mode is "none".
pub fn apply(isolate: *ffi.Isolate, context: *ffi.Context, agent_cluster_cross_origin_isolated: bool) void {
    if (agent_cluster_cross_origin_isolated) return;
    // 1. Let global be realm's global object - reached through its
    //    WindowProxy (the context's global proxy), which forwards
    //    [[Delete]] to it.
    const global = ffi.v8_Context_Global(context) orelse return;
    defer ffi.v8_Object_Dispose(global);
    const key = ffi.v8_String_NewFromUtf8(isolate, name, name.len) orelse return;
    defer ffi.v8_String_Dispose(key);
    // 2-3. ! global.[[Delete]]("SharedArrayBuffer"); the property is
    //      configurable, so it is true.
    const status = ffi.v8_Object_Delete(global, context, @ptrCast(key));
    std.debug.assert(status);
}
