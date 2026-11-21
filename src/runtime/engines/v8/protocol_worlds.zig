//! The engine protocol's isolated worlds on V8 (engine_protocol.zig section
//! 4.2a; tmp/plans/cdp-part1-design.md 3.5): several JavaScript worlds over
//! one DOM.
//!
//! Blink's model, reproduced (Chromium third_party/blink/renderer/platform/
//! bindings/dom_wrapper_world.h and .cc, dom_data_store.h, script_state.h;
//! core/frame/window_proxy_manager.h, local_window_proxy.cc; BSD-3 - the
//! design is taken, no code): a world per id; a context per (frame, world),
//! made lazily by the frame's WindowProxyManager, with its own global object,
//! WindowProxy, interface objects and prototypes over the SAME C++ DOM; a
//! wrapper per (object, world) - the main world's inline in the object, the
//! other worlds' in the world's DOMDataStore; the world's contexts disposed
//! with the frame's on navigation. WebKit's DOMWrapperWorld (Source/WebCore/
//! bindings/js/DOMWrapperWorld.h, JSDOMWrapperCache.h) is the same design under
//! reference counting; its files carry LGPL headers and were read for the
//! design only.
//!
//! What Crane makes of it:
//! - A WORLD REALM per (Window realm, world): a V8 context of the agent made
//!   from the snapshot's Window context like any Window realm, whose global
//!   object is bound to the main realm's Window (protocol_realms.
//!   bindWindowToGlobal). Its runtime realm is a realm of its own - its own
//!   wrapper cache, intrinsics and window operations - whose settings are the
//!   main realm's (`principal_realm`: the API base URL, the origin and the
//!   fetch client follow it, as a ShadowRealm's follow its creator's), whose
//!   Browser, event loop and task sink are the main realm's, and whose
//!   context-manager entry says its world (ContextEntry.world).
//! - The WRAPPER of a platform object is chosen by the world of the realm
//!   converting it (`wrapperRealm`): its relevant realm's world realm for that
//!   world, made on first need. Every world realm's wrapper cache is a world
//!   cache (WrapperCache.world): it keeps NODE wrappers too - the side table
//!   Blink's DOMDataStore is for a non-main world - each holding a counted
//!   reference on its node, as every WebKit wrapper holds a Ref; the node's
//!   inline slot stays the main world's. A non-node platform object is freed
//!   when the last cache of its agent that wraps it lets go (the caches'
//!   existing rule, `wrappedElsewhere`), so a world's wrapper keeps it as the
//!   main world's does.
//! - The WALK (dom.wrapper_tracing, engine.traceNodeWrapper) keeps a reached
//!   tree's world wrappers with its main-world ones: node_wrappers'
//!   traceNodeWrapper asks `traceWorldWrappers` for each node it names once
//!   the agent has a world realm (Registry.worlds).
//! - A world realm ENDS before its main realm (protocol_realms.endRealm) and
//!   when its main realm is detached (a navigation replaced its document, or
//!   its navigable went: protocol_realms.detach) - Blink's
//!   WindowProxyManager::ClearForNavigation and ClearForClose dispose every
//!   world's context with the frame's.
//! - A WindowProxy per (navigable, world): a navigation that keeps the main
//!   world's WindowProxy (WindowRealmOptions.global_this = window_proxy_of)
//!   hands each world's on too (`handOnWorldProxies`), and the next world
//!   realm made for that world under the new main realm is built around it -
//!   Blink's WindowProxy objects live in the frame's WindowProxyManager and are
//!   re-initialized in the new document.
//!
//! Deviations, part 1 (documented, for the test pass): a reachable world
//! wrapper of a node does not walk its tree - its node is kept (its counted
//! reference) but a main-world wrapper of that tree that nothing else reaches
//! may be collected; a string TimerHandler a world passes to setTimeout is
//! compiled in the main realm, whose Window keeps the world's timers
//! (page_realm.receiverWindowRealm), where Blink compiles it in the world.
//!
//! Engine work in the sense of AGENTS.md (handle ownership, allocator
//! lifetimes, teardown order): every `v8_*` call returning a pointer made a
//! Global the caller owns.

const std = @import("std");
const runtime = @import("runtime");
const engine = @import("engine");

const ffi = @import("ffi.zig");
const context_manager = @import("context_manager.zig");
const protocol_agents = @import("protocol_agents.zig");
const protocol_realms = @import("protocol_realms.zig");
const realm_global = @import("realm_global.zig");
const page_realm = @import("page_realm.zig");
const interface_bindings = @import("interface_bindings.zig");
const shared_array_buffer_exposure = @import("shared_array_buffer_exposure.zig");
const node_wrappers = @import("node_wrappers.zig");
const WrapperCache = @import("wrapper_cache.zig").WrapperCache;
const namespaces = @import("namespaces");

const Context = engine.Context;
const WorldId = engine.WorldId;
const Error = engine.Error;

const log = std.log.scoped(.protocol_worlds);

/// The private key of the array on a realm's retained store that keeps its
/// callbacks once it ends (protocol_realms' `retained_key`, the same store).
const retained_key = "crane:retained";

/// A world's options, recorded by the first realm made for it
/// (engine.WorldRealmOptions).
const Definition = struct {
    /// OWNED (c_allocator).
    name: []u8,
    universal_access: bool,
};

/// A world realm the adapter made and that has not ended.
const WorldRealm = struct {
    realm: Context,
    /// The main-world realm whose Window the global wraps.
    main: Context,
    world: WorldId,
    /// The context handle, OWNED (a Global<Context>): disposed at the end.
    context: *ffi.Context,
    /// The context manager's key for the context, read while it lived.
    key: usize,
    /// The Window the global was bound to (the main realm's), and its slab
    /// generation then.
    window: *engine.Instance,
    /// The world's WindowProxy went on to the next world realm of the same
    /// navigable (`handOnWorldProxies`): this realm's end leaves it alone.
    window_proxy_handed_on: bool = false,
};

/// A world's WindowProxy waiting for the next world realm of its navigable,
/// after a navigation (`handOnWorldProxies`).
const HandedProxy = struct {
    world: WorldId,
    /// OWNED (v8_Object_Dispose): the detached global proxy.
    proxy: *ffi.Object,
};

/// One agent's worlds, on its record (protocol_agents.AgentRecord.worlds):
/// read and written on the agent's own thread only - the walk reads it in a
/// collection's atomic pause, when nothing else runs there. Freed by the
/// agent's end (`endAgent`). Storage: std.heap.c_allocator, as the agent's
/// other per-realm maps (protocol_realms.WindowRealms).
pub const AgentWorlds = struct {
    /// Every world realm, by realm.
    realms: std.AutoHashMapUnmanaged(Context, *WorldRealm) = .empty,
    /// The world realms of each main realm, in the order they were made.
    by_main: std.AutoHashMapUnmanaged(Context, std.ArrayListUnmanaged(*WorldRealm)) = .empty,
    /// The worlds' options, by world.
    definitions: std.AutoHashMapUnmanaged(WorldId, Definition) = .empty,
    /// WindowProxies a navigation kept for the next main realm's worlds.
    handed: std.AutoHashMapUnmanaged(Context, std.ArrayListUnmanaged(HandedProxy)) = .empty,
    /// engine.installWorldObserver.
    observer: ?*const engine.WorldObserver = null,
    observer_host: ?*anyopaque = null,
    /// The agent has made a world realm: conversions ask the world, and the
    /// walk visits world wrappers, from then on. Never cleared.
    active: bool = false,
};

/// The worlds of `realm`'s agent; null for a realm of no agent createAgent
/// made.
fn worldsOfRealm(realm: Context) ?*AgentWorlds {
    const isolate = isolateOf(realm) orelse return null;
    return protocol_agents.worldsOf(isolate);
}

fn isolateOf(realm: Context) ?*ffi.Isolate {
    const agent = realm.agent orelse return null;
    return @ptrCast(@alignCast(agent));
}

fn find(worlds: *const AgentWorlds, main: Context, world: WorldId) ?*WorldRealm {
    const list = worlds.by_main.get(main) orelse return null;
    for (list.items) |w| {
        if (w.world == world) return w;
    }
    return null;
}

// ============================================================================
// The gate: whether a conversion has a world to ask
// ============================================================================

/// Whether a conversion of `instance` may need a world's wrapper: false -
/// a few loads, no lookup and no lock - until its Browser has made a world
/// realm (BrowserScope.isolated_worlds_active), so the main world's
/// conversions pay nothing for worlds no one made. A realm of no Browser
/// reads the standalone scope's (runtime.initializeRuntime's: the engine's
/// own tests), and with none has no world.
pub inline fn mayConvertInWorld(instance: *engine.Instance) bool {
    return realmMayHaveWorlds(instance.ctx);
}

pub fn realmMayHaveWorlds(realm: Context) bool {
    const scope = realm.browserScope() orelse return false;
    return scope.isolated_worlds_active.load(.monotonic);
}

/// The world of the realm converting a value now: the current context's
/// (V8 enters a function's creation context while its callback runs, so
/// inside a binding it is the realm of the running function) - 0 with no
/// script running, or in a realm that is no world realm.
pub fn convertingWorld(isolate: *ffi.Isolate) WorldId {
    const current = ffi.v8_Isolate_GetCurrentContext(isolate) orelse return engine.main_world;
    defer ffi.v8_Context_Dispose(current);
    return worldOfContext(current);
}

/// The world of the realm whose context `context` is (0 for any realm that
/// is no world realm, or a context the context manager does not know).
pub fn worldOfContext(context: *ffi.Context) WorldId {
    const entry = context_manager.getEntry(context) orelse return engine.main_world;
    return entry.world;
}

/// The realm a platform object whose relevant realm is `relevant` is wrapped
/// in for `world`: `relevant` itself for the main world; its world realm
/// for any other - made on first need (code of the world reached an object
/// of a Window realm the world had no realm for yet, `frames[0]` or a
/// frame's document: Blink's WindowProxy::InitializeIfNeeded), with the
/// options the world was defined with. Null when the object cannot be
/// wrapped in that world: its realm is no live Window realm (detached by a
/// navigation or its navigable's removal), or the world realm could not be
/// made. An object whose relevant realm is no Window realm at all (a realm
/// the adapter did not make as one) is wrapped in `relevant`.
pub fn wrapperRealm(relevant_realm: Context, world: WorldId) ?Context {
    if (world == engine.main_world) return relevant_realm;
    // An object made in a world realm by a path that did not map it to its
    // main realm is the main realm's all the same.
    const relevant = mainRealmOf(relevant_realm);
    const worlds = worldsOfRealm(relevant) orelse return relevant;
    if (find(worlds, relevant, world)) |w| return w.realm;
    const facts = protocol_realms.windowRealmFacts(relevant) orelse return relevant;
    if (facts.detached) return null;
    if (!worlds.definitions.contains(world)) return null;
    return makeWorldRealm(worlds, relevant, facts, world) catch |err| {
        log.debug("a world realm made on first need failed: {s}", .{@errorName(err)});
        return null;
    };
}

/// `wrapperRealm`'s context, BORROWED from the realm record, or null.
pub fn wrapperContext(relevant: Context, world: WorldId) ?*ffi.Context {
    const realm = wrapperRealm(relevant, world) orelse return null;
    const engine_ctx = realm.engine_ctx orelse return null;
    return @ptrCast(@alignCast(engine_ctx));
}

// ============================================================================
// The operations
// ============================================================================

/// engine.createWorldRealm.
pub fn createWorldRealm(main_realm: Context, options: *const engine.WorldRealmOptions) Error!Context {
    if (options.world == engine.main_world) return main_realm;
    const main = mainRealmOf(main_realm);
    const worlds = worldsOfRealm(main) orelse return error.OperationFailed;
    if (find(worlds, main, options.world)) |w| return w.realm;
    const facts = protocol_realms.windowRealmFacts(main) orelse return error.OperationFailed;
    if (facts.detached) return error.OperationFailed;
    _ = try define(worlds, options);
    return makeWorldRealm(worlds, main, facts, options.world);
}

/// The world's definition: the one recorded, or `options` recorded now.
fn define(worlds: *AgentWorlds, options: *const engine.WorldRealmOptions) Error!Definition {
    if (worlds.definitions.get(options.world)) |known| return known;
    const name = std.heap.c_allocator.dupe(u8, options.name) catch return error.OutOfMemory;
    errdefer std.heap.c_allocator.free(name);
    const definition: Definition = .{ .name = name, .universal_access = options.universal_access };
    worlds.definitions.put(std.heap.c_allocator, options.world, definition) catch return error.OutOfMemory;
    return definition;
}

/// engine.worldRealmFor.
pub fn worldRealmFor(main: Context, world: WorldId) ?Context {
    if (world == engine.main_world) return main;
    const worlds = worldsOfRealm(main) orelse return null;
    const w = find(worlds, main, world) orelse return null;
    return w.realm;
}

/// engine.worldOf.
pub fn worldOf(realm: Context) WorldId {
    const w = stateOf(realm) orelse return engine.main_world;
    return w.world;
}

/// engine.mainRealmOf.
pub fn mainRealmOf(realm: Context) Context {
    const w = stateOf(realm) orelse return realm;
    return w.main;
}

/// engine.worldInfoOf.
pub fn worldInfoOf(realm: Context) ?engine.WorldInfo {
    const worlds = worldsOfRealm(realm) orelse return null;
    const w = worlds.realms.get(realm) orelse return null;
    const definition = worlds.definitions.get(w.world) orelse return .{ .world = w.world, .name = "", .universal_access = false, .main = w.main };
    return .{ .world = w.world, .name = definition.name, .universal_access = definition.universal_access, .main = w.main };
}

/// engine.worldRealmsOf.
pub fn worldRealmsOf(main: Context, out: []Context) usize {
    const worlds = worldsOfRealm(main) orelse return 0;
    const list = worlds.by_main.get(main) orelse return 0;
    for (list.items, 0..) |w, i| {
        if (i >= out.len) break;
        out[i] = w.realm;
    }
    return list.items.len;
}

/// engine.installWorldObserver.
pub fn installWorldObserver(agent: *engine.Agent, observer: ?*const engine.WorldObserver, host: ?*anyopaque) void {
    const worlds = protocol_agents.worldsOf(@ptrCast(@alignCast(agent))) orelse return;
    worlds.observer = observer;
    worlds.observer_host = if (observer != null) host else null;
}

/// Whether script of `realm` - a world realm made with universal access -
/// may reach every origin's objects (cross_origin.zig's IsPlatformObject-
/// SameOrigin): Blink's isolated world security origin, which
/// grantUniveralAccess gives every origin's access.
pub fn hasUniversalAccess(realm: Context) bool {
    const worlds = worldsOfRealm(realm) orelse return false;
    const w = worlds.realms.get(realm) orelse return false;
    const definition = worlds.definitions.get(w.world) orelse return false;
    return definition.universal_access;
}

fn stateOf(realm: Context) ?*WorldRealm {
    // A realm of an agent with no world realm is none: one lookup of the
    // agent's record, and none of the map.
    const worlds = worldsOfRealm(realm) orelse return null;
    if (!worlds.active) return null;
    return worlds.realms.get(realm);
}

// ============================================================================
// Making a world realm
// ============================================================================

/// HTML "create a new realm" for `main`'s Window in `world`: the context,
/// as protocol_realms.createWindowRealm makes a Window realm's - from the
/// snapshot, around the world's WindowProxy a navigation kept, if any - with
/// the main realm's Window bound to its global. Not entered for its life:
/// it may be made while script runs (a world reaching another frame), and is
/// entered for each call that runs in it, as a frame's realm is.
fn makeWorldRealm(worlds: *AgentWorlds, main: Context, facts: protocol_realms.WindowRealmFacts, world: WorldId) Error!Context {
    const isolate = facts.isolate;
    const allocator = facts.allocator;
    // The record first: nothing of the engine is made when there is no room.
    const state = std.heap.c_allocator.create(WorldRealm) catch return error.OutOfMemory;
    errdefer std.heap.c_allocator.destroy(state);

    const entered_isolate = ffi.v8_Isolate_GetCurrent() != isolate;
    if (entered_isolate) ffi.v8_Isolate_Enter(isolate);
    defer if (entered_isolate) ffi.v8_Isolate_Exit(isolate);

    // The world's WindowProxy a navigation kept for this navigable, OWNED.
    const reused_proxy = takeHandedProxy(worlds, main, world);
    defer if (reused_proxy) |proxy| ffi.v8_Object_Dispose(proxy);

    // The context, as createWindowRealm makes one.
    var restored = false;
    const context: *ffi.Context = blk: {
        if (facts.from_snapshot and @import("protocol.zig").capabilities.restores_snapshots != .unsupported) {
            const made = if (reused_proxy) |proxy|
                ffi.v8_Context_NewFromSnapshotWithGlobal(isolate, proxy)
            else
                ffi.v8_Context_NewFromSnapshot(isolate);
            if (made) |c| {
                restored = true;
                break :blk c;
            }
        }
        const global_template = ffi.v8_FunctionTemplate_InstanceTemplate(protocol_realms.windowTemplate(isolate));
        defer ffi.v8_ObjectTemplate_Dispose(global_template);
        const made = if (reused_proxy) |proxy|
            ffi.v8_Context_NewWithGlobalTemplateAndProxy(isolate, global_template, proxy)
        else
            ffi.v8_Context_NewWithGlobalTemplate(isolate, global_template);
        break :blk made orelse return error.OperationFailed;
    };
    // Its own security token (V8's default, its global object): V8 asks the
    // access check on every access to its WindowProxy from another realm,
    // as for any Window realm (cross_origin.zig).
    protocol_agents.restrictCodeGenerationFromStrings(isolate, context);
    ffi.v8_WebAssembly_InstallAddressDescriptors(isolate, context);
    // Entered while it is made, and left at the end - it is entered for
    // each call that runs in it. A failure undoes it in createWindowRealm's
    // order: the realm, the global (a reused proxy is left with none, as
    // after the hand-on alone), the entry, the handle.
    ffi.v8_Context_Enter(context);
    var registered = false;
    errdefer {
        if (registered) context_manager.removeContext(context);
        if (reused_proxy != null) ffi.v8_Context_DetachGlobal(context);
        ffi.v8_Context_Exit(context);
        ffi.v8_Context_Dispose(context);
    }

    // The realm, on the agent's record of its realms, with the main realm's
    // timers and event loop.
    const realm = context_manager.getOrCreateWithExternalEventLoop(context, main.timer, main.event_loop, allocator) catch
        return error.OperationFailed;
    registered = true;
    const entry = context_manager.getEntry(context) orelse return error.OperationFailed;
    entry.world = world;
    // Its cache is a world cache: node wrappers are kept in it, beside the
    // node's own slot, which is the main world's.
    if (realm.getV8WrapperCacheStorage()) |storage| {
        const cache: *WrapperCache = @ptrCast(@alignCast(storage));
        cache.world = true;
    }
    // The main realm's settings, Browser and loop: the world has none of its
    // own (Blink: an isolated world's ScriptState shares the frame's
    // ExecutionContext).
    realm.browser_scope = main.browser_scope;
    realm.secure_context = main.secure_context;
    realm.task_sink = main.task_sink;
    realm.principal_realm = main;

    if (!restored) interface_bindings.installSnapshotIntrinsics(isolate, context);
    interface_bindings.installConditionalConstructs(.Window, context);
    interface_bindings.registerNamespacesGeneric(namespaces, isolate, context);
    shared_array_buffer_exposure.apply(isolate, context, facts.cross_origin_isolated);

    // The main realm's Window, bound to this global (BORROWED by the
    // binding, which the world cache's entry adopts).
    const global = ffi.v8_Context_Global(context) orelse return error.OperationFailed;
    ffi.v8_Object_SetAlignedPointerInInternalField(global, 0, null);
    protocol_realms.bindWindowToGlobal(isolate, context, realm, global, facts.window, allocator);

    // The main realm's window operations (timers, animation frames), as a
    // frame takes its parent's.
    page_realm.defineOnFrame(isolate, context, realm, main);

    const key = context_manager.keyOf(context) orelse return error.OperationFailed;
    state.* = .{ .realm = realm, .main = main, .world = world, .context = context, .key = key, .window = facts.window };
    worlds.realms.put(std.heap.c_allocator, realm, state) catch return error.OutOfMemory;
    errdefer _ = worlds.realms.remove(realm);
    const by_main = worlds.by_main.getOrPut(std.heap.c_allocator, main) catch return error.OutOfMemory;
    if (!by_main.found_existing) by_main.value_ptr.* = .empty;
    by_main.value_ptr.append(std.heap.c_allocator, state) catch return error.OutOfMemory;
    noteActive(worlds, isolate, main);
    ffi.v8_Context_Exit(context);

    if (worlds.observer) |observer| observer.created(worlds.observer_host, realm);
    return realm;
}

/// The agent has a world realm: its Browser's conversions ask the world,
/// and its collections' walks visit world wrappers.
fn noteActive(worlds: *AgentWorlds, isolate: *ffi.Isolate, main: Context) void {
    if (main.browserScope()) |scope| scope.isolated_worlds_active.store(true, .monotonic);
    if (worlds.active) return;
    worlds.active = true;
    node_wrappers.noteWorlds(isolate, worlds);
}

/// The WindowProxy a navigation kept for `main`'s `world`, taken - OWNED -
/// or null.
fn takeHandedProxy(worlds: *AgentWorlds, main: Context, world: WorldId) ?*ffi.Object {
    const list = worlds.handed.getPtr(main) orelse return null;
    for (list.items, 0..) |handed, i| {
        if (handed.world != world) continue;
        _ = list.swapRemove(i);
        return handed.proxy;
    }
    return null;
}

/// A navigation made `new_main` around `old_main`'s WindowProxy
/// (WindowRealmOptions.global_this = window_proxy_of): each world's
/// WindowProxy of `old_main` goes on too - its native info cleared and its
/// global detached, as the main world's (realm_global.handOn, Blink's
/// DisposeContext(kFrameWillBeReused) for every world) - and waits for the
/// next world realm made for that world under `new_main`. Called by
/// protocol_realms.createWindowRealm once `new_main` is recorded.
pub fn handOnWorldProxies(old_main: Context, new_main: Context) void {
    const worlds = worldsOfRealm(old_main) orelse return;
    if (!worlds.active) return;
    const list = worlds.by_main.get(old_main) orelse return;
    if (list.items.len == 0) return;
    const handed = worlds.handed.getOrPut(std.heap.c_allocator, new_main) catch return;
    if (!handed.found_existing) handed.value_ptr.* = .empty;
    for (list.items) |w| {
        if (w.window_proxy_handed_on) continue;
        handed.value_ptr.ensureUnusedCapacity(std.heap.c_allocator, 1) catch return;
        if (!isLive(w.context)) continue;
        const proxy = ffi.v8_Context_Global(w.context) orelse continue;
        realm_global.handOn(w.context);
        ffi.v8_Context_DetachGlobal(w.context);
        w.window_proxy_handed_on = true;
        handed.value_ptr.appendAssumeCapacity(.{ .world = w.world, .proxy = proxy });
    }
}

// ============================================================================
// Ending world realms
// ============================================================================

/// engine.destroyWorldRealms: every world realm of `main` ends - the most
/// recent first - and the WindowProxies kept for them are let go. Implied by
/// the end and the detach of `main` (protocol_realms).
pub fn destroyWorldRealms(main: Context) void {
    const worlds = worldsOfRealm(main) orelse return;
    if (!worlds.active) return;
    while (true) {
        const list = worlds.by_main.getPtr(main) orelse break;
        const w = list.pop() orelse {
            list.deinit(std.heap.c_allocator);
            _ = worlds.by_main.remove(main);
            break;
        };
        endWorldRealm(worlds, w);
    }
    if (worlds.handed.fetchRemove(main)) |kv| {
        var proxies = kv.value;
        for (proxies.items) |handed| ffi.v8_Object_Dispose(handed.proxy);
        proxies.deinit(std.heap.c_allocator);
    }
}

/// A context handle that still reaches its context.
fn isLive(context: *ffi.Context) bool {
    return !ffi.v8_Global_IsEmpty(@ptrCast(context));
}

/// The end of one world realm (Blink's LocalWindowProxy::DisposeContext for
/// an isolated world): the observer told, its window operations ended, the
/// callbacks its script registered let go weak, its global severed from the
/// Window - which stays: it is the main realm's - its realm retired by the
/// context manager (its wrapper cache's end lets go of every wrapper and of
/// the counted references its node wrappers held), V8 told, its handle
/// released. `w` is off the main realm's list already.
fn endWorldRealm(worlds: *AgentWorlds, w: *WorldRealm) void {
    defer std.heap.c_allocator.destroy(w);
    if (worlds.observer) |observer| observer.destroyed(worlds.observer_host, w.realm);
    _ = worlds.realms.remove(w.realm);
    const realm = w.realm;
    const context = w.context;
    const isolate = isolateOf(realm);

    // Its window operations end: nothing reaches the host's timer steps
    // through it again. Its timers and animation frames are its main
    // realm's Window's (page_realm.receiverWindowRealm), which end with that
    // Window - never the Window's own end here (WindowOperations.
    // windowDestroyed runs the Window's unloading cleanup steps, which a
    // world realm does not own).
    page_realm.endWindowOperations(realm);

    if (isLive(context)) {
        // The callbacks this realm's script registered on objects - the
        // page's nodes' listeners included - tagged with its key: kept from
        // its retained store and made weak (protocol_realms.endRealm's
        // rule), so a listener closing over the world does not keep it.
        if (realm_global.retainedStore(realm)) |store| {
            defer ffi.v8_Global_Dispose(store);
            _ = ffi.v8_Object_WeakenTaggedHandles(store, w.key, retained_key.ptr, retained_key.len);
        }
        // The global names the Window no more: a world function script
        // still holds finds no Window, not one the main realm freed.
        if (!w.window_proxy_handed_on) realm_global.clearInstance(context, w.window);
    }

    // The realm: its cache lets go of its wrappers (a node wrapper's
    // reference with it), its Window's entry is taken out and the Window
    // left to its main realm (ContextEntry.world), and the entry retired.
    context_manager.removeContextByKey(w.key);

    if (isLive(context)) {
        if (isolate) |iso| ffi.v8_Isolate_ContextDisposedNotification(iso, context, true);
    }
    ffi.v8_Context_Dispose(context);
}

/// The agent ends: its world realms ended with their main realms (or with
/// the agent's realms, context_manager.endAgentRealms -> `endAllOfAgent`);
/// what is left of the record goes.
pub fn endAgent(isolate: *ffi.Isolate, worlds: *AgentWorlds) void {
    node_wrappers.noteWorlds(isolate, null);
    if (worlds.realms.count() != 0) log.err("the agent ended with {d} world realm(s) still alive", .{worlds.realms.count()});
    var lists = worlds.by_main.valueIterator();
    while (lists.next()) |list| list.deinit(std.heap.c_allocator);
    worlds.by_main.deinit(std.heap.c_allocator);
    var proxies = worlds.handed.valueIterator();
    while (proxies.next()) |list| {
        for (list.items) |handed| ffi.v8_Object_Dispose(handed.proxy);
        list.deinit(std.heap.c_allocator);
    }
    worlds.handed.deinit(std.heap.c_allocator);
    var definitions = worlds.definitions.valueIterator();
    while (definitions.next()) |definition| std.heap.c_allocator.free(definition.name);
    worlds.definitions.deinit(std.heap.c_allocator);
    var states = worlds.realms.valueIterator();
    while (states.next()) |state| std.heap.c_allocator.destroy(state.*);
    worlds.realms.deinit(std.heap.c_allocator);
    worlds.* = .{};
}

/// Every world realm of the agent ends - before its realms do
/// (context_manager.endAgentRealms): a world realm's Window is its main
/// realm's, which the agent's end frees.
pub fn endAllOfAgent(isolate: *ffi.Isolate) void {
    const worlds = protocol_agents.worldsOf(isolate) orelse return;
    if (!worlds.active) return;
    while (true) {
        var mains = worlds.by_main.keyIterator();
        const main = (mains.next() orelse break).*;
        destroyWorldRealms(main);
    }
}

// ============================================================================
// The walk and node teardown
// ============================================================================

/// The walk named `instance`'s node (engine.traceNodeWrapper, in a
/// collection's atomic pause): its wrapper in each world realm of its
/// relevant realm is kept too - Blink's DOMDataStore for a non-main world is
/// an ephemeron table keyed by the object, so a world's wrapper lives while
/// the walk keeps the object's tree. Read-only; no allocation; no V8 call but
/// the visitor's.
pub fn traceWorldWrappers(worlds: *const AgentWorlds, instance: *engine.Instance, visitor: *anyopaque) void {
    const list = worlds.by_main.get(instance.ctx) orelse return;
    for (list.items) |w| {
        const storage = w.realm.getV8WrapperCacheStorage() orelse continue;
        const cache: *const WrapperCache = @ptrCast(@alignCast(storage));
        cache.traceWorldEntry(instance, visitor);
    }
}

/// `instance`, a node, was torn down while wrappers of it may live (a forced
/// realm end's coordinated teardown: context_manager.markInstanceCleanedUp):
/// each world realm's wrapper of it is severed and its reference forgotten,
/// as node_wrappers.nodeDestroyed does for the main world's.
pub fn nodeDestroyed(instance: *engine.Instance) void {
    const worlds = worldsOfRealm(instance.ctx) orelse return;
    if (!worlds.active) return;
    const list = worlds.by_main.get(instance.ctx) orelse return;
    for (list.items) |w| {
        const storage = w.realm.getV8WrapperCacheStorage() orelse continue;
        const cache: *WrapperCache = @ptrCast(@alignCast(storage));
        cache.worldNodeDestroyed(instance);
    }
}
