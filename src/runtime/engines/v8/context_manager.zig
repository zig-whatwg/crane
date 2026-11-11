//! V8 Context Manager
//!
//! Manages the mapping between V8 JavaScript contexts and WebIDL runtime contexts.
//! This bridge allows V8 callbacks to access WebIDL runtime services (logging, etc.)
//! without requiring global state.
//!
//! ## Architecture
//!
//! ```
//! V8 JavaScript Context
//!     ↓ (mapped via hash map)
//! Runtime Context (*ContextData)
//!     ↓ (contains)
//! - Logger (console.log, etc.)
//! - Allocator (memory management)
//! - Engine Context (back-reference to V8)
//! ```
//!
//! ## Per agent
//!
//! The map is each agent's own (`Realms`, a field of the agent's record,
//! protocol_agents.AgentRecord.realms): a context is looked up in the realms
//! of the agent whose isolate is current, which is the context's own - V8
//! reads a context with its isolate current. An agent's end ends its realms
//! (`endAgentRealms`) and no other agent's. Each isolate is used by one
//! thread at a time, so no lock.
//!
//! ## Usage
//!
//! ```zig
//! const mgr = @import("context_manager.zig");
//!
//! // A realm of the current agent, registered (engine.createWindowRealm and
//! // createWorkerRealm do this):
//! const realm = try mgr.getOrCreateWithExternalEventLoop(context, timer, loop, allocator);
//!
//! // In V8 callback:
//! fn constructorCallback(info: *const v8.FunctionCallbackInfo) callconv(.c) void {
//!     const isolate = info.getIsolate();
//!     const v8_ctx = v8.ffi.v8_Isolate_GetCurrentContext(isolate).?;
//!     const ctx = mgr.getOrCreate(v8_ctx, allocator) catch return;
//!
//!     // Now can use ctx for logging, allocation, etc.
//!     const instance = Interface.call_constructor( ctx) catch return;
//! }
//! ```

const std = @import("std");
const log = std.log.scoped(.v8_context);
const v8 = @import("ffi.zig");
const runtime = @import("runtime");
const V8EventLoop = @import("event_loop.zig").V8EventLoop;
const v8_engine = @import("engine.zig");
const fetch = @import("fetch");
const iface_bindings_mod = @import("interface_bindings.zig");
const helpers = @import("webidl").helpers;
const shadow_realm = @import("shadow_realm.zig");
/// The agent records, where each agent's realms live (`Realms`).
const protocol_agents = @import("protocol_agents.zig");
const tombstones = @import("webidl").utils.tombstones;
const host = @import("host");
const node_document = @import("dom").node_document;

/// Context mapping entry
pub const ContextEntry = struct {
    /// WebIDL global names are needed before the Realm/global object is
    /// recorded. installForScope sets this before materializing interfaces;
    /// Window contexts, including snapshot-restored ones, use the default.
    exposure_scope: helpers.GlobalScope = .Window,
    /// V8 context pointer (key)
    v8_ctx: *v8.Context,

    /// Runtime context data (owned)
    runtime_ctx: runtime.ContextData,

    /// Whether this entry owns the runtime context
    /// (and should deinit it when removed)
    owns_context: bool,

    /// Whether `v8_ctx` is this entry's own Global - a copy it took, or a
    /// context it created - rather than a handle its caller keeps and
    /// disposes. An owned handle is the last strong root of a destroyed page
    /// once the rest is released, so retiring the entry disposes it.
    owns_v8_ctx: bool = false,

    /// V8 event loop with timer support (owned if owns_context is true)
    event_loop: ?*V8EventLoop,

    /// Associated realm for this context (for cross-realm support)
    /// Each V8 context has its own realm with intrinsics, global object, etc.
    realm: ?*runtime.Realm,

    /// Parent context entry (for iframe hierarchy)
    /// Null for top-level/main contexts
    parent_entry: ?*ContextEntry,

    /// Child context entries (iframes, workers, etc.)
    /// Uses unmanaged ArrayList for Zig 0.15+ API
    children: std.ArrayListUnmanaged(*ContextEntry),

    /// Allocator used for this entry (needed for children list)
    allocator: std.mem.Allocator,

    /// Window instance for this context (for cross-realm support)
    /// This Window instance IS bound to the V8 global object, enabling
    /// `iframe.contentWindow.DOMRectReadOnly` to work correctly.
    /// Set during createChildContext() for iframe contexts.
    window_instance: ?*runtime.Instance = null,

    /// The realm global's GlobalAnchor (realm_global.attach; v8_wrapper.cpp
    /// GlobalAnchor), as Zig's weak reference to it: cleared before the
    /// realm's global instance is freed (removeContextByKey) and disposed
    /// when the entry is retired. Null for a realm whose global was never
    /// attached, and once retired.
    global_anchor: ?*v8.GlobalAnchorRef = null,

    // The realm's document URL lives on its runtime context
    // (runtime_ctx.document_url): realm state, not engine state.

    /// Set as destroyChildContext starts on this entry. Its teardown runs
    /// arbitrary deinit code - a Window, a DOM tree, iframe elements - and any
    /// of it can reach this entry again; the entry is retired, never freed,
    /// so the flag stays readable for the manager's lifetime.
    destroying: bool = false,
};

/// One agent's realms: the context manager's record of every context it
/// hosts for the agent, live and retired.
///
/// It is the agent's (protocol_agents.AgentRecord.realms), found from the
/// isolate - as Blink keeps an isolate's state on its V8PerIsolateData
/// (`V8PerIsolateData::From(isolate)`, one per isolate, a worker thread's
/// isolate its own) and WebKit on its VM's client data (JSVMClientData, which
/// the VM owns and which its worlds join and leave) - and the agent's end
/// ends it (`endAgentRealms`, isolate_lifecycle's first step): that agent's
/// realms, and no other agent's. It was a `threadlocal`, and the thread's
/// host agent - the one made with no isolate entered - took it down whole at
/// its end, the realms other agents on the thread had made with it
/// (tests/v8/agent_realms_isolation_test.zig; docs/instances.md: state has an
/// owner, never a thread).
///
/// Read and written on the agent's own thread only - an isolate is used by
/// one thread at a time - without a lock.
pub const Realms = struct {
    /// What the entries and both lists are allocated with: the agent's
    /// (engine.AgentOptions.allocator), set when the record is first asked
    /// for them (protocol_agents.realmsOf), or a test's (`useAllocator`).
    allocator: ?std.mem.Allocator = null,

    /// Map from the context's key (`keyOf`: its Crane id) to its entry.
    ///
    /// IMPORTANT: We store *ContextEntry (pointer) instead of ContextEntry (value)
    /// because HashMap moves values during rehash. If we stored values directly,
    /// any pointer into entry.runtime_ctx (like Window.ctx or Element.ctx)
    /// would become dangling after rehash. By heap-allocating entries and
    /// storing pointers, the entries themselves don't move when HashMap grows.
    contexts: std.AutoHashMapUnmanaged(usize, *ContextEntry) = .empty,
    /// Bounds `contexts`' tombstones: every realm an agent makes is put in
    /// and taken out again at its end, page after page, for the agent's
    /// life (infra.tombstones.TombstoneGuard).
    guard: tombstones.TombstoneGuard = .{},

    /// Entries taken out of `contexts` but not yet freed.
    ///
    /// Instances created in a context hold `ctx == &entry.runtime_ctx` - that is
    /// the whole reason entries are heap-allocated, per the note above. Neither
    /// `destroyChildContext` nor `removeContext` destroys those Instances; they
    /// are deliberately left for the slab's wholesale teardown. So freeing the
    /// entry underneath them left every one of them pointing at
    /// DebugAllocator-poisoned memory, where `_v8_wrapper_cache_storage` reads
    /// back as 0xAAAA_AAAA_AAAA_AAAA: non-null, and not 8-aligned, so
    /// `markInstanceCleanedUp` panicked in its `@alignCast` instead of quietly
    /// returning a wrong answer. Retiring the entry keeps every stale `ctx`
    /// pointing at a real, inert ContextData until the agent's end
    /// (`endAgentRealms`) drains this list.
    ///
    /// Costs one entry plus its ContextData's own buffers per destroyed context,
    /// for the lifetime of the agent. That is retention, not a leak - the drain
    /// frees all of it - and it buys away a class of use-after-free that no
    /// caller of `instance.ctx` can defend against on its own.
    retired: std.ArrayListUnmanaged(*ContextEntry) = .empty,

    /// Set while the agent's end tears its realms down (`endAgentRealms`).
    is_tearing_down: bool = false,

    fn alloc(self: *const Realms) std.mem.Allocator {
        return self.allocator orelse std.heap.c_allocator;
    }
};

/// The realms of the agent whose isolate is current: null with none current,
/// or for an isolate createAgent did not make, which hosts no realm. Every
/// lookup by context runs with the context's isolate current - reading a
/// context's key (v8_Context_GetRawAddress) does too.
fn currentRealms() ?*Realms {
    const isolate = v8.v8_Isolate_GetCurrent() orelse return null;
    return protocol_agents.realmsOf(isolate);
}

/// The agent's realms (`Realms`) allocate with `allocator` rather than the
/// agent's own: for a test that makes them run out of memory. Before the
/// agent's first realm only - error.AlreadyInitialized once anything was
/// allocated, error.NotAnAgent for an isolate createAgent did not make.
pub fn useAllocator(isolate: *v8.Isolate, allocator: std.mem.Allocator) !void {
    const realms = protocol_agents.realmsOf(isolate) orelse return error.NotAnAgent;
    if (realms.contexts.capacity() != 0 or realms.retired.capacity != 0) return error.AlreadyInitialized;
    realms.allocator = allocator;
}

/// The end of the agent whose isolate this is, for its realms: every realm
/// still on its record torn down, every retired entry freed, both lists'
/// storage freed - this agent's, and no other agent's on the thread. The
/// first step of the agent's end (isolate_lifecycle.cleanupAll, from
/// protocol_agents.endAgent), with the agent entered and its record still
/// found by `realmsOf` (ending), so that what the teardown looks up by
/// context is found as it ran. Nothing for an isolate createAgent did not
/// make.
///
/// Uses CleanupCoordinator to ensure proper ordering and prevent
/// race conditions between context teardown and GC-driven cleanup.
pub fn endAgentRealms(isolate: *v8.Isolate) void {
    const state = protocol_agents.realmsOf(isolate) orelse return;
    endRealms(state, protocol_agents.deferredTeardownOf(isolate));
}

/// `queue`: the agent's deferred teardown queue, drained before the realms'
/// records are freed (below).
fn endRealms(state: *Realms, queue: ?*runtime.gc.DeferredTeardown) void {
    // An agent that never hosted a realm has nothing to end.
    if (state.contexts.capacity() == 0 and state.retired.capacity == 0) return;
    log.debug("[context_manager.endRealms] {} live, {} retired", .{ state.contexts.count(), state.retired.items.len });
    const cleanup_coordinator = runtime.cleanup_coordinator;

    // Create coordinator for this teardown
    var coordinator = cleanup_coordinator.CleanupCoordinator.init(state.alloc());
    defer coordinator.deinit();

    // Set coordinator as active so GC callbacks can check teardown state,
    // and give the one it replaces back after (see removeContextByKey).
    const previous_coordinator = cleanup_coordinator.getActiveCoordinator();
    cleanup_coordinator.setActiveCoordinator(&coordinator);
    defer cleanup_coordinator.setActiveCoordinator(previous_coordinator);

    // Begin coordinated cleanup - signals GC callbacks to skip
    coordinator.beginContextCleanup();
    state.is_tearing_down = true;

    // Phase: Static Registries (cleanup before context-specific resources)
    // (The Intl objects' and ObservableArrays' states are the agent's:
    // protocol_agents.endAgent frees them.)
    coordinator.cleanupPhase(.static_registries);

    // Every realm still on the record - one its host never ended (a
    // ShadowRealm's context, a context a constructor registered, a test's) -
    // ends as a realm's own end ends it (`removeContextByKey`): its garbage
    // and orphans drained, its finalizers run (pending promise reactions,
    // live async iterators), the callbacks its script registered released,
    // its Window and tree, wrapper cache, event loop and realm record torn
    // down, and the entry retired - which disposes the entry's own context
    // handle. This path had a teardown of its own (the host agent's
    // context_manager.deinit) that skipped the drains, the finalizers and
    // the callbacks, and never disposed the context handle: one leaked
    // Global<Context> per realm, and the Globals those held (lane tstate1).
    // One realm at a time, from a fresh walk: an end can end others (its
    // frames) and takes its own entry out. A teardown that keeps making
    // realms is cut off rather than followed for ever.
    var budget = state.contexts.count() * 4 + 16;
    while (state.contexts.count() != 0) : (budget -= 1) {
        if (budget == 0) {
            log.err("an agent's end left {d} realm(s): their teardown kept making realms", .{state.contexts.count()});
            break;
        }
        var it = state.contexts.iterator();
        const kv = it.next().?;
        // Never through the context handle, which may be its maker's and
        // let go: the entry knows its Window and its global's anchor.
        removeContextByKey(kv.key_ptr.*);
    }

    // What the realms' ends left garbage - a node a platform object their
    // wrapper caches freed held counted (an event's target), whose tree that
    // release left with no hold - goes now, while every realm record its
    // nodes name is still here: since the wrapper redesign's P2 no realm end
    // frees a node whatever its count, so the counts' queue is the only way
    // these trees go (protocol_agents.endAgent closes it after this).
    if (queue) |q| q.drainAll();

    // Free the entries retired by each realm's end, the ones above
    // included. Held until the agent's end because Instances created in
    // those contexts may still point at `entry.runtime_ctx`; once the agent
    // has ended, none of its realms' Instances is read through one (a worker
    // on a thread of its own freed its retired entries at its end before
    // too, as that thread's host agent).
    coordinator.cleanupPhase(.context_data);
    for (state.retired.items) |entry| {
        if (entry.owns_context) entry.runtime_ctx.deinit();
        state.alloc().destroy(entry);
    }

    // Mark cleanup complete
    coordinator.endContextCleanup();

    // Free the lists' storage. The record goes right after this
    // (protocol_agents.removeAgent); until then it reads as an agent
    // with no realms. What a walk-out above left is freed unended.
    var left = state.contexts.valueIterator();
    while (left.next()) |entry| state.alloc().destroy(entry.*);
    state.retired.deinit(state.alloc());
    state.contexts.deinit(state.alloc());
    state.* = .{ .allocator = state.allocator };
}

/// Get or create a runtime context for the given V8 context
///
/// If a runtime context already exists for this V8 context, returns it.
/// Otherwise, creates a new runtime context with default options.
///
/// The returned context is valid until:
/// - removeContext() is called for this V8 context
/// - the agent ends (`endAgentRealms`)
///
/// On the agent's own thread (the current isolate's realms).
///
/// Arguments:
/// - v8_ctx: V8 context pointer
/// - allocator: Allocator to use for the runtime context (if created)
///
/// Returns: Runtime context pointer (borrowed, do not free)
pub fn getOrCreate(v8_ctx: *v8.Context, allocator: std.mem.Allocator) !runtime.Context {
    // For backwards compatibility, call with null isolate (no timer support)
    return getOrCreateWithIsolate(v8_ctx, null, allocator);
}

/// Get or create a runtime context with an external timer/event loop
///
/// Use this when you already have a V8EventLoop (e.g., in BrowserContext) and want
/// to share it with all runtime contexts. This ensures all timers use the same
/// libuv loop and are polled together.
///
/// Arguments:
/// - v8_ctx: V8 context pointer
/// - timer: External timer interface to use (optional)
/// - event_loop: External event loop interface to use (optional)
/// - allocator: Allocator for the runtime context
///
/// Returns: Runtime context pointer (borrowed, do not free)
pub fn getOrCreateWithExternalEventLoop(
    v8_ctx: *v8.Context,
    timer: ?runtime.TimerInterface,
    event_loop: ?@import("event_loop").EventLoop,
    allocator: std.mem.Allocator,
) !runtime.Context {
    const state = currentRealms() orelse return error.NotInitialized;

    // Use the raw V8 internal address as the key
    const raw_addr = v8.v8_Context_GetRawAddress(v8_ctx) orelse return error.InvalidContext;
    const key = @intFromPtr(raw_addr);

    // Check if context already exists
    if (state.contexts.get(key)) |entry| {
        return &entry.runtime_ctx;
    }

    // Create new runtime context with external timer/event loop
    var ctx_data = try runtime.ContextData.init(allocator, .{
        .colored = false,
        .show_timestamp = false,
        .show_labels = false,
        .engine_ctx = @ptrCast(v8_ctx),
        .timer = timer,
        .event_loop = event_loop,
    });
    errdefer ctx_data.deinit();

    // Initialize V8 wrapper cache for this context
    const WrapperCache = @import("wrapper_cache.zig").WrapperCache;
    const cache_ptr = try allocator.create(WrapperCache);
    errdefer allocator.destroy(cache_ptr);

    cache_ptr.* = try WrapperCache.init(allocator, v8_ctx);
    errdefer cache_ptr.deinit();

    // Store cache in runtime context
    ctx_data.setV8WrapperCacheStorage(@ptrCast(cache_ptr));
    // The realm's agent: the isolate the context was just made in, which is
    // the current one. Operations that enter the realm from outside it enter
    // this (engine.enterRealm) - a worker's is never the page's.
    ctx_data.agent = @ptrCast(v8.v8_Isolate_GetCurrent());

    // Heap-allocate the entry so it doesn't move when HashMap rehashes
    const entry = try state.alloc().create(ContextEntry);
    errdefer state.alloc().destroy(entry);

    entry.* = ContextEntry{
        .v8_ctx = v8_ctx,
        .runtime_ctx = ctx_data,
        .owns_context = true,
        .event_loop = null, // We don't own the external event loop
        .realm = null,
        .parent_entry = null,
        .children = .empty,
        .allocator = allocator,
    };

    // Store pointer in map - entry won't move even if HashMap rehashes
    try reserveRetirement(state);
    state.guard.beforeInsert(&state.contexts);
    try state.contexts.put(state.alloc(), key, entry);

    return &entry.runtime_ctx;
}

/// Get or create a runtime context for the given V8 context with full timer support
///
/// If a runtime context already exists for this V8 context, returns it.
/// Otherwise, creates a new runtime context with V8EventLoop for timer support.
///
/// The returned context is valid until:
/// - removeContext() is called for this V8 context
/// - the agent ends (`endAgentRealms`)
///
/// On the agent's own thread (the current isolate's realms).
///
/// Arguments:
/// - v8_ctx: V8 context pointer
/// - isolate: V8 isolate (optional, needed for timer support)
/// - allocator: Allocator to use for the runtime context (if created)
///
/// Returns: Runtime context pointer (borrowed, do not free)
pub fn getOrCreateWithIsolate(v8_ctx: *v8.Context, isolate: ?*v8.Isolate, allocator: std.mem.Allocator) !runtime.Context {
    const state = currentRealms() orelse return error.NotInitialized;

    // Use the raw V8 internal address as the key (stable across Global/Local conversions)
    const raw_addr = v8.v8_Context_GetRawAddress(v8_ctx) orelse return error.InvalidContext;
    const key = @intFromPtr(raw_addr);

    // Check if context already exists
    if (state.contexts.get(key)) |entry| {
        return &entry.runtime_ctx;
    }

    // The entry keeps its OWN handle, so the caller's stays the caller's to
    // release whichever path this takes. Storing the caller's handle made it
    // the entry's on this path only, so no caller could ever release one: the
    // constructor binding leaked a Global<Context> per `new X()`, each keeping
    // its page's whole native context alive.
    const copy_isolate = isolate orelse (v8.v8_Isolate_GetCurrent() orelse return error.InvalidContext);
    const entry_ctx: *v8.Context = @ptrCast(v8.v8_Context_GlobalHandle_New(copy_isolate, v8_ctx) orelse return error.InvalidContext);
    errdefer v8.v8_Context_Dispose(entry_ctx);

    // Create V8 event loop with timer support if isolate is provided
    var event_loop_ptr: ?*V8EventLoop = null;
    var timer_interface: ?runtime.TimerInterface = null;
    var event_loop_interface: ?@import("event_loop").EventLoop = null;

    if (isolate) |iso| {
        const ev_loop = try allocator.create(V8EventLoop);
        errdefer allocator.destroy(ev_loop);

        ev_loop.* = try V8EventLoop.init(iso, allocator);
        errdefer ev_loop.deinit();

        event_loop_ptr = ev_loop;
        timer_interface = ev_loop.timerInterface();
        event_loop_interface = ev_loop.eventLoop();
    }

    // Create new runtime context with V8 engine interface
    // The engine interface provides Promise creation, async iterators, and other
    // engine-agnostic operations that body methods (text(), json(), etc.) need.
    var ctx_data = try runtime.ContextData.init(allocator, .{
        .colored = false, // V8 callbacks shouldn't use colored output
        .show_timestamp = false,
        .show_labels = false,
        .engine_ctx = @ptrCast(entry_ctx), // Store V8 context as engine context
        .timer = timer_interface,
        .event_loop = event_loop_interface,
    });
    errdefer ctx_data.deinit();

    // Initialize V8 wrapper cache for this context
    const WrapperCache = @import("wrapper_cache.zig").WrapperCache;
    const cache_ptr = try allocator.create(WrapperCache);
    errdefer allocator.destroy(cache_ptr);

    cache_ptr.* = try WrapperCache.init(allocator, entry_ctx);
    errdefer cache_ptr.deinit();

    // Store cache in runtime context
    ctx_data.setV8WrapperCacheStorage(@ptrCast(cache_ptr));
    // The realm's agent: the isolate the context was just made in, which is
    // the current one. Operations that enter the realm from outside it enter
    // this (engine.enterRealm) - a worker's is never the page's.
    ctx_data.agent = @ptrCast(v8.v8_Isolate_GetCurrent());

    // Create realm for cross-realm support (only if we have an isolate)
    // Per WebIDL, every context has an associated realm with intrinsics
    // Note: global_object is set to null here and will be populated later by
    // the realm's creator (protocol_realms.createWindowRealm) when it binds its Window
    var realm: ?*runtime.Realm = null;
    if (isolate) |iso| {
        realm = try runtime.Realm.init(allocator, .{
            .engine_realm = @ptrCast(entry_ctx),
            .agent = @ptrCast(iso),
            .context_type = .window, // Main context is a window
            .global_object = null, // Set by the realm's creator once it binds its global
        });
        errdefer if (realm) |r| r.deinit();

        // Populate realm intrinsics for cross-realm support
        _ = @import("realm_v8.zig").populateIntrinsics(realm.?);

        // Set realm on runtime context so impl code can access via instance.ctx.realm
        ctx_data.setRealm(realm.?);
    }

    // Heap-allocate the entry so it doesn't move when HashMap rehashes
    const entry = try state.alloc().create(ContextEntry);
    errdefer state.alloc().destroy(entry);

    entry.* = ContextEntry{
        .v8_ctx = entry_ctx,
        .owns_v8_ctx = true,
        .runtime_ctx = ctx_data,
        .owns_context = true,
        .event_loop = event_loop_ptr,
        .realm = realm,
        .parent_entry = null,
        .children = .empty,
        .allocator = allocator,
    };

    // Store pointer in map - entry won't move even if HashMap rehashes
    try reserveRetirement(state);
    state.guard.beforeInsert(&state.contexts);
    try state.contexts.put(state.alloc(), key, entry);

    // Return pointer to context data - stable because entry is heap-allocated
    return &entry.runtime_ctx;
}

/// Get an existing runtime context for the given V8 context
///
/// Returns null if no runtime context exists for this V8 context.
///
/// On the agent's own thread (the current isolate's realms).
pub fn get(v8_ctx: *v8.Context) ?runtime.Context {
    const state = currentRealms() orelse return null;

    // Use the raw V8 internal address as the key (stable across Global/Local conversions)
    const raw_addr = v8.v8_Context_GetRawAddress(v8_ctx) orelse return null;
    const key = @intFromPtr(raw_addr);

    if (state.contexts.get(key)) |entry| {
        return &entry.runtime_ctx;
    }

    return null;
}

/// The realm registered under `key` (keyOf: the context's Crane id), or
/// null. Reads no context: the cross-origin access check asks it with the
/// id V8's current context carries (cross_origin.zig).
pub fn getByKey(key: usize) ?runtime.Context {
    const state = currentRealms() orelse return null;
    const entry = state.contexts.get(key) orelse return null;
    return &entry.runtime_ctx;
}

/// Is a context with this raw address still registered?
///
/// Takes the ADDRESS, not the Global<Context>*, on purpose. `get()` above has to
/// call v8_Context_GetRawAddress to derive the key, which dereferences the handle -
/// so it cannot be used to ask "is this handle still valid?", because doing so is
/// the very use-after-free being tested for.
///
/// Callers that need to outlive a context (a queued microtask, say) must capture
/// `v8_Context_GetRawAddress` while the context is still alive and pass that key
/// here later.
pub fn isContextAddressAlive(raw_addr: usize) bool {
    const state = currentRealms() orelse return false;
    return state.contexts.contains(raw_addr);
}

/// Hydrate a V8 context restored from snapshot with the appropriate interfaces for the given scope
///
/// This function installs only the interfaces that are exposed in the given scope,
/// using the exposure metadata from WebIDL [Exposed] attributes.
///
/// On the agent's own thread (the current isolate's realms).
///
/// Arguments:
/// - isolate: V8 isolate pointer
/// - v8_ctx: V8 context pointer (restored from snapshot)
/// - scope: The global scope kind to install interfaces for
pub fn hydrateContextFromSnapshot(
    isolate: *v8.Isolate,
    v8_ctx: *v8.Context,
    scope: helpers.GlobalScope,
) void {
    log.debug("[HYDRATE-SNAPSHOT] hydrateContextFromSnapshot called, context={*}, scope={s}\n", .{ v8_ctx, @tagName(scope) });

    // Use inline for to convert runtime scope to comptime for installForScope
    inline for (comptime std.meta.fieldNames(helpers.GlobalScope)) |field_name| {
        if (scope == @field(helpers.GlobalScope, field_name)) {
            // NOTE: Do NOT call installLazyConstructorsOnGlobal here!
            // The snapshot already contains all WebIDL constructors registered via initializeBindings().
            // Installing lazy getters would OVERWRITE the snapshot's constructors with fresh ones,
            // breaking prototype chain identity (instanceof checks would fail because the prototype
            // objects would be different from those in the snapshot).

            // Register legacy interface aliases (e.g., webkitURL = URL)
            // V8 snapshots don't preserve object property sets on the global,
            // so we must re-register these aliases at runtime after loading from snapshot.
            const interface_bindings = @import("interface_bindings.zig");
            interface_bindings.registerLegacyInterfaceAliases(isolate, v8_ctx);

            // NOTE: Do NOT call setupConstructorInheritance here!
            // The snapshot already contains properly configured prototype chains set up during
            // snapshot creation via FunctionTemplate::Inherit(). Re-calling this would create
            // new templates and potentially break the prototype chain identity.

            log.debug("[HYDRATE-SNAPSHOT] Context hydrated with legacy aliases, scope={s}\n", .{@tagName(scope)});
            return;
        }
    }
}

/// Remove a runtime context for a V8 context
///
/// If the context manager owns the runtime context, it will be deinitialized.
/// If the context was registered via register(), it will NOT be deinitialized.
///
/// This function uses the cleanup coordinator to prevent GC callbacks from
/// firing during cleanup, which would cause crashes.
///
/// On the agent's own thread (the current isolate's realms).
pub fn removeContext(v8_ctx: *v8.Context) void {
    // Use the raw V8 internal address as the key (must match getOrCreate*)
    const raw_addr = v8.v8_Context_GetRawAddress(v8_ctx) orelse return;
    removeContextByKey(@intFromPtr(raw_addr));
}

/// The key `removeContextByKey` takes for `v8_ctx` - read while the context
/// lives (it is in the context's embedder data), so a realm whose context
/// the collector may take first can still be removed.
pub fn keyOf(v8_ctx: *v8.Context) ?usize {
    const raw_addr = v8.v8_Context_GetRawAddress(v8_ctx) orelse return null;
    return @intFromPtr(raw_addr);
}

/// The realm's Window torn down - its destructor chain, once - with its
/// cleanup marked (runtime.instance_lifecycle): from its first step, every
/// holder that keeps it with a generation and asks for its cleanup reads it
/// gone, before its slot is given back (protocol_realms.endRealm, step 5),
/// and the slot's release asks for that mark (lane winslot1, P2).
fn deinitWindow(window: *runtime.Instance) void {
    const lifecycle = runtime.instance_lifecycle;
    if (!lifecycle.markCleanupStarted(window)) return;
    @import("interfaces").Window.deinit(window);
    lifecycle.markCleanupComplete(window);
}

/// `removeContext` by the context's key (`keyOf`): the realm's Window, its
/// wrapper cache and its realm record go, and the entry is retired. Never
/// touches the context, which the collector may already have taken: the
/// entry knows its Window and its global's anchor.
pub fn removeContextByKey(key: usize) void {
    const state = currentRealms() orelse return;
    const raw_addr: ?*anyopaque = @ptrFromInt(key);

    // The garbage this realm's trees left - trees whose counts reached zero
    // (refcount step 7, dom.refcount_teardown; a collected wrapper's
    // reference is one of those counts) - goes first, while every object of
    // the realm lives and before its coordinated teardown begins: the
    // conditions the collector's second pass had. A teardown may end another
    // realm (an iframe in the tree), which drains its own.
    if (state.contexts.get(key)) |entry| {
        if (entry.runtime_ctx.getV8WrapperCacheStorage()) |cache_storage| {
            const cache: *@import("wrapper_cache.zig").WrapperCache = @ptrCast(@alignCast(cache_storage));
            cache.drainDeferred();
            // And the garbage its trees left (refcount step 7: counts decide).
            cache.drainRealmGarbage(&entry.runtime_ctx);
        }
        // Then its orphans - subtrees its removals left with no wrapper
        // reaching them, which no tree teardown and no collector reaches -
        // under the same conditions (runtime.orphan_roots, [wrap_tracking]).
        // They stayed until the Browser ended.
        runtime.orphan_roots.drain(&entry.runtime_ctx);
    }

    if (state.contexts.fetchRemove(key)) |kv| {
        state.guard.noteRemoval(&state.contexts);
        const entry = kv.value; // This is now *ContextEntry
        // Retire rather than destroy: Instances created in this context are not
        // destroyed below (they go with the slab) and their `ctx` points into
        // this entry. See ManagerState.retired.
        defer retireEntry(state, entry);
        // First, while every object of the realm is alive: the promise
        // reactions that have not run and the asynchronous iterators still
        // alive end, and their host data with them (realm_finalizers.zig).
        if (@import("realm_finalizers.zig").listOf(&entry.runtime_ctx)) |finalizers| finalizers.drain();
        // The callbacks this context's script registered hold handles into it
        // - one listener is enough to keep the whole page alive - and nothing
        // else releases them, since its EventTargets are never torn down.
        @import("callback_registry.zig").cleanupForContext(raw_addr);
        if (entry.owns_context) {
            // A pointer, not a copy - `clearV8WrapperCacheStorage` below has to
            // land on the entry's own ContextData, which is what every Instance
            // in this context reads through.
            const ctx_data = &entry.runtime_ctx;
            const cleanup_coordinator = runtime.cleanup_coordinator;
            const WrapperCache = @import("wrapper_cache.zig").WrapperCache;

            // Create coordinator for this context teardown
            // This signals GC callbacks to skip, preventing crashes
            var coordinator = cleanup_coordinator.CleanupCoordinator.init(state.alloc());
            defer coordinator.deinit();

            // Set coordinator as active so GC callbacks can check teardown state,
            // and give the one it replaces back after: a realm's teardown can
            // end another realm inside one of its phases (a frame's Window
            // ending a popup it owns whose realm is the page's child), and
            // that inner end used to leave NO coordinator active for the rest
            // of the outer one - every later deferral dropped, and
            // runtime.gc.releaseOwned freeing storage inline, mid-teardown
            // (lane winslot1, tests/v8/cleanup_coordinator_nested_test.zig).
            const previous_coordinator = cleanup_coordinator.getActiveCoordinator();
            cleanup_coordinator.setActiveCoordinator(&coordinator);
            defer cleanup_coordinator.setActiveCoordinator(previous_coordinator);

            // Begin coordinated cleanup - signals GC callbacks to skip
            coordinator.beginContextCleanup();

            // A frame's realm is made by engine.createWindowRealm with a
            // parent, whose end ends it first (protocol_realms): no entry
            // has children here.
            entry.children.deinit(entry.allocator);

            // Clean up Window and Document (DOM tree) before wrapper cache
            // This is critical: DOM nodes (including HTMLIFrameElement) need their
            // deinit called to clean up resources like BrowsingContext.
            // DOM nodes may not be in the wrapper_cache if never accessed from JS.
            // We must explicitly trigger DOM tree cleanup here.
            coordinator.cleanupPhase(.dom_tree);

            // NOTE: We do NOT iterate wrapper_cache to find HTMLIFrameElement instances.
            // Per Chromium's pattern, wrapper cache iteration is unsafe because:
            // 1. Some instances may have invalid state pointers
            // 2. Instance types cannot be safely checked without accessing state
            // Instead, we rely on DOM tree traversal: Window.deinit → Document.deinit →
            // Node.deinit chain which properly cleans up all DOM nodes including iframes.
            // HTMLIFrameElement instances are cleaned up when Node.deinit iterates children.

            // Clean up the Window and its DOM tree
            // The realm's global instance is freed below (the Window here,
            // a worker's global scope after the cache): its anchor lets go of
            // it first, which severs the hidden global and WindowProperties.
            if (entry.global_anchor) |ref| v8.v8_GlobalAnchor_Clear(ref);
            // The Window its global was attached with - never field 0 of the
            // context's Global(), which a navigation's reused proxy points at
            // the NEXT realm's Window.
            const window_instance_dom = entry.window_instance;
            if (window_instance_dom) |wi| {
                // Remove Window from wrapper cache FIRST to prevent double-free
                if (ctx_data.getV8WrapperCacheStorage()) |cache_storage| {
                    const cache_ptr: *WrapperCache = @ptrCast(@alignCast(cache_storage));
                    _ = cache_ptr.remove(wi);
                }

                // Now call Window.deinit which will clean up Location, Document, and DOM tree.
                //
                // The Location's wrapper stays in the cache: Window.deinit frees
                // the Location whole (runtime.gc.releaseOwned), so the sweep
                // below finds it torn down, severs its wrapper and gives its
                // slot to this teardown. It used to be taken out of the cache
                // here, unsevered, before the Window freed it - and then
                // nothing returned its storage: every page kept its Location
                // until its Browser ended (lane pageretention1).
                deinitWindow(wi);
            }

            // Clean up V8 wrapper cache
            // Now safe because:
            // 1. Children are already cleaned up (no stale child pointers)
            // 2. DOM nodes already removed themselves
            // 3. HTMLIFrameElement instances explicitly cleaned up above
            coordinator.cleanupPhase(.wrapper_cache);
            // A worker's or worklet's global scope goes after every other
            // object of its realm, not in the walk's hash order: Blink
            // disposes a worker's global scope only once its context's end
            // has been notified and its script is gone
            // (WorkerThread::PerformShutdownOnWorkerThread), and WebKit
            // releases it after prepareForDestruction and clearScript
            // (WorkerOrWorkletThread::destroyWorkerGlobalScope). A teardown
            // the walk runs can read the realm's global; ahead of it, the
            // global was read freed (lane workerteardown1: a fetch body's
            // end reported timing to it). A guard: the host ends what still
            // works for the realm before its end (a worker's fetch group,
            // WorkerHost.teardownRealm). A Window went above, with its
            // document. The realm's end cleared the global object's fields
            // before this (worker_realm.bindGlobalFields), so only the cache
            // entry is left to take out.
            const last_global: ?*runtime.Instance = last: {
                if (window_instance_dom != null) break :last null;
                const record = entry.realm orelse break :last null;
                // Only the kinds whose end is ordered so (an allowlist: any
                // other realm keeps the walk's order).
                if (!record.info.isWorker() and !record.info.isWorklet()) break :last null;
                const global = record.global_object orelse break :last null;
                break :last @ptrCast(@alignCast(global));
            };
            var free_last_global = false;
            if (ctx_data.getV8WrapperCacheStorage()) |cache_storage| {
                const cache_ptr: *WrapperCache = @ptrCast(@alignCast(cache_storage));
                // Only one the walk would have freed: an entry of this cache.
                if (last_global) |global| free_last_global = cache_ptr.remove(global);
                cache_ptr.deinit();
                ctx_data.getAllocator().destroy(cache_ptr);
                ctx_data.clearV8WrapperCacheStorage();
            }
            // With no cache left to answer for it: its teardown's engine
            // calls (traced edges, wrapper lookups) find none and do nothing,
            // its Pins dispose their handles in the agent still entered.
            if (free_last_global) runtime.gc.onObjectFreed(last_global.?);

            // Clean up V8 event loop
            coordinator.cleanupPhase(.event_loop);
            if (entry.event_loop) |ev_loop| {
                ev_loop.deinit();
                ctx_data.getAllocator().destroy(ev_loop);
            }

            // Clean up realm
            if (entry.realm) |realm| {
                @import("realm_v8.zig").disposeIntrinsics(realm);
                realm.deinit();
            }

            // Last: the storage of the nodes this teardown tore down that no
            // wrapper of any realm ever reached ([wrap_tracking];
            // Node.deinitNodeByType handed it over). Nothing can reach their
            // slots: the cache, the event loop and the realm are gone.
            coordinator.releaseDeferredStorage();

            // NOTE: no `ctx_data.deinit()` here - deinit()'s drain does it, once
            // no Instance can still be pointing at this ContextData.
        }

        entry.runtime_ctx.clearDocumentUrl();
    }
}

/// Clear all wrapper caches without destroying the contexts
///
/// This is used for test isolation - clears cached V8 wrappers between tests
/// while keeping the contexts alive. This prevents stale V8 objects from
/// causing issues when running multiple tests sequentially.
///
/// The two-phase cleanup in WrapperCache.clear() ensures:
/// 1. All weak callbacks are disabled first (no use-after-free)
/// 2. Then instances are cleaned up via GC integration (type-specific deinit)
/// 3. V8 handles are disposed
/// 4. CacheEntries are freed
///
/// On the agent's own thread (the current isolate's realms).
pub fn clearWrapperCaches() void {
    const state = currentRealms() orelse return;
    const WrapperCache = @import("wrapper_cache.zig").WrapperCache;

    var it = state.contexts.valueIterator();
    while (it.next()) |entry_ptr| {
        const entry = entry_ptr.*; // Dereference pointer to get *ContextEntry
        var ctx_data = entry.runtime_ctx;
        if (ctx_data.getV8WrapperCacheStorage()) |cache_storage| {
            const cache_ptr: *WrapperCache = @ptrCast(@alignCast(cache_storage));
            cache_ptr.clear();
        }
    }
}

// ============================================================================
// Child Context Management (Cross-Realm Support)
// ============================================================================

// ============================================================================
// Window Indexed Property Handler for frames[index] access
// ============================================================================

/// Indexed property getter for Window global objects.
/// Enables `window.frames[0]`, `window[0]`, etc. to access child browsing contexts.
///
/// Per HTML spec §7.4.3.1 (WindowProxy [[GetOwnProperty]]):
/// - Numeric indices return the WindowProxy of the corresponding one of the
///   Window's document-tree child navigables (a shadow tree's are not among
///   them)
/// - Returns undefined if index >= their number (window.length)
///
/// This callback is registered on the global object template for child contexts.
///
/// IMPORTANT: This function handles lazy initialization of child browsing contexts.
/// When an iframe is inserted into the DOM, a BrowsingContext is created but the
/// V8 context and Window instance are NOT created until needed. This getter triggers
/// the creation of the V8 child context when frames[index] is accessed and the
/// child browsing context exists but doesn't have an active Window yet. It reaches
/// Window only through its generated interface, and the container through the
/// dom.child_navigables hook its owner installs.
pub fn windowIndexedPropertyGetter(
    index: u32,
    info: *const v8.PropertyCallbackInfo,
) callconv(.c) v8.Intercepted {
    const interfaces = @import("interfaces");
    const template_registry = @import("template_registry.zig");
    const conv = @import("conversions.zig");

    const isolate = info.getIsolate();
    // Owned, as every v8_* pointer is (a Global per call): both are released
    // on every path - kept, each window[i] leaked two Globals (leaks
    // --atExit, lane rc5).
    const v8_context = v8.v8_Isolate_GetCurrentContext(isolate) orelse return .kNo;
    defer v8.v8_Context_Dispose(v8_context);

    // The Window whose child navigables `window[index]` names: THE
    // Window-receiver rule (realm_global.globalOfReceiver) - the holder is the
    // global proxy, or, for a use in a realm whose WindowProxy went on, V8's
    // detached copy of it (that realm's own Window). It read field 0 of the
    // holder, then of the current context's global: for the copy that was the
    // NEW Window behind the reused proxy (design 2.3 gap b).
    const this_obj = info.getHolder() orelse return .kNo;
    defer v8.v8_Object_Dispose(this_obj);
    const instance = @import("realm_global.zig").globalOfReceiver(isolate, this_obj, .native) orelse return .kNo;

    // HTML 7.2.3.1 WindowProxy [[GetOwnProperty]] step 2: index is in the
    // Window's document-tree child navigables, and the result is the
    // index-th one's active WindowProxy. Window's own indexed getter answers
    // from that list (interfaces.Window.call_item), and null when the
    // child's Window is not made yet.
    var result = interfaces.Window.call_item(instance, index) catch return .kNo;

    // A child navigable whose Window script has not asked for yet: its
    // container makes it (its navigable's realm under this window's, its
    // Window and initial document - dom.child_navigables.window). Indexed in
    // the list Window's length and item answer from: the browsing context's
    // children in INSERTION order - all three browsers keep it (a
    // foster-parented iframe does not reorder window[i]:
    // html/browsers/the-window-object/accessing-other-browsing-contexts/
    // indexed-browsing-contexts-01.html; the spec's tree order is unshipped)
    // - keeping only DOCUMENT-TREE members, never a shadow tree's navigables
    // (Codex row 81 Q8) - the one list Window's length and item walk too
    // (dom.navigables.documentTreeChildNavigables). Window's item answers
    // null for such a child as well as past the end: making the child's
    // Window is the container's, which only the engine's access triggers
    // here (HTMLIFrameElement's contentWindow makes it lazily too).
    if (result == null) {
        if (documentTreeChildAt(instance, index)) |child_bc| {
            result = if (child_bc.getActiveWindow()) |window|
                @ptrCast(@alignCast(window))
            else
                @import("dom").child_navigables.window(@ptrCast(child_bc));
        }
    }

    if (result) |child_window| {
        // HTML 7.1.3.3's access report check, for an index that names a
        // child (Chromium's DOMWindow::AnonymousIndexedGetter reports
        // "indexed"; access-reporting/property-indexed-getter: none for an
        // index past the end).
        @import("protocol_realms.zig").reportWindowAccess(instance, "indexed");
        // We have a child Window instance - wrap it and return
        const interface_name = template_registry.getInstanceInterfaceName(child_window);
        const wrapped = template_registry.wrapInstanceAsV8Object(
            child_window,
            interface_name,
            isolate,
            v8_context,
        ) catch {
            conv.throwError(isolate, "Failed to wrap child window");
            return .kNo;
        };
        info.setReturnValue(@ptrCast(wrapped));
        return .kYes;
    }
    // If result is null (out of bounds), don't set a return value
    // This lets V8 continue with normal property lookup (returns undefined)
    return .kNo;
}

/// The `index`-th of `window`'s document-tree child navigables, in the
/// order Window's length and item count them (dom.navigables
/// .documentTreeChildNavigables, the one list both walk): null past their
/// number, or for a Window with no navigable or associated Document.
fn documentTreeChildAt(window: *runtime.Instance, index: u32) ?*@import("dom").browser_state.BrowsingContext {
    const dom = @import("dom");
    const interfaces = @import("interfaces");
    const navigable = dom.browser_state.browsingContextOf(window) orelse return null;
    const document = (interfaces.Window.get_document(window) catch null) orelse return null;
    var children = dom.navigables.documentTreeChildNavigables(navigable, document, std.heap.c_allocator);
    defer children.deinit(std.heap.c_allocator);
    if (index >= children.items.len) return null;
    return children.items[index].browsing_context;
}

/// Indexed property query for Window global objects.
/// Returns PropertyAttribute flags if the index is a valid frame index.
/// Per V8 IndexedPropertyQueryCallback:
/// - Return Intercepted.kYes if property exists (with attributes set via info.setReturnValue)
/// - Return Intercepted.kNo if property doesn't exist (continue normal lookup)
pub fn windowIndexedPropertyQuery(
    index: u32,
    info: *const v8.PropertyCallbackInfo,
) callconv(.c) v8.Intercepted {
    // THE Window-receiver rule, as the getter's.
    const this_obj = info.getHolder() orelse return .kNo;
    defer v8.v8_Object_Dispose(this_obj);
    const instance = @import("realm_global.zig").globalOfReceiver(info.getIsolate(), this_obj, .native) orelse return .kNo;

    // Check if this index is valid
    const length = @import("interfaces").Window.get_length(instance) catch return .kNo;
    if (index < length) {
        // Valid index - return property attributes (ReadOnly | DontEnum)
        // Per spec, indexed properties on Window are configurable but not writable
        const isolate = info.getIsolate();
        const attrs = v8.v8_Integer_New(isolate, 3); // 3 = ReadOnly | DontEnum
        // SetReturnValue copies; the Global is ours.
        defer v8.v8_Value_Dispose(@ptrCast(attrs));
        info.setReturnValue(@ptrCast(attrs));
        return .kYes;
    }
    // Invalid index - property doesn't exist
    return .kNo;
}

/// Indexed property enumerator for Window global objects.
/// Returns an array of indices 0..length-1.
pub fn windowIndexedPropertyEnumerator(
    info: *const v8.PropertyCallbackInfo,
) callconv(.c) void {
    const isolate = info.getIsolate();

    // Every handle below is this callback's: SetReturnValue and Array::Set
    // copy what they are given. Kept, they were two Globals per enumeration
    // of the window's own keys - the context and the array - and one more per
    // child navigable.
    // THE Window-receiver rule, as the getter's.
    const this_obj = info.getHolder() orelse return;
    defer v8.v8_Object_Dispose(this_obj);
    const length: u32 = if (@import("realm_global.zig").globalOfReceiver(isolate, this_obj, .native)) |instance|
        @import("interfaces").Window.get_length(instance) catch 0
    else
        0;

    // Create array of indices as integers
    // V8's indexed property interceptor expects integer indices here.
    // V8 internally converts these to strings when needed for ownKeys.
    const arr = v8.v8_Array_New(isolate, @intCast(length));
    defer v8.v8_Array_Dispose(arr);
    if (length > 0) {
        const v8_context = v8.v8_Isolate_GetCurrentContext(isolate) orelse return;
        defer v8.v8_Context_Dispose(v8_context);
        var i: u32 = 0;
        while (i < length) : (i += 1) {
            const idx_val = v8.v8_Integer_New(isolate, @intCast(i));
            defer v8.v8_Value_Dispose(@ptrCast(idx_val));
            _ = v8.v8_Array_Set(arr, v8_context, i, @ptrCast(idx_val));
        }
    }
    info.setReturnValue(@ptrCast(arr));
}

/// Take an entry out of service without freeing it.
///
/// See `ManagerState.retired`: an Instance's `ctx` is a pointer INTO this entry,
/// and the Instances outlive the entry. What can be released has been released by
/// the caller; this makes the ContextData inert so that a stale `ctx` answers
/// "no wrapper cache, no engine context, no realm" rather than reading poison.
///
/// `engine` is left alone on purpose - it points at a static interface, and
/// `ContextData.deinit` needs it to release `_engine_event_loop_storage`.
fn retireEntry(state: *Realms, entry: *ContextEntry) void {
    // The entry's own handle was the last strong root of a destroyed frame:
    // everything else that held the page is released by now, so every frame
    // ever torn down kept its whole heap - context, global, wrappers - alive
    // for the rest of the process. Nothing reads a retired entry's context:
    // the map no longer finds it, destroyChildContext returns at `destroying`,
    // and the drain in deinit frees only Zig state.
    if (entry.owns_v8_ctx) {
        v8.v8_Context_Dispose(entry.v8_ctx);
        entry.owns_v8_ctx = false;
    }
    if (entry.global_anchor) |ref| {
        v8.v8_GlobalAnchor_Clear(ref);
        v8.v8_GlobalAnchor_Dispose(ref);
        entry.global_anchor = null;
    }
    entry.runtime_ctx.clearV8WrapperCacheStorage();
    entry.runtime_ctx.engine_ctx = null;
    entry.runtime_ctx.realm = null;
    entry.runtime_ctx.event_loop = null;
    entry.runtime_ctx.timer = null;
    entry.children = .empty;
    entry.parent_entry = null;
    entry.window_instance = null;
    entry.runtime_ctx.clearDocumentUrl();

    // Never allocates: every entry reserved its slot before it went into
    // `contexts` (reserveRetirement). The old fallback - freeing the entry when
    // this append ran out of memory - left every Context kept across turns
    // pointing at freed memory, where engine_protocol.zig's Context contract
    // promises a valid, inert record until the agent ends.
    state.retired.appendAssumeCapacity(entry);
}

/// Reserve the `retired` slot an entry about to go into `contexts` will take
/// when it is retired, so that retireEntry never allocates: capacity stays at
/// least every retired entry plus every live one. Called before each insert;
/// out of memory here fails the realm's creation, never its retirement.
fn reserveRetirement(state: *Realms) error{OutOfMemory}!void {
    try state.retired.ensureTotalCapacity(state.alloc(), state.retired.items.len + state.contexts.count() + 1);
}

/// Get the realm for a V8 context
///
/// Returns the Realm associated with the given V8 context, or null
/// if no realm is associated or the context is not registered.
///
/// On the agent's own thread (the current isolate's realms).
pub fn getRealmForContext(v8_ctx: *v8.Context) ?*runtime.Realm {
    const state = currentRealms() orelse return null;

    const raw_addr = v8.v8_Context_GetRawAddress(v8_ctx) orelse return null;
    const key = @intFromPtr(raw_addr);

    if (state.contexts.get(key)) |entry| {
        return entry.realm;
    }

    return null;
}

/// Get the realm for the current V8 context
///
/// Returns the Realm for the currently entered V8 context, or null
/// if no context is entered or no realm is associated.
///
/// On the agent's own thread (the current isolate's realms).
pub fn getCurrentRealm() ?*runtime.Realm {
    const isolate = v8.v8_Isolate_GetCurrent() orelse return null;
    const context = v8.v8_Isolate_GetCurrentContext(isolate) orelse return null;
    return getRealmForContext(context);
}

/// Get the ContextEntry for a V8 context
///
/// Returns the full ContextEntry for the given V8 context, allowing
/// access to parent/child relationships.
///
/// On the agent's own thread (the current isolate's realms).
pub fn getEntry(v8_ctx: *v8.Context) ?*ContextEntry {
    const state = currentRealms() orelse return null;

    const raw_addr = v8.v8_Context_GetRawAddress(v8_ctx) orelse return null;
    const key = @intFromPtr(raw_addr);

    return state.contexts.get(key);
}

/// The Window of the realm whose context is `v8_ctx`: the one its realm's
/// global was attached with (realm_global.attach, which every Window realm's
/// creation records here), or null - the context is no Window realm's, or its
/// realm ended. Never field 0 of the context's Global(): after a navigation
/// handed the WindowProxy on, that names the NEW realm's Window, and an old
/// realm's callbacks must see their own (design 2.3, gap c; THE
/// Window-receiver rule is realm_global.receiverRealm).
///
/// On the agent's own thread (the current isolate's realms).
pub fn getWindowForContext(v8_ctx: *v8.Context) ?*runtime.Instance {
    const state = currentRealms() orelse return null;
    const raw_addr = v8.v8_Context_GetRawAddress(v8_ctx) orelse return null;
    const entry = state.contexts.get(@intFromPtr(raw_addr)) orelse return null;
    return entry.window_instance;
}

/// The global object of the realm whose context is `v8_ctx` - its Window,
/// WorkerGlobalScope, worklet global scope: the realm record's (ECMA-262
/// [[GlobalObject]], which the realm's creator records as it binds its global),
/// or the Window the entry records; null when the context manager records no
/// such realm (none, or ended). THE receiver rule's answer for every [Global]
/// interface (realm_global.globalOfReceiver).
pub fn globalObjectForContext(v8_ctx: *v8.Context) ?*runtime.Instance {
    const state = currentRealms() orelse return null;
    const raw_addr = v8.v8_Context_GetRawAddress(v8_ctx) orelse return null;
    const entry = state.contexts.get(@intFromPtr(raw_addr)) orelse return null;
    if (entry.realm) |record| if (record.global_object) |global| return @ptrCast(@alignCast(global));
    return entry.window_instance;
}

/// The GlobalAnchor reference of `v8_ctx`'s realm (ContextEntry.global_anchor),
/// BORROWED; null when it has none or the context manager does not record it.
pub fn globalAnchorOf(v8_ctx: *v8.Context) ?*v8.GlobalAnchorRef {
    const state = currentRealms() orelse return null;
    const raw_addr = v8.v8_Context_GetRawAddress(v8_ctx) orelse return null;
    const entry = state.contexts.get(@intFromPtr(raw_addr)) orelse return null;
    return entry.global_anchor;
}

/// Keep `ref` - the GlobalAnchor realm_global.attach just set on `v8_ctx`'s
/// global - on the realm's entry, which owns it from now on. One the entry
/// had (a second attach) is cleared and disposed; with no entry, nothing
/// would dispose it, so it is disposed now (the anchor itself lives on with
/// the global).
pub fn adoptGlobalAnchor(v8_ctx: *v8.Context, ref: *v8.GlobalAnchorRef) void {
    const entry: ?*ContextEntry = blk: {
        const state = currentRealms() orelse break :blk null;
        const raw_addr = v8.v8_Context_GetRawAddress(v8_ctx) orelse break :blk null;
        break :blk state.contexts.get(@intFromPtr(raw_addr));
    };
    const owner = entry orelse return v8.v8_GlobalAnchor_Dispose(ref);
    if (owner.global_anchor) |previous| {
        v8.v8_GlobalAnchor_Clear(previous);
        v8.v8_GlobalAnchor_Dispose(previous);
    }
    owner.global_anchor = ref;
}

/// Get the V8EventLoop for a V8 context
///
/// Returns the V8EventLoop associated with this context, if one was created.
/// This is used by worker threads to poll libuv timers (setTimeout/setInterval).
///
/// On the agent's own thread (the current isolate's realms).
pub fn getEventLoop(v8_ctx: *v8.Context) ?*V8EventLoop {
    const state = currentRealms() orelse return null;

    const raw_addr = v8.v8_Context_GetRawAddress(v8_ctx) orelse return null;
    const key = @intFromPtr(raw_addr);

    if (state.contexts.get(key)) |entry| {
        return entry.event_loop;
    }
    return null;
}

/// Associate a realm with an existing context
///
/// This is used when a context was created via getOrCreate but a realm
/// needs to be associated with it later.
///
/// On the agent's own thread (the current isolate's realms).
pub fn setRealmForContext(v8_ctx: *v8.Context, realm: *runtime.Realm) !void {
    const state = currentRealms() orelse return error.NotInitialized;

    const raw_addr = v8.v8_Context_GetRawAddress(v8_ctx) orelse return error.InvalidContext;
    const key = @intFromPtr(raw_addr);

    if (state.contexts.get(key)) |entry| {
        // Free existing realm if any
        if (entry.realm) |old_realm| {
            old_realm.deinit();
        }
        entry.realm = realm;
    } else {
        return error.ContextNotFound;
    }
}

/// Associate a Window instance with an existing context
///
/// This is used when Browser.Context creates its own Window instance
/// and needs to register it with the context manager so that
/// getWindowForContext() can find it later.
///
/// This is critical for iframe browsing context creation, where
/// handleIframeInsertion needs to look up the parent Window.
///
/// On the agent's own thread (the current isolate's realms).
pub fn setWindowForContext(v8_ctx: *v8.Context, window: *runtime.Instance) !void {
    const state = currentRealms() orelse return error.NotInitialized;

    const raw_addr = v8.v8_Context_GetRawAddress(v8_ctx) orelse return error.InvalidContext;
    const key = @intFromPtr(raw_addr);

    if (state.contexts.get(key)) |entry| {
        entry.window_instance = window;
    } else {
        return error.ContextNotFound;
    }
}

/// Set the document URL for a context (used for module resolution)
///
/// This should be called when navigating to a page to enable proper
/// resolution of relative module specifiers in dynamic imports.
pub fn setDocumentUrl(v8_ctx: *v8.Context, url: []const u8) !void {
    const state = currentRealms() orelse return error.NotInitialized;

    const raw_addr = v8.v8_Context_GetRawAddress(v8_ctx) orelse return error.InvalidContext;
    const key = @intFromPtr(raw_addr);

    if (state.contexts.get(key)) |entry| {
        // The realm keeps it: runtime.ContextData.setDocumentUrl, which code
        // outside the adapter calls directly.
        try entry.runtime_ctx.setDocumentUrl(url);
    } else {
        return error.ContextNotFound;
    }
}

/// Get the document URL for a context
pub fn getDocumentUrl(v8_ctx: *v8.Context) ?[]const u8 {
    const state = currentRealms() orelse return null;

    const raw_addr = v8.v8_Context_GetRawAddress(v8_ctx) orelse return null;
    const key = @intFromPtr(raw_addr);

    if (state.contexts.get(key)) |entry| {
        return entry.runtime_ctx.documentUrl();
    }
    return null;
}

/// Mark an instance as cleaned up in the wrapper cache
///
/// This should be called when a DOM node is being cleaned up via Node.deinit
/// to prevent double-free when the context is later torn down. The instance
/// has already been (or is being) cleaned up, so we mark it to prevent
/// wrapper_cache.deinit() from calling onObjectFreed again.
///
/// We don't remove from cache or dispose V8 handles here because we might
/// still be in JavaScript execution context. That happens in wrapper_cache.deinit().
///
/// On the agent's own thread (the current isolate's realms).
pub fn markInstanceCleanedUp(instance: *runtime.Instance) void {
    // A node's wrapper is its agent's, in its own slot: severed and ended
    // now, its reference with it (node_wrappers.nodeDestroyed).
    if (instance.vtable.counted != null) return @import("node_wrappers.zig").nodeDestroyed(instance);
    // Get the context from the instance
    const ctx_data = instance.ctx;

    // Get the wrapper cache from the context
    const cache_storage = ctx_data.getV8WrapperCacheStorage() orelse return;
    const WrapperCache = @import("wrapper_cache.zig").WrapperCache;
    const cache: *WrapperCache = @ptrCast(@alignCast(cache_storage));

    // Mark the instance as already cleaned up
    _ = cache.markAsCleanedUp(instance);
}

// ============================================================================
// External Reference Registration for V8 Snapshots
// ============================================================================

/// Register Window indexed property callbacks as external references
///
/// This MUST be called before creating or loading a V8 snapshot.
/// Indexed property callbacks must be registered so V8 can resolve them at load time.
pub fn registerExternalReferences() void {
    const ext_refs = @import("external_references.zig");

    // Register indexed property handler callbacks for Window global objects
    ext_refs.registerPointer(@intFromPtr(&windowIndexedPropertyGetter));
    ext_refs.registerPointer(@intFromPtr(&windowIndexedPropertyQuery));
    ext_refs.registerPointer(@intFromPtr(&windowIndexedPropertyEnumerator));
    // No named handler on the global: a Window's named properties are its
    // WindowProperties object's (window_properties.zig, HTML 7.3.3). The
    // global named getter and query that were registered here were installed
    // nowhere (lane v8up b3c deleted them; design 2.3 gap b).
}

// ============================================================================
// Centralized Runtime Hydration API
// ============================================================================
//
// These functions centralize post-snapshot steps (template registry population,
// accessor reinstall, namespace registration, prototype fixes) into single
// per-context-type hydration functions.
//
// This eliminates duplication between Context.zig and worker_v8_context.zig.
// ============================================================================

/// Context type for hydration
pub const HydrationContextType = enum {
    /// Window context (for HTML pages) - gets document, location, navigator
    window,
    /// Worker context - gets self, postMessage (NO document, location)
    worker,
};

/// Options for hydrating a context
pub const HydrationOptions = struct {
    /// V8 isolate
    isolate: *v8.Isolate,
    /// V8 context to hydrate
    context: *v8.Context,
    /// Allocator for runtime objects
    allocator: std.mem.Allocator,
    /// Timer interface for setTimeout/setInterval
    timer_interface: ?runtime.TimerInterface = null,
    /// Event loop interface (streams EventLoop interface)
    event_loop_interface: ?@import("event_loop").EventLoop = null,
    /// Network manager for async fetch (Window only)
    network_manager: ?*anyopaque = null,
};

/// Hydration result for worker contexts
pub const WorkerHydrationResult = struct {
    /// Runtime context for the V8 context
    runtime_ctx: runtime.Context,
    /// Whether hydration succeeded
    success: bool = true,
};

/// Hydrate a V8 context as a Worker context (from snapshot)
///
/// This function performs all post-snapshot hydration steps for Worker contexts:
/// 1. Populates Zig-side template registry (wrapInstanceAsV8Object support)
/// 2. Reinstalls accessor callbacks on prototypes (stale after snapshot load)
/// 3. Sets up basic worker globals (self, globalThis)
/// 4. Registers context with context manager
///
/// ## Worker-specific behavior
///
/// Workers do NOT get:
/// - document, location, navigator (DOM-specific)
/// - Window instance (workers use DedicatedWorkerGlobalScope)
///
/// Workers DO get:
/// - self (reference to global)
/// - postMessage (registered separately by worker setup)
/// - console (registered separately)
///
/// ## Usage
///
/// ```zig
/// const result = try context_manager.hydrateWorkerContext(.{
///     .isolate = isolate,
///     .context = v8_ctx,
///     .allocator = allocator,
/// });
/// ```
pub fn hydrateWorkerContext(options: HydrationOptions) !WorkerHydrationResult {
    const interface_bindings = @import("interface_bindings.zig");

    const isolate = options.isolate;
    const v8_ctx = options.context;
    const allocator = options.allocator;

    log.debug("[HYDRATE-WORKER] hydrateWorkerContext called, isolate={*}, context={*}\n", .{ isolate, v8_ctx });

    // 1. The context manager is the current agent's: nothing to make.

    // 2. Register context with context manager
    const runtime_ctx = try getOrCreate(v8_ctx, allocator);

    // 3. Populate Zig-side template registry AND reinstall constructors with fresh callbacks
    log.debug("[HYDRATE-WORKER] Calling registerAllTemplatesOnly...\\n", .{});
    interface_bindings.registerAllTemplatesOnly(isolate, v8_ctx, .lazy_follows);

    // NOTE: Accessor callback reinstallation is NO LONGER NEEDED after whatwg-41la6.
    // The Chromium pattern fix (calling GetFunction before NewInstance) ensures
    // prototype chains are materialized correctly during snapshot creation.

    log.debug("[HYDRATE-WORKER] hydrateWorkerContext complete\n", .{});

    // 6. Set up basic worker globals
    const global_obj = v8.v8_Context_Global(v8_ctx) orelse {
        return error.NoGlobal;
    };

    // 'self' = globalThis (reference to global object)
    const self_key = v8.v8_String_NewFromUtf8(isolate, "self", 4) orelse {
        return error.StringCreationFailed;
    };
    _ = v8.v8_Object_Set(global_obj, v8_ctx, @ptrCast(self_key), @ptrCast(global_obj));

    // 'globalThis' = global object
    const global_this_key = v8.v8_String_NewFromUtf8(isolate, "globalThis", 10) orelse {
        return error.StringCreationFailed;
    };
    _ = v8.v8_Object_Set(global_obj, v8_ctx, @ptrCast(global_this_key), @ptrCast(global_obj));

    return WorkerHydrationResult{
        .runtime_ctx = runtime_ctx,
        .success = true,
    };
}

/// Check if a context has Window-specific globals
///
/// Returns true if the context has 'document' as a property (Window context),
/// false if it has 'postMessage' but no 'document' (Worker context).
pub fn isWindowContext(isolate: *v8.Isolate, context: *v8.Context) bool {
    const global = v8.v8_Context_Global(context) orelse return false;

    // Check for 'document' property - Window contexts have this
    const doc_key = v8.v8_String_NewFromUtf8(isolate, "document", 8) orelse return false;
    const has_doc = v8.v8_Object_Has(global, context, @ptrCast(doc_key));

    return has_doc;
}

/// Check if a context is a Worker context
pub fn isWorkerContext(isolate: *v8.Isolate, context: *v8.Context) bool {
    const global = v8.v8_Context_Global(context) orelse return false;

    // Workers have 'self' but NOT 'document'
    const self_key = v8.v8_String_NewFromUtf8(isolate, "self", 4) orelse return false;
    const has_self = v8.v8_Object_Has(global, context, @ptrCast(self_key));

    const doc_key = v8.v8_String_NewFromUtf8(isolate, "document", 8) orelse return false;
    const has_doc = v8.v8_Object_Has(global, context, @ptrCast(doc_key));

    return has_self and !has_doc;
}
