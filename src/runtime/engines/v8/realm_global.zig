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
//! - `receiverRealm` / `globalOfReceiver`, THE Window-receiver rule every Window member callback goes
//!   through (design 2.3 and its ruling).
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

// ============================================================================
// THE Window-receiver rule
// ============================================================================

/// The realm whose Window a Window member acts on, given the object V8 handed its callback - This() for
/// a FunctionTemplate accessor or method, Holder() for a native accessor or an interceptor on the global
/// - as an owned context (v8_Context_Dispose); null when the receiver is no Window (the binding throws
/// "Illegal invocation").
///
/// 1. A CONTEXTUAL use - `document`, `setTimeout(...)`, `addEventListener(...)` with no `window.` - acts
///    on the Window of the realm the callback runs in. The integrator's ruling (2026-11-11 00:48 UTC,
///    golden rule 2; probe tmp/probes/v8up-detached/, design 2.3): after a navigation handed the
///    WindowProxy on, a function of the OLD realm reads the OLD Window's members contextually, as
///    ECMA-262 GetBindingValue of the global object record makes WebIDL's `this` the old global object,
///    and as Firefox 159 and Safari 27 do; Chrome 156 reads the new Window, because V8 replaces the
///    global-object receiver by `global_proxy()` (objects.cc 1650-1656, GetPropertyWithAccessor), which
///    after DetachGlobal is the reused proxy. What V8 15.7 hands Crane for such a use: a FunctionTemplate
///    member gets This() = the reused proxy - its realm's Global() - and runs in the holder's creation
///    context, the OLD one (objects.cc 1660 SaveAndSwitchContext); a native accessor or interceptor gets
///    Holder() = V8's detached COPY of the proxy, with empty fields and no creation context or the old
///    one (Isolate::DetachGlobal's global_proxy_for_api, V8 32fd863235d; GetHolderForApi,
///    api-callbacks-inl.h 283-291; `isDetachedGlobalCopy`) and runs in the caller's context, the OLD one.
///    Both are "the current realm's Window" here.
///    KNOWN DEVIATION (integrator 2026-11-11 01:05 UTC; pinned by
///    tests/wpt/crane/v8up-old-realm-explicit-getter-deviation.html): `oldGetter.call(window)` from the
///    old realm reads the OLD Window here; the spec and all three browsers (Chrome 156.0.8078.76,
///    Firefox 159.0.1, Safari 27.0; probe v2) read the NEW one, through the WindowProxy. V8 15.7 cannot
///    tell it from a contextual read: both arrive with This() = the reused proxy in the old context
///    (Builtins::InvokeApiFunction with the receiver already replaced; FunctionCallbackInfo has no
///    Holder() or Callee() any more), and a detached context's LoadGlobalIC always goes slow
///    (ic.cc 1109-1113), so no IC state tells them apart either.
/// 2. Any other realm's WindowProxy - `iframe.contentWindow.document`, a getter of one realm called on
///    another's window - acts on the Window that proxy names now: its realm's (the receiver is the global
///    proxy of its own creation context).
/// 3. Anything else - Object.create(Window.prototype), a plain object - is no Window.
///
/// `callback` says which object `receiver` is and which context the callback runs in, because V8 differs:
/// - `.member`: a FunctionTemplate accessor or method (every IDL attribute and operation). V8 runs it in
///   the HOLDER's creation context (objects.cc SaveAndSwitchContext; a method call in its function's), so
///   the current realm is the realm whose global object the member was found on - for a contextual use in
///   a navigated-away realm, that realm, whose Global() is the reused proxy, This(): steps 1-3 as above.
/// - `.native`: a native accessor or interceptor on the global (a lazy interface object, the indexed
///   interceptor), given Holder(). V8 does NOT switch contexts for it: the current realm is the CALLER's,
///   which says nothing about whose global the property is on. A navigated-away realm reading
///   `window.DOMParser` reaches the NEW realm's lazy property with Holder() = the reused proxy, and its own
///   context's Global() is that same proxy, so step 1 took the new global's property for the old realm's,
///   and V8 stored the old realm's interface object on the new global (lane v8up b3e,
///   tests/v8/v8up_old_realm_members_test.zig). So the holder decides: an attached proxy is its creation
///   context's (the realm it is attached to), V8's detached copy is the old realm's - its creation context
///   when it kept one (`isDetachedGlobalCopy`), else the current realm, which for the copy is the old one.
pub fn receiverRealm(isolate: *ffi.Isolate, receiver: *ffi.Object, callback: Callback) ?*ffi.Context {
    const current = ffi.v8_Isolate_GetCurrentContext(isolate) orelse return null;
    if (callback == .native) {
        const own = ffi.v8_Object_GetCreationContext(receiver) orelse {
            // A contextless object: V8's detached copy, met in the old realm's own read.
            if (isDetachedGlobalCopy(current, receiver)) return current;
            ffi.v8_Context_Dispose(current);
            return null;
        };
        // The proxy attached to its realm, or the copy that kept the old realm as its creation context.
        if (isGlobalOf(own, receiver) or isDetachedGlobalCopy(own, receiver)) {
            ffi.v8_Context_Dispose(current);
            return own;
        }
        ffi.v8_Context_Dispose(own);
        ffi.v8_Context_Dispose(current);
        return null;
    }
    // 1. The current realm's own global proxy, or V8's detached copy of it.
    if (isGlobalOf(current, receiver) or isDetachedGlobalCopy(current, receiver)) return current;
    ffi.v8_Context_Dispose(current);
    // 2. Another realm's global proxy.
    const own = ffi.v8_Object_GetCreationContext(receiver) orelse return null;
    if (isGlobalOf(own, receiver)) return own;
    ffi.v8_Context_Dispose(own);
    // 3. No Window.
    return null;
}

/// Which callback `receiverRealm` answers for (see there).
pub const Callback = enum { member, native };

/// The global object `receiver` resolves to under `receiverRealm`'s rule - a Window, or a worker's or a
/// worklet's global scope for their [Global] members - or null: the receiver is no realm's global, or its
/// realm has none any more (ended - its global object was freed).
pub fn globalOfReceiver(isolate: *ffi.Isolate, receiver: *ffi.Object, callback: Callback) ?*runtime.Instance {
    const context = receiverRealm(isolate, receiver, callback) orelse return null;
    defer ffi.v8_Context_Dispose(context);
    return context_manager.globalObjectForContext(context);
}

/// Whether `object` is `context`'s global proxy.
fn isGlobalOf(context: *ffi.Context, object: *ffi.Object) bool {
    const global = ffi.v8_Context_Global(context) orelse return false;
    defer ffi.v8_Object_Dispose(global);
    return ffi.v8_Value_StrictEquals(@ptrCast(object), @ptrCast(global));
}

/// Whether `object` is the copy of `current`'s global proxy V8 makes at DetachGlobal and hands a detached
/// context's native accessors and interceptors as Holder() (Isolate::DetachGlobal, src/execution/isolate.cc
/// 8010-8038 at 15.7.112.43; JSGlobalObject::global_proxy_for_api, i::GetHolderForApi): the proxy's map, so
/// its internal field count, with every field empty, and as creation context either none or `current`.
/// Which of the two depends on the map the copy kept: DetachGlobal copies the proxy, then
/// JSObject::ForceSetPrototype(proxy, null) gives the PROXY a new map and only that one is made contextless
/// (meta map, null constructor) - so the copy keeps the old map, whose meta map names the old native context
/// (JSReceiver::GetCreationContext reads the meta map's native context). A page's frame realm showed that
/// (lane v8up b3e, a V8UPDIAG print in the lazy interface getter: creation context present, field 0 empty,
/// not the context's Global()), and its first read of a lazy interface object was undefined - Chrome 157's
/// answer too, by the same V8 mechanism; Firefox 159 and Safari 27 give the old realm's (probe
/// tmp/probes/v8up-oldwin3/; the majority, the integrator's ruling). A live proxy, attached or not, has
/// its Window in field 0; a proxy whose Window was freed (a removed frame's, severed) is never `current`'s
/// copy unless its own realm is current, where step 1 already answered.
fn isDetachedGlobalCopy(current: *ffi.Context, object: *ffi.Object) bool {
    if (ffi.v8_Object_InternalFieldCount(object) < 1) return false;
    if (ffi.v8_Object_GetAlignedPointerFromInternalField(object, 0) != null) return false;
    const context = ffi.v8_Object_GetCreationContext(object) orelse return true;
    defer ffi.v8_Context_Dispose(context);
    const own = ffi.v8_Context_GetRawAddress(context) orelse return false;
    return own == ffi.v8_Context_GetRawAddress(current);
}
