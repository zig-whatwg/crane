//! The engine protocol's realms on V8 (design 4.2): a Window's realm made and
//! ended, and the realms HTML names from the running script - entry,
//! incumbent - and ECMAScript's GetFunctionRealm.
//!
//! protocol.zig forwards these operations here. The host keeps the spec state
//! - the Window, its Document, its browsing context - and hands the engine the
//! Window through `create_global_object`; the engine makes the context, binds
//! the Window as its global object and gives it what a Window global has.

const std = @import("std");
const runtime = @import("runtime");
const engine = @import("engine");

const ffi = @import("ffi.zig");
const context_manager = @import("context_manager.zig");
const interface_bindings = @import("interface_bindings.zig");
const dom_type_info = @import("dom_type_info.zig");
const window_properties = @import("window_properties.zig");
const WrapperCache = @import("wrapper_cache.zig").WrapperCache;
const realm_v8 = @import("realm_v8.zig");
const template_registry = @import("template_registry.zig");
const page_realm = @import("page_realm.zig");
const namespaces = @import("namespaces");

const Context = engine.Context;
const JSValue = engine.JSValue;
const Error = engine.Error;

const log = std.log.scoped(.protocol_realms);

/// What the adapter keeps for a Window realm it made, until its end.
const WindowRealmState = struct {
    /// The agent - the isolate - and whether making the realm entered it.
    isolate: *ffi.Isolate,
    entered_isolate: bool,
    /// The realm's origin, serialized (owned); null for an opaque one. Kept,
    /// with the predicate below, for the WindowProxy and Location cross-origin
    /// checks - which V8 does not run yet: no access-check callback is
    /// installed, and those checks are still the impls' (Window.get_document,
    /// with the accessor Window).
    origin: ?[]u8,
    /// HTML IsPlatformObjectSameOrigin, as the host supplied it.
    is_platform_object_same_origin: ?*const fn (host: ?*anyopaque, current: Context, object: *engine.Instance) bool,
    host: ?*anyopaque,
    /// A later realm was built around this one's WindowProxy (a navigation
    /// that made a new Window): the proxy is that realm's now, so this one's
    /// end must not detach it again.
    window_proxy_handed_on: bool = false,
    /// The realm's context is entered for its life - until it ends, or until
    /// a realm that takes over its WindowProxy is entered in its place. Never
    /// for a realm with a parent (a frame's), which is made while its parent's
    /// script runs.
    context_entered: bool = true,
    /// The parent navigable's realm (WindowRealmOptions.parent), or null.
    parent: ?Context = null,
    /// The realms made with this one as their parent that have not ended:
    /// they end first when this one does.
    children: std.ArrayListUnmanaged(Context) = .empty,
    /// The realm's Window, which the host made (create_global_object).
    window: ?*engine.Instance = null,
    /// This realm's global object, once its WindowProxy went on to a later
    /// realm (window_proxy_handed_on): held weakly - empty once V8 collects
    /// it - to sever it from this realm's Window at the end. A function of
    /// this realm that script still holds looks its globals up on it, and the
    /// WindowProxy no longer reaches it.
    retired_global: ?*ffi.Value = null,
    allocator: std.mem.Allocator,
};

/// The Window realms made on this thread (an agent is one thread), by realm.
threadlocal var window_realms: std.AutoHashMapUnmanaged(Context, *WindowRealmState) = .empty;

fn contextOf(realm: Context) ?*ffi.Context {
    const engine_ctx = realm.engine_ctx orelse return null;
    return @ptrCast(@alignCast(engine_ctx));
}

/// Whether `context` is the one most recently entered in `isolate`: V8 exits
/// contexts only in the reverse of the order they were entered.
fn isLastEntered(isolate: *ffi.Isolate, context: *ffi.Context) bool {
    const entered = ffi.v8_Isolate_GetEnteredOrMicrotaskContext(isolate) orelse return false;
    defer ffi.v8_Context_Dispose(entered);
    const address = ffi.v8_Context_GetRawAddress(context) orelse return false;
    return ffi.v8_Context_GetRawAddress(entered) == address;
}

/// The runtime realm a V8 context is, releasing the context handle.
fn realmOfOwnedContext(context: ?*ffi.Context) ?Context {
    const ctx = context orelse return null;
    defer ffi.v8_Context_Dispose(ctx);
    return context_manager.get(ctx);
}

// ============================================================================
// createWindowRealm / destroyWindowRealm
// ============================================================================

/// HTML "create a new realm" (8.1.3.3) with a Window global:
///
/// 1. InitializeHostDefinedRealm() with the host's customizations - the
///    global object is a new Window (`create_global_object`), the global this
///    binding the browsing context's WindowProxy (`global_this`: a new one,
///    or the one a navigation keeps). V8 makes both in Context::New /
///    Context::FromSnapshot; the Window is bound to the global after.
/// 2-4. The realm is the context's; V8 never leaves a realm execution context
///    on the stack for it.
/// 5. Deleting SharedArrayBuffer when the agent cluster's cross-origin
///    isolation mode is "none" is NOT performed: Crane has no agent clusters
///    yet, and V8 exposes SharedArrayBuffer as it always has here.
///
/// The realm's context stays entered for the realm's life, so it is made
/// with no script running in the agent - as HTML makes a Window's realm, from
/// a navigation's task: a context entered above a running script's would
/// have to be exited before that script's.
pub fn createWindowRealm(options: *const engine.WindowRealmOptions) Error!Context {
    const isolate: *ffi.Isolate = @ptrCast(@alignCast(options.agent));
    const allocator = options.allocator;

    // The agent stays entered while its realm lives: the page's context is
    // entered for its whole life, and a context can be entered only in its
    // own isolate.
    const entered_isolate = ffi.v8_Isolate_GetCurrent() != isolate;
    if (entered_isolate) ffi.v8_Isolate_Enter(isolate);
    errdefer if (entered_isolate) ffi.v8_Isolate_Exit(isolate);

    // [reuse_window_proxy]: the WindowProxy of the realm this one replaces.
    // Blink's LocalWindowProxy::DisposeContext(kFrameWillBeReused): the proxy
    // is detached from the old context, then the new context is built around
    // it, so every reference to it - contentWindow, open()'s result - now
    // reaches the new Window. The old realm's end must then leave it alone.
    var reused_proxy: ?*ffi.Object = null;
    defer if (reused_proxy) |proxy| ffi.v8_Object_Dispose(proxy);
    switch (options.global_this) {
        .new_window_proxy => {},
        .window_proxy_of => |old| {
            const old_context = contextOf(old) orelse return error.OperationFailed;
            reused_proxy = ffi.v8_Context_Global(old_context) orelse return error.OperationFailed;
            const old_state = window_realms.get(old);
            if (old_state == null or !old_state.?.window_proxy_handed_on) {
                // The old global object, behind the proxy until the detach:
                // the old realm's end severs it from its Window. V8's V1
                // GetPrototype on a global proxy answers the hidden global
                // object (only V1 SetPrototype must never be used on one).
                if (old_state) |state| state.retired_global = retiredGlobalOf(reused_proxy.?);
                ffi.v8_Context_DetachGlobal(old_context);
            }
            if (old_state) |state| {
                state.window_proxy_handed_on = true;
                // The new realm is entered in the old one's place: V8 exits
                // contexts only in reverse order, and the old realm ends
                // while the new one lives.
                if (state.context_entered and isLastEntered(isolate, old_context)) {
                    ffi.v8_Context_Exit(old_context);
                    state.context_entered = false;
                }
            }
        },
    }

    // The context: restored from the snapshot, whose global already has the
    // WebIDL interfaces (~2 ms), or made afresh with them defined below
    // (~40 ms) - always on an engine without snapshots.
    var restored = false;
    const context: *ffi.Context = blk: {
        if (options.from_snapshot and @import("protocol.zig").capabilities.restores_snapshots != .unsupported) {
            const made = if (reused_proxy) |proxy|
                ffi.v8_Context_NewFromSnapshotWithGlobal(isolate, proxy)
            else
                ffi.v8_Context_NewFromSnapshot(isolate);
            if (made) |c| {
                restored = true;
                break :blk c;
            }
            log.debug("the snapshot's context could not be made; building the realm afresh", .{});
        }
        // The global object is an instance of the Window interface object's
        // template, as the snapshot generator makes it: its [[Prototype]] is
        // Window.prototype from the start (WebIDL 3.8), its two internal
        // fields hold the Window and its type info, and it is immutable-
        // prototype - Object.setPrototypeOf(globalThis, {}) throws. Setting
        // the prototype afterwards cannot work: an immutable [[Prototype]]
        // refuses the change.
        const global_template = ffi.v8_FunctionTemplate_InstanceTemplate(windowTemplate(isolate));
        // The context keeps what it needs of the template; the handle is ours.
        defer ffi.v8_ObjectTemplate_Dispose(global_template);
        const made = if (reused_proxy) |proxy|
            ffi.v8_Context_NewWithGlobalTemplateAndProxy(isolate, global_template, proxy)
        else
            ffi.v8_Context_NewWithGlobalTemplate(isolate, global_template);
        break :blk made orelse return error.OperationFailed;
    };
    // A frame's realm (one with a parent) takes its parent's security token:
    // V8 lets script reach another context's global proxy only with the same
    // token, and the WindowProxy's cross-origin checks are the host's.
    const parent_context: ?*ffi.Context = if (options.parent) |parent| contextOf(parent) orelse return error.OperationFailed else null;
    if (parent_context) |pc| {
        // Owned, and copied by SetSecurityToken. By default the token is the
        // parent's global object, so a kept handle would keep the page alive.
        if (ffi.v8_Context_GetSecurityToken(pc)) |token| {
            defer ffi.v8_Value_Dispose(token);
            ffi.v8_Context_SetSecurityToken(context, token);
        }
    }
    // The page's context stays entered while it lives; destroyWindowRealm
    // exits it. A frame's is entered only while it is made (below).
    ffi.v8_Context_Enter(context);
    var registered = false;
    errdefer {
        if (registered) context_manager.removeContext(context);
        ffi.v8_Context_Exit(context);
        ffi.v8_Context_Dispose(context);
    }

    // The runtime's realm for the context, recording the host's timers and
    // event loop (never run here).
    // (The manager is per thread; its only failure is having been made.)
    context_manager.init(allocator) catch {};
    const realm = context_manager.getOrCreateWithExternalEventLoop(context, options.timer, options.event_loop, allocator) catch
        return error.OperationFailed;
    registered = true;

    if (restored) {
        // The snapshot has the interfaces; the adapter's template registry
        // still has to learn them, or a wrapped Document gets the wrong
        // prototype. A frame's realm builds only the interface objects its
        // script reads (.lazy_follows, as context_manager's child contexts
        // did): every one of ~1,260 costs a frame ~25 ms and ~2.8 MB, and a
        // frame-heavy page makes dozens.
        interface_bindings.registerAllTemplatesOnly(isolate, context, if (options.parent != null) .lazy_follows else .eager);
    } else {
        interface_bindings.initializeBindingsWithGlobalTemplate(isolate, context);
    }
    // The namespaces (console, WebAssembly, CSS...) are not in the snapshot.
    interface_bindings.registerNamespacesGeneric(namespaces, isolate, context);

    // Ours until the Window's wrapper-cache entry adopts it (bindWindowToGlobal),
    // which releases it at the realm's end; the host BORROWS it until then.
    const global = ffi.v8_Context_Global(context) orelse return error.OperationFailed;
    // No Window is bound until the host has made one - and a reused proxy
    // still names the Window it had. Undoing the realm reads field 0
    // (removeContext's Window), which must not find another realm's Window,
    // nor a field never set, which V8 refuses to read as a pointer.
    ffi.v8_Object_SetAlignedPointerInInternalField(global, 0, null);
    ffi.v8_Object_SetAlignedPointerInInternalField(global, 1, null);

    // HTML "create a new realm", the customization for the global object:
    // the host's new Window, bound to `global` (BORROWED by the host).
    const window = options.create_global_object(realm, .{ .handle = .{ .ptr = global } }, options.host) orelse {
        ffi.v8_Object_Dispose(global);
        return error.OperationFailed;
    };
    bindWindowToGlobal(isolate, context, realm, global, window, allocator);

    const state = allocator.create(WindowRealmState) catch return error.OutOfMemory;
    errdefer allocator.destroy(state);
    state.* = .{
        .isolate = isolate,
        .entered_isolate = entered_isolate,
        .origin = if (options.origin) |o| allocator.dupe(u8, o) catch return error.OutOfMemory else null,
        .is_platform_object_same_origin = options.is_platform_object_same_origin,
        .host = options.host,
        .parent = options.parent,
        .window = window,
        .allocator = allocator,
    };
    errdefer if (state.origin) |o| allocator.free(o);
    const parent_state: ?*WindowRealmState = if (options.parent) |parent| window_realms.get(parent) else null;
    if (parent_state) |ps| ps.children.append(std.heap.c_allocator, realm) catch return error.OutOfMemory;
    errdefer if (parent_state) |ps| removeChild(ps, realm);
    window_realms.put(std.heap.c_allocator, realm, state) catch return error.OutOfMemory;

    if (options.parent != null) {
        // A frame's window gets the window operations its parent's has.
        page_realm.defineOnFrame(isolate, context);
        // Made while the parent's script runs: its context leaves the stack
        // now, and is entered for each call that runs in it.
        ffi.v8_Context_Exit(context);
        state.context_entered = false;
        if (entered_isolate) {
            ffi.v8_Isolate_Exit(isolate);
            state.entered_isolate = false;
        }
    }
    return realm;
}

/// `proxy`'s hidden global object, as a weak handle (empty once collected).
fn retiredGlobalOf(proxy: *ffi.Object) ?*ffi.Value {
    const value = ffi.v8_Object_GetPrototype(proxy) orelse return null;
    if (!ffi.v8_Value_IsObject(value)) {
        ffi.v8_Global_Dispose(value);
        return null;
    }
    ffi.v8_Global_SetWeak(@ptrCast(value), null, &retiredGlobalCollected);
    return value;
}

/// A retired global object was collected: its weak handle is empty now,
/// which is all the realm's end needs to know.
fn retiredGlobalCollected(_: ?*anyopaque, _: usize) callconv(.c) void {}

/// Clear `window` from `global` and the prototype objects behind it (the
/// placeholder, WindowProperties) before the Window is freed: a Window member
/// read through them is then an illegal invocation, not a read of freed
/// memory.
fn severWindow(global: *ffi.Object, window: *engine.Instance) void {
    clearWindowField(global, window);
    var links: [3]?*ffi.Value = .{ null, null, null };
    defer for (links) |link| {
        if (link) |value| ffi.v8_Value_Dispose(value);
    };
    var current: *ffi.Object = global;
    for (&links) |*slot| {
        const proto = ffi.v8_Object_GetPrototypeV2(current) orelse return;
        slot.* = proto;
        if (!ffi.v8_Value_IsObject(proto)) return;
        const object: *ffi.Object = @ptrCast(proto);
        clearWindowField(object, window);
        current = object;
    }
}

/// Sever `context`'s WindowProxy and the global object behind it - both
/// carry the Window in field 0 - from `window`, which is being freed while
/// the global stays attached (engine.WindowRealmEnd.navigable_destroyed).
/// Only compares `window`; never reads it.
fn severAttachedGlobal(context: *ffi.Context, window: *engine.Instance) void {
    const proxy = ffi.v8_Context_Global(context) orelse return;
    defer ffi.v8_Object_Dispose(proxy);
    severWindow(proxy, window);
    // V1 GetPrototype on a global proxy answers the hidden global object,
    // which V2 (severWindow's walk) steps over.
    const global = ffi.v8_Object_GetPrototype(proxy) orelse return;
    defer ffi.v8_Global_Dispose(global);
    if (ffi.v8_Value_IsObject(global)) severWindow(@ptrCast(global), window);
}

fn clearWindowField(object: *ffi.Object, window: *engine.Instance) void {
    if (ffi.v8_Object_InternalFieldCount(object) < 1) return;
    const ptr = ffi.v8_Object_GetAlignedPointerFromInternalField(object, 0) orelse return;
    if (@intFromPtr(ptr) != @intFromPtr(window)) return;
    ffi.v8_Object_SetAlignedPointerInInternalField(object, 0, null);
}

fn removeChild(state: *WindowRealmState, child: Context) void {
    for (state.children.items, 0..) |c, i| {
        if (c != child) continue;
        _ = state.children.swapRemove(i);
        return;
    }
}

/// The agent's Window interface template, made and registered - EventTarget
/// first, so Window inherits the registered one - when no realm has made it
/// yet. A template made here gets the WindowProxy's indexed access
/// (`frames[i]`, HTML 7.2.3.1) on its instances, as the snapshot generator's
/// does; one an earlier realm made and used cannot change any more (V8 refuses
/// to alter an instantiated template).
fn windowTemplate(isolate: *ffi.Isolate) *ffi.FunctionTemplate {
    if (template_registry.getTemplateForIsolate("Window", isolate)) |made| return made;
    if (template_registry.getTemplateForIsolate("EventTarget", isolate) == null) {
        template_registry.register("EventTarget", interface_bindings.EventTarget.createTemplate(isolate), isolate);
    }
    const template = interface_bindings.Window.createTemplate(isolate);
    template_registry.register("Window", template, isolate);
    const instance_template = ffi.v8_FunctionTemplate_InstanceTemplate(template);
    defer ffi.v8_ObjectTemplate_Dispose(instance_template);
    ffi.v8_ObjectTemplate_SetIndexedPropertyHandlerFull(
        instance_template,
        context_manager.windowIndexedPropertyGetter,
        null,
        context_manager.windowIndexedPropertyQuery,
        context_manager.windowIndexedPropertyEnumerator,
        null,
    );
    return template;
}

/// Bind `window` as `global`'s platform object, and give the global what a
/// Window's global has.
fn bindWindowToGlobal(
    isolate: *ffi.Isolate,
    context: *ffi.Context,
    realm: Context,
    global: *ffi.Object,
    window: *engine.Instance,
    allocator: std.mem.Allocator,
) void {
    // Internal field 0: the Window; 1: its type info.
    ffi.v8_Object_SetAlignedPointerInInternalField(global, 0, @ptrCast(window));
    if (dom_type_info.getTypeInfoByName("Window")) |type_info| {
        ffi.v8_Object_SetAlignedPointerInInternalField(global, 1, @ptrCast(@constCast(type_info)));
    }

    // Cross-origin checks ask the context manager for an accessor's Window.
    context_manager.setWindowForContext(context, window) catch |err| {
        log.debug("the realm's Window was not recorded: {}", .{err});
    };

    // The global IS the Window's wrapper - and its cache entry takes the
    // handle over, releasing it when the realm ends (removeContext). Not
    // taken (no cache, out of memory), it is released once the global is
    // set up.
    const adopted = blk: {
        const storage = realm.getV8WrapperCacheStorage() orelse break :blk false;
        const cache: *WrapperCache = @ptrCast(@alignCast(storage));
        cache.set(window, global, isolate) catch break :blk false;
        break :blk true;
    };
    defer if (!adopted) ffi.v8_Object_Dispose(global);

    // The realm record - context, agent, global object: cross-realm errors,
    // the realm's intrinsics, and "the realm's global object".
    if (realm.realm == null) {
        if (runtime.Realm.init(allocator, .{
            .engine_realm = @ptrCast(context),
            .agent = @ptrCast(isolate),
            .context_type = .window,
            .global_object = @ptrCast(window),
        })) |record| {
            // The realm's intrinsics (%TypeError%, %Object%, %Array%...), for
            // making objects and errors in this realm from another.
            _ = realm_v8.populateIntrinsics(record);
            realm.setRealm(record);
            context_manager.setRealmForContext(context, record) catch {};
        } else |err| log.debug("the realm record was not made: {}", .{err});
    }

    // WebIDL 3.8, [Global]: the interface's attributes and operations - and
    // EventTarget's, which Window inherits - are own properties of the global,
    // since its immutable prototype cannot be relied on to provide them.
    interface_bindings.Window.registerPropertiesAsOwnOnObject(isolate, context, global);
    interface_bindings.Window.registerMethodsAsOwnOnObject(isolate, context, global);
    interface_bindings.EventTarget.registerMethodsAsOwnOnObject(isolate, context, global);

    // HTML 7.3.3, named access on the Window: WindowProperties on the chain.
    _ = window_properties.insertIntoPrototypeChain(isolate, context, window);

    // `self` and `frames` are [Replaceable]: own data properties whose value
    // is the global itself, as their setter's [[DefineOwnProperty]] makes them
    // - defined, never assigned, which would run the script-facing setter
    // (docs/lessons/architecture-engine-code-defines-a-realm-s-properties-it-
    // never-assigns-them.md). They keep `self === globalThis`, which
    // testharness.js's `(function (global_scope) { ... })(self)` needs.
    // (`window` is served by its accessor.)
    inline for (.{ "self", "frames" }) |name| {
        if (ffi.v8_String_NewFromUtf8(isolate, name.ptr, name.len)) |key| {
            defer ffi.v8_String_Dispose(key);
            _ = ffi.v8_Object_DefineProperty(global, context, @ptrCast(key), @ptrCast(global), true, true, true);
        }
    }
}

/// A realm whose end is under way on this thread: a stack, one node per
/// destroyWindowRealm frame, innermost first.
const EndingRealm = struct {
    realm: Context,
    next: ?*const EndingRealm,
};
threadlocal var ending_realms: ?*const EndingRealm = null;

fn isEnding(realm: Context) bool {
    var node = ending_realms;
    while (node) |n| : (node = n.next) {
        if (n.realm == realm) return true;
    }
    return false;
}

/// The end of a Window realm (Blink's LocalWindowProxy::DisposeContext order),
/// as `how` says (engine.WindowRealmEnd).
pub fn destroyWindowRealm(realm: Context, how: engine.WindowRealmEnd) void {
    // A realm ends once, and its end can reach itself: the context manager's
    // teardown frees what the realm's wrapper cache holds, and a removed
    // iframe element wrapped only here (`frames[0].frameElement`) takes its
    // integration with it - whose cleanup is this realm's end. The inner call
    // does nothing; the outer one finishes. Blink's
    // LocalWindowProxy::DisposeContext likewise returns unless its lifecycle
    // is still kContextIsInitialized.
    if (isEnding(realm)) return;
    const ending: EndingRealm = .{ .realm = realm, .next = ending_realms };
    ending_realms = &ending;
    defer ending_realms = ending.next;

    // Its frames' realms that are still alive end first, the same way: a
    // removed frame's frames are destroyed navigables too.
    if (window_realms.get(realm)) |s| {
        while (s.children.pop()) |child| destroyWindowRealm(child, how);
        s.children.deinit(std.heap.c_allocator);
    }
    const state = if (window_realms.fetchRemove(realm)) |kv| kv.value else null;
    defer if (state) |s| {
        if (s.origin) |o| s.allocator.free(o);
        if (s.retired_global) |g| ffi.v8_Global_Dispose(g);
        s.allocator.destroy(s);
    };
    if (state) |s| if (s.parent) |parent| {
        if (window_realms.get(parent)) |ps| removeChild(ps, realm);
    };
    const context = contextOf(realm) orelse return;
    const isolate: *ffi.Isolate = if (state) |s| s.isolate else @ptrCast(@alignCast(ffi.v8_Isolate_GetCurrent() orelse return));

    // The window operations this realm installed end with it; a frame's
    // window gives up its timers.
    page_realm.endWindowOperations(realm);
    if (state) |s| if (s.parent != null) page_realm.frameWindowDestroyed(realm);

    // A global object whose WindowProxy went on to a later realm is not
    // reached through the context any more: sever it from the Window the
    // context manager is about to free.
    if (state) |s| if (s.retired_global) |g| {
        if (!ffi.v8_Global_IsEmpty(g) and ffi.v8_Value_IsObject(g)) {
            if (s.window) |window| severWindow(@ptrCast(g), window);
        }
    };

    // 1. The context manager first: it tears down the Window, its document and
    // its frames, and retires the realm - which from here on has no engine
    // context, and may only be compared.
    context_manager.removeContext(context);
    // 2. The context and its global proxy - the WindowProxy, which outlives
    // them.
    switch (how) {
        // Break the link, unless a later realm already took the proxy over.
        .global_detached => if (state == null or !state.?.window_proxy_handed_on) ffi.v8_Context_DetachGlobal(context),
        // Blink's DisposeContext(kFrameIsDetached) leaves the global
        // attached: script that holds a removed frame's WindowProxy still
        // reads its own properties - `self`, `frames`, `globalThis` - and
        // `window` (self-et-al.window.js). Detached, every read threw "no
        // access", from whenever the collector freed the removed iframe.
        // The global outlives the Window the context manager just freed, so
        // it is severed from it: a member that needs the Window finds none
        // and throws a TypeError, rather than reading freed memory.
        .navigable_destroyed => if (state) |s| if (s.window) |window| severAttachedGlobal(context, window),
    }
    // 3. Exit the context entered for the realm's life - unless a realm
    // that took over its WindowProxy was entered in its place. Only the last
    // entered context can be exited; one still under another is left entered
    // rather than exited out of order, which V8 does not survive.
    const entered = if (state) |s| s.context_entered else true;
    if (entered) {
        if (isLastEntered(isolate, context))
            ffi.v8_Context_Exit(context)
        else
            log.warn("a Window realm ended under another entered context; its context stays entered", .{});
    }
    // 4. Tell V8 a context is garbage (forced: sequential pages must not pile
    // up), and release the handle.
    _ = ffi.v8_Isolate_ContextDisposedNotification(isolate, true);
    ffi.v8_Context_Dispose(context);
    if (state) |s| if (s.entered_isolate) ffi.v8_Isolate_Exit(isolate);
}

// ============================================================================
// entryRealm / incumbentRealm / functionRealm
// ============================================================================

/// HTML 8.1.3.3.1: the entry realm is the realm of the most recently pushed
/// realm execution context - V8's entered context (Context::Enter, which
/// "prepare to run script" performs), or a running microtask's.
pub fn entryRealm() ?Context {
    const isolate = ffi.v8_Isolate_GetCurrent() orelse return null;
    return realmOfOwnedContext(ffi.v8_Isolate_GetEnteredOrMicrotaskContext(isolate));
}

/// HTML 8.1.3.3.2: the incumbent realm - the topmost script-having execution
/// context's realm, or the backup incumbent settings object's when that
/// context is being skipped or there is none. V8's GetIncumbentContext is
/// those steps, with Context::BackupIncumbentScope as the backup stack
/// ("prepare to run a callback" pushes one).
pub fn incumbentRealm() ?Context {
    const isolate = ffi.v8_Isolate_GetCurrent() orelse return null;
    return realmOfOwnedContext(ffi.v8_Isolate_GetIncumbentContext(isolate));
}

/// ECMAScript GetFunctionRealm(`value`): its [[Realm]], through bound
/// functions and proxies. Null for a value that is no object, one whose realm
/// the context manager does not host, and at a revoked proxy (where the spec
/// throws a TypeError: the caller answers it). Deviation, as V8's own walk
/// makes it: an object that is no function answers its creation context
/// (a platform object: its relevant realm) where step 5 says the current
/// realm.
pub fn functionRealm(value: JSValue) ?Context {
    const handle: *ffi.Value = switch (value) {
        .handle => |h| @ptrCast(@alignCast(h.ptr)),
        .instance => |instance| return instance.ctx,
        else => return null,
    };
    var revoked = false;
    return realmOfOwnedContext(ffi.v8_Value_GetFunctionRealm(handle, &revoked));
}
