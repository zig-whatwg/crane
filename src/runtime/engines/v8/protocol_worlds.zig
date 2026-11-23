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
//! - A reachable world wrapper of a node keeps its tree: it is bound to a
//!   holder anchor whose trace walks from its node (platform_anchor.
//!   bindInWorld, node_wrappers.traceHolder), as a reached NodeAnchor does.
//! - A world's timers are its Window's - one map of active timers - and run
//!   in the world: the host is handed the world realm and keeps the map on
//!   its main realm (browser/Context.zig TimerMap), so a string handler is
//!   compiled in the world and a callback's this is the world's WindowProxy.
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
const tombstones = @import("webidl").utils.tombstones;
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
    /// The world's own policy (engine.WorldRealmOptions.
    /// content_security_policy), OWNED (c_allocator); null: the page's.
    content_security_policy: ?[]u8 = null,
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
    /// The promises and FrozenArrays of other worlds this realm's own for
    /// them is kept on (`mirrorPromise`, `mirrorFrozenArray`), as WEAK handles OWNED: each mirror is taken off its
    /// source at the realm's end (`dropMirrors`), so a source that outlives
    /// the realm keeps nothing of it alive. Handles whose source was
    /// collected are swept as the list grows (`mirrored_sweep_at`).
    mirrored: std.ArrayListUnmanaged(*ffi.Value) = .empty,
    mirrored_sweep_at: usize = 16,
    /// Its promises for other worlds' promises still to settle (`Mirror`),
    /// cut at its end (`dropMirrors`): their reactions are the source
    /// realms', and must hold nothing of this realm after it.
    pending: std.ArrayListUnmanaged(*Mirror) = .empty,
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
    /// Bound `realms`', `by_main`'s and `handed`'s tombstones: their keys
    /// are realms, and a page's main realm and its world realms are made
    /// and ended with every navigation for the agent's life
    /// (infra.tombstones.TombstoneGuard; tools/lint_tombstones.zig).
    realms_guard: tombstones.TombstoneGuard = .{},
    by_main_guard: tombstones.TombstoneGuard = .{},
    handed_guard: tombstones.TombstoneGuard = .{},
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

/// Whether `isolate`'s agent has made a world realm (`noteActive` tells its
/// node wrapper registry): one call into the isolate's record, no lock - the
/// gate of a conversion with no realm at hand (conversions.memberAcrossWorlds).
pub fn agentHasWorlds(isolate: *ffi.Isolate) bool {
    const registry = node_wrappers.registryOf(isolate) orelse return false;
    return registry.worlds != null;
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
    const policy: ?[]u8 = if (options.content_security_policy) |text| std.heap.c_allocator.dupe(u8, text) catch return error.OutOfMemory else null;
    errdefer if (policy) |p| std.heap.c_allocator.free(p);
    const definition: Definition = .{ .name = name, .universal_access = options.universal_access, .content_security_policy = policy };
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

/// engine.worldOf: no lookup, no lock, for a realm of a Browser that made
/// no world (`realmMayHaveWorlds`) - the host asks it on hot paths (its
/// timer map).
pub fn worldOf(realm: Context) WorldId {
    if (!realmMayHaveWorlds(realm)) return engine.main_world;
    const w = stateOf(realm) orelse return engine.main_world;
    return w.world;
}

/// engine.mainRealmOf, as cheap as `worldOf` without worlds.
pub fn mainRealmOf(realm: Context) Context {
    if (!realmMayHaveWorlds(realm)) return realm;
    const w = stateOf(realm) orelse return realm;
    return w.main;
}

/// engine.worldInfoOf.
pub fn worldInfoOf(realm: Context) ?engine.WorldInfo {
    // No lookup for a Browser that made no world: the host asks on every
    // eval's code generation check.
    if (!realmMayHaveWorlds(realm)) return null;
    const worlds = worldsOfRealm(realm) orelse return null;
    const w = worlds.realms.get(realm) orelse return null;
    const definition = worlds.definitions.get(w.world) orelse return .{ .world = w.world, .name = "", .universal_access = false, .main = w.main };
    return .{
        .world = w.world,
        .name = definition.name,
        .universal_access = definition.universal_access,
        .content_security_policy = definition.content_security_policy,
        .main = w.main,
    };
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
    const context: *ffi.Context = blk: {
        if (facts.from_snapshot and @import("protocol.zig").capabilities.restores_snapshots != .unsupported) {
            const made = if (reused_proxy) |proxy|
                ffi.v8_Context_NewFromSnapshotWithGlobal(isolate, proxy)
            else
                ffi.v8_Context_NewFromSnapshot(isolate);
            if (made) |c| break :blk c;
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
    // Kept after the realm ends (runtime.ContextData.world).
    realm.world = world;

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
    worlds.realms_guard.beforeInsert(&worlds.realms);
    worlds.realms.put(std.heap.c_allocator, realm, state) catch return error.OutOfMemory;
    errdefer {
        _ = worlds.realms.remove(realm);
        worlds.realms_guard.noteRemoval(&worlds.realms);
    }
    worlds.by_main_guard.beforeInsert(&worlds.by_main);
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
    worlds.handed_guard.beforeInsert(&worlds.handed);
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
    destroyWorldRealmsIn(worlds, main);
}

/// `destroyWorldRealms` on the agent's record: `main` leaves `by_main` and
/// `handed` whatever its world realms' ends do.
fn destroyWorldRealmsIn(worlds: *AgentWorlds, main: Context) void {
    while (true) {
        const list = worlds.by_main.getPtr(main) orelse break;
        const w = list.pop() orelse {
            list.deinit(std.heap.c_allocator);
            _ = worlds.by_main.remove(main);
            worlds.by_main_guard.noteRemoval(&worlds.by_main);
            break;
        };
        endWorldRealm(worlds, w);
    }
    if (worlds.handed.fetchRemove(main)) |kv| {
        worlds.handed_guard.noteRemoval(&worlds.handed);
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
    if (worlds.realms.remove(w.realm)) worlds.realms_guard.noteRemoval(&worlds.realms);
    const realm = w.realm;
    const context = w.context;
    const isolate = isolateOf(realm);

    // Its timers and animation frame callbacks end - the ones it set, in
    // its Window's map (the host tells a world realm from its main realm by
    // engine.worldOf and ends only the world's: browser/Context.zig) - then
    // its window operations: nothing reaches the host's steps through it
    // again.
    page_realm.frameWindowDestroyed(realm);
    page_realm.endWindowOperations(realm);

    // Its promises for other worlds' promises are taken off them.
    dropMirrors(w);

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
    while (definitions.next()) |definition| {
        std.heap.c_allocator.free(definition.name);
        if (definition.content_security_policy) |policy| std.heap.c_allocator.free(policy);
    }
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
    while (true) {
        var mains = worlds.by_main.keyIterator();
        const main = (mains.next() orelse break).*;
        destroyWorldRealmsIn(worlds, main);
    }
    // Proxies kept for a main realm that never made its world realms again.
    while (true) {
        var mains = worlds.handed.keyIterator();
        const main = (mains.next() orelse break).*;
        destroyWorldRealmsIn(worlds, main);
    }
}

// ============================================================================
// Values across worlds
// ============================================================================

/// JavaScript null, as a value to hand back (V8's null is a root: it is
/// never absent).
fn jsNull(isolate: *ffi.Isolate) *ffi.Value {
    return ffi.v8_Null(isolate) orelse unreachable;
}

/// `value`, about to reach script of the realm whose context is `context` -
/// a JSValue an impl hands back (an attribute's, an operation's: a value it
/// stored, a traced value) or a callback's argument - as a value of that
/// realm's world (engine section 4.2a): Blink's WorldSafeV8Reference::
/// GetAcrossWorld (third_party/blink/renderer/platform/bindings/
/// world_safe_v8_reference.h and .cc, ToWorldSafeValue; BSD-3 - reproduced,
/// not copied), so no object of one world reaches another's script:
/// - a primitive is every world's: kept;
/// - an object made in the target realm's world: kept;
/// - a platform object of another world: the target world's wrapper of the
///   same instance (one object, a wrapper per world);
/// - a promise of another world: the target world's promise for it, settled
///   with the value across worlds (`mirrorPromise`: Blink's
///   ScriptPromiseProperty keeps a promise per world);
/// - any other object of another world: structured-cloned into the target
///   realm - and null when it cannot be (a function, a symbol inside), as
///   Blink's serialization swallows the exception and answers null (`Clone`).
/// The worlds are compared - the value's creation context's against the
/// target context's - before any conversion work. OWNED: a new handle; null
/// when `value` is kept as it is.
///
/// THE FAST PATH is the callers': they ask only for a `.handle` value of a
/// realm whose Browser made an isolated world (`realmMayHaveWorlds`: two
/// loads, no lookup), so a page with no world pays one predictable branch.
pub fn acrossWorlds(isolate: *ffi.Isolate, value: *ffi.Value, context: *ffi.Context) ?*ffi.Value {
    if (!ffi.v8_Value_IsObject(value)) return null;
    // The worlds first: the common case - the value is the target world's
    // own - does no conversion work.
    const target_world = worldOfContext(context);
    const creation = ffi.v8_Object_GetCreationContext(@ptrCast(value)) orelse return null;
    defer ffi.v8_Context_Dispose(creation);
    const source_world = worldOfContext(creation);
    if (source_world == target_world) return null;

    // A platform object: its wrapper in the target world.
    if (@import("platform_anchor.zig").instanceOf(@ptrCast(value))) |raw| {
        const instance: *engine.Instance = @ptrCast(@alignCast(raw));
        const wrapper = @import("conversions.zig").instanceToV8InWorld(isolate, instance, target_world) catch return jsNull(isolate);
        // An undefined is the conversion's own (no wrapper there): owned.
        if (ffi.v8_Value_IsUndefined(wrapper)) return wrapper;
        return ffi.v8_Global_Clone(wrapper) orelse jsNull(isolate);
    }

    // A promise: the target world's own promise for it (`mirrorPromise`) -
    // a structured clone cannot carry one.
    if (ffi.v8_Value_IsPromise(value)) {
        const source_realm = context_manager.get(creation) orelse return jsNull(isolate);
        return mirrorPromise(isolate, value, source_realm, context);
    }

    // Any other object: a structured clone into the target realm, its
    // exceptions swallowed (`Clone`).
    var clone: Clone = .{
        .source_realm = context_manager.get(creation) orelse return jsNull(isolate),
        .target_realm = context_manager.get(context) orelse return jsNull(isolate),
        .value = value,
    };
    var exception: ?*ffi.Value = null;
    _ = ffi.v8_RunCatching(isolate, Clone.run, &clone, &exception);
    if (exception) |thrown| ffi.v8_Global_Dispose(thrown);
    return clone.result orelse jsNull(isolate);
}

/// `value`, the array a FrozenArray<T> attribute's getter returned - the
/// binding knows the IDL type at compile time (codegen's
/// `Meta.frozen_array_attributes`, binding_plumbing.finishGetter) - as script
/// of `context`'s realm reads it: an array of another world becomes that
/// realm's own frozen array of the same elements, each across worlds
/// (`acrossWorlds`: a node or a port is its wrapper there). Blink's
/// FrozenArray makes its JS array per world (third_party/blink/renderer/
/// bindings/core/v8/frozen_array_base.cc, FrozenArrayBase::ToV8; BSD-3 -
/// reproduced, not copied). One per (array, world realm), kept on the array
/// as a promise's mirror is (`keepMirror`; taken off at the realm's end):
/// the world reads one array until the attribute's value changes - the
/// impl hands out a new array - as the page does. A value that is no array
/// goes as `acrossWorlds` takes it. OWNED; null when `value` is kept as it is.
pub fn frozenArrayAcrossWorlds(isolate: *ffi.Isolate, value: *ffi.Value, context: *ffi.Context) ?*ffi.Value {
    if (!ffi.v8_Value_IsArray(value)) return acrossWorlds(isolate, value, context);
    const target_world = worldOfContext(context);
    const creation = ffi.v8_Object_GetCreationContext(@ptrCast(value)) orelse return null;
    defer ffi.v8_Context_Dispose(creation);
    if (worldOfContext(creation) == target_world) return null;
    return mirrorFrozenArray(isolate, value, creation, context);
}

/// `frozenArrayAcrossWorlds`'s array for `context`'s realm: kept (a world
/// realm's), or made - each element of `source` across worlds, then frozen
/// (WebIDL 3.2.36: "SetIntegrityLevel(array, "frozen")").
fn mirrorFrozenArray(isolate: *ffi.Isolate, source: *ffi.Value, source_context: *ffi.Context, context: *ffi.Context) *ffi.Value {
    const target_realm = context_manager.get(context) orelse return jsNull(isolate);
    const state = stateOf(target_realm);
    var key_buffer: [48]u8 = undefined;
    const key: ?[]const u8 = if (state) |w| mirrorKey(&key_buffer, w) else null;
    if (key) |k| if (ffi.v8_Object_GetPrivateRef(@ptrCast(source), k.ptr, @intCast(k.len))) |kept| {
        if (madeIn(kept, context)) return kept;
        ffi.v8_Global_Dispose(kept);
    };
    const length = ffi.v8_Array_Length(@ptrCast(source));
    const array = ffi.v8_Array_NewInContext(context, @intCast(length)) orelse return jsNull(isolate);
    const made: *ffi.Value = @ptrCast(array);
    var index: u32 = 0;
    while (index < length) : (index += 1) {
        const element = ffi.v8_Array_Get(source_context, @ptrCast(source), index) orelse {
            ffi.v8_Global_Dispose(made);
            return jsNull(isolate);
        };
        defer ffi.v8_Global_Dispose(element);
        const across = acrossWorlds(isolate, element, context);
        defer if (across) |converted| ffi.v8_Global_Dispose(converted);
        if (!ffi.v8_Array_Set(array, context, index, across orelse element)) {
            ffi.v8_Global_Dispose(made);
            return jsNull(isolate);
        }
    }
    if (!ffi.v8_Object_Freeze(@ptrCast(array), context)) {
        ffi.v8_Global_Dispose(made);
        return jsNull(isolate);
    }
    if (state) |w| keepMirror(w, source, key.?, made);
    return made;
}

/// `acrossWorlds`'s structured clone of `value` from `source_realm` into
/// `target_realm`, run under a TryCatch: what cannot be cloned - a function,
/// a node inside, a getter that throws - answers null with nothing left
/// pending, as Blink's SerializedScriptValue::SerializeAndSwallowExceptions
/// does for WorldSafeV8Reference.
const Clone = struct {
    source_realm: Context,
    target_realm: Context,
    value: *ffi.Value,
    result: ?*ffi.Value = null,

    fn run(data: ?*anyopaque) callconv(.c) void {
        const self: *Clone = @ptrCast(@alignCast(data.?));
        const protocol = @import("protocol.zig");
        const bytes = protocol.structuredSerializeForStorage(self.source_realm, .{ .handle = .{ .ptr = self.value } }, std.heap.c_allocator) catch return;
        defer std.heap.c_allocator.free(bytes);
        const cloned = protocol.structuredDeserialize(self.target_realm, bytes) catch return;
        switch (cloned.value) {
            .handle => |h| self.result = @ptrCast(@alignCast(h.ptr)),
            else => cloned.release(),
        }
    }
};

/// The target world's promise for `source`, a promise of another world:
/// Blink's ScriptPromiseProperty, which keeps one promise per world and
/// settles each with the value as that world sees it (third_party/blink/
/// renderer/bindings/core/v8/script_promise_property.h, ScriptPromiseProperty
/// ::Promise(DOMWrapperWorld&); BSD-3 - reproduced, not copied).
///
/// For a world realm, one per (promise, realm): kept on `source` under a
/// private key naming the realm, so the world reads one promise every time
/// (`document.fonts.ready === document.fonts.ready` in a world too). Nothing
/// of `source` keeps the world realm once it ends (`dropMirrors`): the kept
/// promise is taken off every source still alive, and the reaction that
/// settles it - made in `source_realm`, so its functions are the source
/// world's - lets go of the world's resolver (`Mirror.resolver`). A main
/// realm reading a world's promise (one a world stored in a page object) is
/// handed a new one each read, its reaction the main realm's.
///
/// Marked handled: a rejection is reported once, by `source`'s own realm.
/// OWNED; null when it cannot be made.
fn mirrorPromise(isolate: *ffi.Isolate, source: *ffi.Value, source_realm: Context, context: *ffi.Context) *ffi.Value {
    const target_realm = context_manager.get(context) orelse return jsNull(isolate);
    const state = stateOf(target_realm);
    var key_buffer: [48]u8 = undefined;
    const key: ?[]const u8 = if (state) |w| mirrorKey(&key_buffer, w) else null;
    if (key) |k| if (ffi.v8_Object_GetPrivateRef(@ptrCast(source), k.ptr, @intCast(k.len))) |kept| {
        // Made in this realm (`madeIn`: a guard - the key names the realm,
        // and the realm's end deletes it).
        if (madeIn(kept, context)) return kept;
        ffi.v8_Global_Dispose(kept);
    };
    const resolver = ffi.v8_PromiseResolver_New(context) orelse return jsNull(isolate);
    const promise: *ffi.Value = @ptrCast(ffi.v8_PromiseResolver_GetPromise(resolver) orelse {
        ffi.v8_PromiseResolver_Dispose(resolver);
        return jsNull(isolate);
    });
    ffi.v8_Promise_MarkAsHandled(promise);
    const mirror = Mirror.allocator.create(Mirror) catch {
        ffi.v8_PromiseResolver_Dispose(resolver);
        ffi.v8_Global_Dispose(promise);
        return jsNull(isolate);
    };
    mirror.* = .{ .resolver = resolver, .realm = target_realm };
    // A world realm's: on its pending list, to be cut at its end. No room:
    // no mirror.
    if (state) |w| w.pending.append(std.heap.c_allocator, mirror) catch {
        mirror.release();
        ffi.v8_Global_Dispose(promise);
        return jsNull(isolate);
    };
    if (state) |w| mirror.index = w.pending.items.len - 1;
    // The reaction: the source's realm's for a world realm's mirror (its
    // functions hold nothing of the world), the target's otherwise. Fails
    // only when that realm's end is under way: no mirror then, and what it
    // holds is freed here (`data` stays the caller's).
    const reaction_realm = if (state != null) source_realm else target_realm;
    @import("protocol_promises.zig").reactToPromise(reaction_realm, .{ .handle = .{ .ptr = source } }, &Mirror.steps, mirror) catch {
        mirror.release();
        ffi.v8_Global_Dispose(promise);
        return jsNull(isolate);
    };
    if (state) |w| keepMirror(w, source, key.?, promise);
    return promise;
}

/// The private key `w`'s value for another world's - its promise for a
/// promise, its frozen array for a FrozenArray - is kept under on it: one per
/// realm (the context manager's key, unique while the realm lives,
/// and deleted from every source at its end).
fn mirrorKey(buffer: *[48]u8, w: *const WorldRealm) []const u8 {
    return std.fmt.bufPrint(buffer, "crane:world-mirror:{x}", .{w.key}) catch unreachable;
}

/// Keep `kept`, `w`'s value for `source` (`mirrorKey`), on `source` under `key` -
/// and a weak handle of `source` on `w`, to take it off at `w`'s end. When
/// there is no room for the handle the promise is not kept (the next read
/// makes another).
fn keepMirror(w: *WorldRealm, source: *ffi.Value, key: []const u8, kept: *ffi.Value) void {
    const weak = ffi.v8_Global_Clone(source) orelse return;
    w.mirrored.append(std.heap.c_allocator, weak) catch {
        ffi.v8_Global_Dispose(weak);
        return;
    };
    ffi.v8_Global_SetWeak(@ptrCast(weak), null, noteSourceCollected);
    ffi.v8_Object_SetPrivateRef(@ptrCast(source), key.ptr, @intCast(key.len), kept);
    if (w.mirrored.items.len < w.mirrored_sweep_at) return;
    // The sources the collector took: their handles are empty.
    var i: usize = 0;
    while (i < w.mirrored.items.len) {
        if (ffi.v8_Global_IsEmpty(w.mirrored.items[i])) {
            ffi.v8_Global_Dispose(w.mirrored.swapRemove(i));
        } else i += 1;
    }
    w.mirrored_sweep_at = @max(16, w.mirrored.items.len * 2);
}

/// A kept mirror's source was collected: its handle is empty now, swept by
/// `keepMirror` or disposed at the realm's end. (V8's first pass: nothing
/// may be done here.)
fn noteSourceCollected(data: ?*anyopaque, length_in_bytes: usize) callconv(.c) void {
    _ = data;
    _ = length_in_bytes;
}

/// `w` ends: nothing of another world's promise keeps it alive after. Its
/// promise kept on each source still alive is taken off it - the private
/// edge deleted, in `w`'s context - and each mirror still pending lets go of
/// its resolver (`Mirror.cut`): the reaction, the source realm's, settles
/// or drops it later with nothing to do.
fn dropMirrors(w: *WorldRealm) void {
    for (w.pending.items) |mirror| mirror.cut();
    w.pending.deinit(std.heap.c_allocator);
    w.pending = .empty;
    defer {
        for (w.mirrored.items) |weak| ffi.v8_Global_Dispose(weak);
        w.mirrored.deinit(std.heap.c_allocator);
        w.mirrored = .empty;
    }
    if (w.mirrored.items.len == 0 or !isLive(w.context)) return;
    var key_buffer: [48]u8 = undefined;
    const key = mirrorKey(&key_buffer, w);
    ffi.v8_Context_Enter(w.context);
    defer ffi.v8_Context_Exit(w.context);
    for (w.mirrored.items) |weak| {
        if (!ffi.v8_Global_IsEmpty(weak)) ffi.v8_Object_DeletePrivateRef(@ptrCast(weak), key.ptr, @intCast(key.len));
    }
}

/// Whether `object`'s creation context is `context`.
fn madeIn(object: *ffi.Value, context: *ffi.Context) bool {
    const creation = ffi.v8_Object_GetCreationContext(@ptrCast(object)) orelse return false;
    defer ffi.v8_Context_Dispose(creation);
    const made = ffi.v8_Context_GetRawAddress(creation) orelse return false;
    const target = ffi.v8_Context_GetRawAddress(context) orelse return false;
    return made == target;
}

/// A world's promise for another world's (`mirrorPromise`): its resolver,
/// settled once by the reaction to the source. Freed when the reaction ends
/// (it settles, or is dropped); a world realm's is on the realm's `pending`
/// list until then, or until the realm's end cuts it.
const Mirror = struct {
    /// The target realm's resolver, OWNED; null once the target realm ended
    /// (`cut`).
    resolver: ?*ffi.PromiseResolver,
    /// The target realm: read only while `resolver` is set.
    realm: Context,
    /// Its place on its world realm's `pending` list; null for a main
    /// realm's mirror, which is on none.
    index: ?usize = null,

    const allocator = std.heap.c_allocator;
    const steps: engine.PromiseReactionSteps = .{ .fulfilled = fulfilled, .rejected = rejected, .dropped = dropped };

    fn fulfilled(data: ?*anyopaque, value: engine.JSValue) void {
        settle(@ptrCast(@alignCast(data.?)), value, false);
    }

    fn rejected(data: ?*anyopaque, reason: engine.JSValue) void {
        settle(@ptrCast(@alignCast(data.?)), reason, true);
    }

    /// The reaction's realm ended, or the source was collected, first: the
    /// world's promise stays pending.
    fn dropped(data: ?*anyopaque) void {
        const self: *Mirror = @ptrCast(@alignCast(data.?));
        self.release();
    }

    fn settle(self: *Mirror, value: engine.JSValue, is_rejection: bool) void {
        defer self.release();
        const resolver = self.resolver orelse return;
        const entered = @import("protocol_support.zig").enter(self.realm) catch return;
        defer entered.leave();
        const context = entered.context();
        const raw = @import("realm_entry.zig").EngineValue.of(entered.isolate, context, value) catch return;
        defer raw.release();
        // The value as the target world sees it.
        const across = acrossWorlds(entered.isolate, raw.ptr, context);
        defer if (across) |converted| ffi.v8_Global_Dispose(converted);
        const settled = across orelse raw.ptr;
        _ = if (is_rejection)
            ffi.v8_PromiseResolver_Reject(resolver, context, settled)
        else
            ffi.v8_PromiseResolver_Resolve(resolver, context, settled);
    }

    /// The target world realm ends (`dropMirrors`, which empties its list
    /// after): the resolver goes, and the reaction finds nothing to settle.
    fn cut(self: *Mirror) void {
        if (self.resolver) |resolver| ffi.v8_PromiseResolver_Dispose(resolver);
        self.resolver = null;
        self.index = null;
    }

    /// The end of the record: off its realm's list (the realm lives while
    /// the resolver is set), its resolver released.
    fn release(self: *Mirror) void {
        if (self.resolver) |resolver| {
            if (self.index) |index| if (stateOf(self.realm)) |w| {
                _ = w.pending.swapRemove(index);
                if (index < w.pending.items.len) w.pending.items[index].index = index;
            };
            ffi.v8_PromiseResolver_Dispose(resolver);
        }
        allocator.destroy(self);
    }
};

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

// ============================================================================
// Traced values across worlds (refcount step 8, option (c))
// ============================================================================
//
// engine.traceValues keeps an owner's set - its listeners' callbacks, an
// observer's callback, the observers a node lists - on the owner's wrapper,
// and an owner has a wrapper per world. Blink traces those values from the
// C++ object (EventTarget::Trace -> EventListenerMap ->
// TraceWrapperV8Reference; MutationObserverRegistration traced from its
// node), which ANY of its wrappers keeps alive, in any world. So here the set
// reaches every wrapper the owner has (`traceValuesInWorlds`), and a wrapper
// made later gets it drawn onto it (`drawTracedValuesOnWrap`): a page's
// EventTarget only a world still holds keeps the page's listener, and a
// world's closure over a node only the world wrapped is collected with it -
// the set no longer waits, strongly, for a main-world wrapper script may
// never make. (A NODE's wrappers already keep each other - each world's is a
// holder whose walk reaches every wrapper of its tree, `traceWorldWrappers` -
// but a node only one world wrapped has no other wrapper to hang the set on.)
// Main's ruling of 2026-11-23 11:53 AM ET (lane rc8).

/// `realm`'s wrapper cache, or null.
fn cacheOf(realm: Context) ?*WrapperCache {
    const storage = realm.getV8WrapperCacheStorage() orelse return null;
    return @ptrCast(@alignCast(storage));
}

/// Whether `cache` is `other`.
fn isCache(cache: *const WrapperCache, other: ?*const WrapperCache) bool {
    const that = other orelse return false;
    return cache == that;
}

/// Each wrapper `owner` has in its realm group - its main realm's and each
/// of its world realms' - but the one `except` keeps, handed to `visit`
/// BORROWED from its cache, until `visit` answers false. None for a Window:
/// its sets hang on its main realm's retained store
/// (protocol_realms.tracedEdgeHolderOfWindow), which outlives every world
/// realm of it. None while its agent has made no world realm.
fn eachOtherWrapper(owner: *engine.Instance, except: ?*const WrapperCache, context: anytype, comptime visit: fn (@TypeOf(context), *ffi.Object) bool) void {
    if (std.mem.eql(u8, owner.vtable.name, "Window")) return;
    const worlds = worldsOfRealm(owner.ctx) orelse return;
    if (!worlds.active) return;
    const main = mainRealmOf(owner.ctx);
    if (cacheOf(main)) |cache| {
        if (!isCache(cache, except) and !cache.is_tearing_down) {
            if (cache.get(owner)) |wrapper| {
                if (!visit(context, wrapper)) return;
            }
        }
    }
    const list = worlds.by_main.get(main) orelse return;
    for (list.items) |w| {
        const cache = cacheOf(w.realm) orelse continue;
        if (isCache(cache, except) or cache.is_tearing_down) continue;
        const wrapper = cache.get(owner) orelse continue;
        if (!visit(context, wrapper)) return;
    }
}

/// engine.traceValues across worlds: every wrapper `owner` has besides the
/// one in `own` (its own realm's cache, where protocol_tracing hangs the set)
/// keeps exactly `handles` (BORROWED) under `key` as well. Whether any did.
/// Each wrapper is held strongly while its set is made: making it allocates,
/// and a collection then must not take the wrapper the values hang on.
pub fn traceValuesInWorlds(owner: *engine.Instance, own: ?*const WrapperCache, key: []const u8, handles: []const ?*ffi.Value) bool {
    const Fan = struct {
        key: []const u8,
        handles: []const ?*ffi.Value,
        drawn: bool = false,

        fn visit(self: *@This(), wrapper: *ffi.Object) bool {
            const held = ffi.v8_Global_Clone(@ptrCast(wrapper)) orelse return true;
            defer ffi.v8_Global_Dispose(held);
            if (ffi.v8_Object_SetPrivateValues(@ptrCast(held), self.key.ptr, @intCast(self.key.len), self.handles.ptr, self.handles.len)) self.drawn = true;
            return true;
        }
    };
    var fan: Fan = .{ .key = key, .handles = handles };
    eachOtherWrapper(owner, own, &fan, Fan.visit);
    return fan.drawn;
}

/// `instance`'s wrapper `wrapper` (BORROWED, held by the caller) was just
/// made in `cache`: it keeps the sets `instance`'s other wrappers keep -
/// copied from the first one found, since every wrapper keeps the same sets
/// (`traceValuesInWorlds`) - or, with no other wrapper, takes the sets
/// waiting in its own realm's cache for a wrapper there
/// (WrapperCache.takeWaitingValues; when that cache is `cache`, its wrap drew
/// them already). The caller made sure a world realm may exist
/// (`realmMayHaveWorlds`).
pub fn drawTracedValuesOnWrap(cache: *const WrapperCache, instance: *engine.Instance, wrapper: *ffi.Object) void {
    const Copy = struct {
        to: *ffi.Object,
        copied: bool = false,

        fn visit(self: *@This(), from: *ffi.Object) bool {
            ffi.v8_Object_CopyTracedValues(from, self.to);
            self.copied = true;
            return false;
        }
    };
    var copy: Copy = .{ .to = wrapper };
    eachOtherWrapper(instance, cache, &copy, Copy.visit);
    if (copy.copied) return;
    if (std.mem.eql(u8, instance.vtable.name, "Window")) return;
    const own = cacheOf(instance.ctx) orelse return;
    if (isCache(own, cache) or own.is_tearing_down) return;
    own.takeWaitingValues(instance, wrapper);
}

/// engine.hasWrapper beyond `instance`'s own realm: whether another realm of
/// its group - a world realm's cache, or its main realm's for an instance of
/// a world realm - has a wrapper of it. The caller made sure a world realm
/// may exist (`realmMayHaveWorlds`). A Window's other wrappers are its world
/// realms' globals, which it does not count: those realms end before its own.
pub fn hasWrapperInOtherWorld(instance: *engine.Instance) bool {
    const Found = struct {
        found: bool = false,

        fn visit(self: *@This(), _: *ffi.Object) bool {
            self.found = true;
            return false;
        }
    };
    var found: Found = .{};
    const own: ?*const WrapperCache = cacheOf(instance.ctx);
    eachOtherWrapper(instance, own, &found, Found.visit);
    return found.found;
}
