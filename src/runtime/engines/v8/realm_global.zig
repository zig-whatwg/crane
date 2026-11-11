//! A realm's global object on V8 >= 14 (lane v8up b3c; tmp/plans/v8-global-object-design.md 1-2).
//!
//! V8 removed every embedder path to a context's JSGlobalObject (crbug.com/333672197): the V1
//! `GetPrototype` Crane reached it by is `Object.getPrototypeOf` since 21963a7493e, and a property
//! callback's Holder() for a property of an attached global is the global PROXY (3d66b2bdda7). What V8
//! offers is Blink's model, which this file follows:
//!
//! - `attach`, THE attach function for every realm global - a Window's (fresh, or restored from the
//!   snapshot: Blink's LocalWindowProxy::Initialize runs the same SetupWindowPrototypeChain after
//!   Context::FromSnapshot as after Context::New, design 1.5), a worker's, a worklet's, a ShadowRealm's:
//!   the global instance in the proxy's internal field 0 (the receiver and every conversion read it) and
//!   a GlobalAnchor set by `Object::WrapGlobal` on the proxy AND its hidden global object
//!   (LocalWindowProxy::SetupWindowPrototypeChain, local_window_proxy.cc 405-449, at Chromium
//!   157.0.8103.51; WorkerOrWorkletScriptController::Initialize..., worker_or_worklet_script_controller.cc
//!   205-213). The anchor's retained store is what the realm's global keeps alive (`retainedStore`).
//! - `handOn`, a navigation that hands the WindowProxy to a new realm: the proxy's anchor is cleared
//!   (Blink LocalWindowProxy::DisposeContext step 2, ClearNativeInfo), the hidden global keeps the old one,
//!   and the new realm's `attach` re-wraps the proxy. No handle to the old global object exists (Blink 1.2):
//!   the old anchor - its retained store - lives while that object does, and Zig's reference to it reads
//!   gone in the collection that takes it.
//! - `clearInstance`, the global instance is about to be freed: field 0 and the anchor's instance go.
//!
//! The anchor itself is the context manager's, on the realm's entry (ContextEntry.global_anchor): made by
//! `attach`, cleared before the realm's global instance is freed and disposed when the entry is retired
//! (context_manager.removeContextByKey), on the agent's thread.

const std = @import("std");
const runtime = @import("runtime");

const ffi = @import("ffi.zig");
const context_manager = @import("context_manager.zig");

/// THE attach function for `context`'s global (see the file comment): `instance` - the realm's Window,
/// WorkerGlobalScope, worklet global scope, or null for a realm with no global platform object (a
/// ShadowRealm's: Crane makes no ShadowRealmGlobalScope yet) - bound to the global proxy, and a new
/// GlobalAnchor on the proxy and its hidden global object, kept on the realm's context manager entry.
/// Called once per realm, after the context manager registered it; a second call replaces the anchor
/// (the old one cleared).
pub fn attach(context: *ffi.Context, instance: ?*runtime.Instance) void {
    // [wrap_tracking]: the global object reaches the instance from here.
    if (instance) |bound| runtime.instance_lifecycle.markWrapped(bound);
    const ref = ffi.v8_GlobalAnchor_Attach(context, @ptrCast(instance)) orelse return;
    context_manager.adoptGlobalAnchor(context, ref);
}

/// A navigation hands `old_context`'s WindowProxy to a new realm (HTML "create and initialize a Document
/// object" with a reused WindowProxy; Blink LocalWindowProxy::DisposeContext(kGlobalObjectIsDetached),
/// local_window_proxy.cc 171-235): step 2, ClearNativeInfo on the proxy only - the old hidden global keeps
/// its anchor, and with it its Window and retained store - before Context::DetachGlobal (step 4). The new
/// realm's `attach` then wraps the proxy with its own anchor.
pub fn handOn(old_context: *ffi.Context) void {
    ffi.v8_GlobalAnchor_ClearProxy(old_context);
}

/// The realm's global instance is about to be freed while its global may outlive it (a worker's end, a
/// destroyed navigable's Window): the proxy's field 0 no longer names it - when it still does; a proxy
/// a later realm took over names that realm's - and the anchor's instance is cleared, which severs the
/// hidden global and every object wrapped with the anchor (WindowProperties) at once.
pub fn clearInstance(context: *ffi.Context, instance: ?*runtime.Instance) void {
    if (ffi.v8_Context_Global(context)) |proxy| {
        defer ffi.v8_Object_Dispose(proxy);
        if (ffi.v8_Object_InternalFieldCount(proxy) >= 1) {
            const named = ffi.v8_Object_GetAlignedPointerFromInternalField(proxy, 0);
            if (instance == null or named == @as(?*anyopaque, @ptrCast(instance))) {
                ffi.v8_Object_SetAlignedPointerInInternalField(proxy, 0, null);
            }
        }
    }
    if (context_manager.globalAnchorOf(context)) |ref| ffi.v8_GlobalAnchor_Clear(ref);
}

/// The realm's retained store - what its global object keeps alive (its Window's traced edges; once the
/// realm is detached, its wrappers and callbacks): an owned Global (v8_Global_Dispose), or null when the
/// realm has no anchor or its global object is gone. `realm` is any runtime realm; only one whose context
/// the context manager still records has one.
pub fn retainedStore(realm: runtime.Context) ?*ffi.Value {
    const engine_ctx = realm.engine_ctx orelse return null;
    const context: *ffi.Context = @ptrCast(@alignCast(engine_ctx));
    const ref = context_manager.globalAnchorOf(context) orelse return null;
    return ffi.v8_GlobalAnchor_Retained(ref);
}
