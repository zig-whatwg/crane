//! Implementation for EventTarget interface
//!
//! Spec: https://dom.spec.whatwg.org/#interface-eventtarget
//! WHATWG DOM Standard §2.7

const std = @import("std");
const log = std.log.scoped(.event_target);
const runtime = @import("runtime");
const engine = @import("engine");
const interfaces = @import("interfaces");
const abort_algorithms = @import("dom").abort_algorithms;
const dom_module = @import("dom");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const webidl = @import("webidl");
const infra = @import("infra");
const EventTarget = interfaces.EventTarget;

pub const State = EventTarget.State;

pub const ImplError = error{
    NotImplemented,
    InvalidStateError,
    OutOfMemory,
};

/// DOM §2.7 - Event listener structure
/// An event listener can be used to observe a specific event and consists of:
pub const EventListenerRecord = struct {
    /// type (a string)
    type: runtime.DOMString,

    /// callback (null or an EventListener callback): the callback interface
    /// value addEventListener converted, OWNED by the record.
    callback: ?engine.CallbackInterface,

    /// capture (a boolean, initially false)
    capture: bool = false,

    /// passive (null or a boolean, initially null)
    passive: ?bool = null,

    /// once (a boolean, initially false)
    once: bool = false,

    /// signal (null or an AbortSignal object). Read only by "add an event
    /// listener"; the stored record does not keep the signal alive, so
    /// nothing may read it afterwards.
    signal: ?*runtime.Instance = null,

    /// Identity for the abort steps "add an event listener" step 6 gives
    /// the signal: they remove THIS listener, not an equal one added after
    /// it was removed. Unique per thread; 0 for records never stored.
    id: u64 = 0,

    /// removed (a boolean for bookkeeping purposes, initially false)
    removed: bool = false,

    /// This record is an event handler's listener (HTML "activate an event
    /// handler"): its callback is the event handler processing algorithm for
    /// `type`, and `callback` is null. Keeping it IN the list is what orders
    /// `el.onclick = f` among the listeners added with addEventListener - the
    /// handler runs where it was first activated, not after everything else.
    event_handler: bool = false,

    /// Identity of an event handler listener, since it has no callback to
    /// compare: a deactivated and re-activated handler is a NEW listener, and
    /// a dispatch already under way must not mistake one for the other.
    handler_serial: u32 = 0,
};

/// Internal state for EventTarget implementation
/// Contains the event listener list which is lazily allocated to save memory
/// OPTIMIZATION: Most EventTargets never have listeners attached.
/// This saves ~40% memory on typical DOM trees where 90% of nodes have no listeners.
pub const InternalState = struct {
    allocator: std.mem.Allocator,

    /// DOM §2.7 - Each EventTarget has an associated event listener list
    /// (a list of zero or more event listeners). It is initially the empty list.
    ///
    /// OPTIMIZATION: Lazy allocation - most EventTargets never have listeners attached.
    /// Pattern borrowed from WebKit's NodeRareData and Chromium's NodeRareData.
    event_listener_list: ?*infra.List(EventListenerRecord) = null,

    /// Runtime type discriminator for duck typing
    /// This field helps distinguish EventTarget types at runtime.
    /// - 0: Plain EventTarget or AbortSignal
    /// - 1-12: Node types (ELEMENT_NODE, TEXT_NODE, etc.)
    /// This is filled in by Node's init - EventTarget itself uses 0.
    node_type: u16 = 0,

    /// HTML "event handler map" (§8.1.8.1): the event handlers whose target
    /// this is, by event type ("click" for onclick). Created with the first
    /// one - most targets never have any. A value is the handler as the
    /// binding converted it (HandlerValue), so that EventHandler,
    /// OnErrorEventHandler and OnBeforeUnloadEventHandler share the map. The
    /// keys are the IDL attributes' literal event types.
    ///
    /// The map owns each value: the binding hands the setter's argument over
    /// as it is, and `setEventHandler` releases a value it replaces or clears,
    /// `deinitEx` the rest. A value is a handle to a function in some page,
    /// and one never released kept that page alive for the process.
    event_handler_map: ?*std.StringHashMapUnmanaged(HandlerValue) = null,

    /// Set on an entry made lazily (`lazyInternal`), for an EventTarget whose
    /// impl never ran EventTarget's init - and so never runs its deinit,
    /// which is what removes an entry. Null for every other entry.
    lazy: ?LazyEntry = null,

    pub fn init(allocator: std.mem.Allocator) InternalState {
        return .{
            .allocator = allocator,
            .event_listener_list = null,
            .node_type = 0,
        };
    }

    pub fn deinit(self: *InternalState) void {
        self.deinitEx(true);
    }

    /// Deinitialize, releasing the engine values held - the listeners'
    /// callbacks and the event handlers - only when `release_engine_values`:
    /// during final runtime cleanup the engine's agent is already gone.
    pub fn deinitEx(self: *InternalState, release_engine_values: bool) void {
        if (self.event_listener_list) |list| {
            // Free each record's type string and, with an agent to give it
            // back to, its callback.
            const slice = list.toSliceMut();
            for (slice) |*listener| {
                var @"type" = listener.type;
                @"type".deinit(self.allocator);
                if (release_engine_values) {
                    if (listener.callback) |callback| callback.release();
                }
            }
            list.deinit();
            self.allocator.destroy(list);
        }
        if (self.event_handler_map) |map| {
            // Without an agent there is nothing to release into.
            if (release_engine_values) {
                var values = map.valueIterator();
                while (values.next()) |value| value.release();
            }
            map.deinit(self.allocator);
            self.allocator.destroy(map);
            self.event_handler_map = null;
        }
    }

    /// Ensure event listener list is allocated
    /// Lazily allocates the list on first use to save memory
    pub fn ensureEventListenerList(self: *InternalState) !*infra.List(EventListenerRecord) {
        if (self.event_listener_list) |list| {
            return list;
        }

        // First time adding a listener - allocate the list
        const list = try self.allocator.create(infra.List(EventListenerRecord));
        list.* = infra.List(EventListenerRecord).init(self.allocator);
        self.event_listener_list = list;
        return list;
    }

    /// Get event listener list (read-only access)
    /// Returns empty slice if no listeners have been added yet
    pub fn getEventListenerList(self: *const InternalState) []const EventListenerRecord {
        if (self.event_listener_list) |list| {
            return list.toSlice();
        }
        return &[_]EventListenerRecord{};
    }
};

/// What an entry made lazily records about the instance it was made for.
///
/// 236 impls of EventTarget's descendants (EventSource until 2026-10-01,
/// OffscreenCanvas, Performance, the IDB requests, the Audio, Sensor and
/// Bluetooth stubs ...) make their instance with runtime.Instance.init and
/// never chain to EventTarget's init or deinit, so their first
/// addEventListener makes the entry here and nothing removes it when the
/// instance goes. A worker's such entry outlived the worker's agent, and the
/// browser's end released its listener's handle into the disposed isolate
/// (eventsource/format-bom.any.js, at a sweep shard's exit: "Check failed:
/// node->IsInUse()").
const LazyEntry = struct {
    /// The instance's realm. Its end releases the entry (`releaseRealmEntries`,
    /// an unloading cleanup step), while the realm's agent lives: listeners
    /// go with their realm.
    realm: runtime.Context,
    /// INTERIM until every EventTarget impl chains init/deinit (queue): the
    /// instance's slab generation. An entry whose instance was freed stays
    /// here until its realm ends, keyed by an address the slab hands out
    /// again; the instance that gets the slot must not inherit the dead
    /// one's listeners (`getInternalFromRegistry`). A chained impl removes
    /// its entry in deinit, and then this goes.
    generation: u64,
};

/// Get the internal state from an instance
fn getInternal(instance: *runtime.Instance) ?*InternalState {
    const state = instance.getState(State);
    return if (@hasField(@TypeOf(state.own), "_internal")) state.own._internal else null;
}

/// The hooks this type owns (src/dom), installed once, at process start,
/// by crane.Process through the generated interface (docs/instances.md).
pub fn installHooks() void {
    // A lazily made entry's realm end releases it (`lazyInternal`).
    dom_module.unloading_cleanup.install(&releaseRealmEntries);
    // No event can be fired before a target exists.
    @import("dom").fire_event.install(.{
        .dispatch_trusted = dispatchTrusted,
        .dispatch_trusted_with_throws = dispatchTrustedWithThrows,
    });
    dom_module.event_handlers.install(.{ .get = getHandlerAddress, .set = setHandlerAddress, .erase = eraseAllEventListenersAndHandlers });
}

/// Initialize instance (creates the instance)
/// This is the root of the DOM inheritance chain - creates the Instance and
/// initializes EventTarget's internal state.
pub fn init(
    allocator: std.mem.Allocator,
    comptime StateType: type,
    vtable: *const runtime.VTable,
    ctx: runtime.Context,
) !*runtime.Instance {
    const instance = try runtime.Instance.init(allocator, StateType, vtable, ctx);
    errdefer runtime.Instance.deinit(instance);

    // Initialize EventTarget internal state in registry
    _ = try initInternal(instance, allocator);

    return instance;
}

/// Deinitialize instance
pub fn deinit(instance: *runtime.Instance) void {
    // Clean up internal state from registry
    if (getInternalFromRegistry(instance)) |internal| {
        internal.deinit();
        removeFromRegistry(instance);
    }
    // NOTE: Do NOT call runtime.Instance.deinit() - GC layer handles slab freeing
}

/// Constructor implementation
/// Spec: https://dom.spec.whatwg.org/#dom-eventtarget-eventtarget
pub fn call_constructor(ctx: runtime.Context) !*runtime.Instance {
    // Create instance through init()
    const instance = try init(ctx.allocator, State, &EventTarget.vtable, ctx);
    errdefer deinit(instance);

    // Note: EventTarget.State.own is empty struct, so no _internal field
    // For now, we'll manage internal state separately
    // TODO: Add _internal field to State via codegen

    return instance;
}

/// Initialize an EventTarget with internal state
/// This is called by subclasses (like Node) to set up the internal state
pub fn initInternal(instance: *runtime.Instance, allocator: std.mem.Allocator) !*InternalState {
    const ArenaAllocator = @import("runtime").ArenaAllocator;
    const internal = try ArenaAllocator.get().create(InternalState);
    internal.* = InternalState.init(allocator);

    // Store internal state in registry (ensure it's initialized first)
    try setInternalInRegistry(instance, internal);

    return internal;
}

/// Global registry for internal state
/// This is a workaround until the codegen adds _internal field to State
///
/// Every EventTarget of every thread is here - a Browser's thread and each of
/// its workers' (docs/instances.md) - so the map is reached only under
/// `mutex`. A value is a block its instance's thread allocated and frees, so
/// a pointer read under the lock stays good after it; what an entry holds of
/// the engine (listeners' callbacks, event handlers) is released OUTSIDE the
/// lock, on the entry's own thread (`releaseEntry`).
const Registry = struct {
    /// Protects `map`, `guard` and `cleanup_hook_registered`; held for one
    /// map operation or one sweep of the map, never across a call that can
    /// reach the engine or script.
    mutex: std.Io.Mutex = .init,
    map: ?std.AutoHashMap(usize, *InternalState) = null,
    cleanup_hook_registered: bool = false,
    /// Every EventTarget - every node - a page makes enters the registry and
    /// leaves it; the guard rehashes before an insert once the tombstones
    /// those removals leave could take half the free slots
    /// (webidl.utils.tombstones).
    guard: webidl.utils.tombstones.TombstoneGuard = .{},

    fn lock(self: *Registry) void {
        std.Io.Threaded.mutexLock(&self.mutex);
    }

    fn unlock(self: *Registry) void {
        std.Io.Threaded.mutexUnlock(&self.mutex);
    }

    /// The map, made on first use. Called with `mutex` held.
    fn ensure(self: *Registry) *std.AutoHashMap(usize, *InternalState) {
        if (self.map == null) {
            self.map = std.AutoHashMap(usize, *InternalState).init(std.heap.page_allocator);
            // Register cleanup hook on first use
            if (!self.cleanup_hook_registered) {
                runtime.registerCleanupHook(cleanupRegistry);
                self.cleanup_hook_registered = true;
            }
        }
        return &self.map.?;
    }

    /// Take `key`'s entry out of the map. Called with `mutex` held; the
    /// caller releases it (`releaseEntry`) after unlocking.
    fn take(self: *Registry, key: usize) ?*InternalState {
        const map = &(self.map orelse return null);
        const kv = map.fetchRemove(key) orelse return null;
        self.guard.noteRemoval(map);
        return kv.value;
    }

    /// The whole map, taken out for a final sweep. Called with `mutex` held.
    fn takeAll(self: *Registry) ?std.AutoHashMap(usize, *InternalState) {
        const map = self.map orelse return null;
        self.map = null;
        // So the hook can be registered again if the runtime is.
        self.cleanup_hook_registered = false;
        self.guard.reset();
        return map;
    }
};
var internal_state_registry: Registry = .{};

/// Clean up all remaining internal states, releasing the engine values they
/// hold (listeners' callbacks, event handlers). This should be called during
/// browser/context cleanup, BEFORE the agent is destroyed.
///
/// This is called from cleanup.cleanupAllDomRegistries() which runs before
/// runtime.deinitializeRuntime(), while the agent is still alive - and after
/// every worker of the Browser has ended, so every entry left is this
/// thread's.
pub fn cleanupAllRemainingInternal() void {
    const registry = &internal_state_registry;
    registry.lock();
    var taken = registry.takeAll();
    registry.unlock();
    if (taken) |*map| {
        // Clean up all internal states with V8 resource cleanup enabled
        var iter = map.valueIterator();
        while (iter.next()) |internal_ptr| {
            internal_ptr.*.deinitEx(true); // the agent is alive: release its values
        }
        map.deinit();
    }
}

/// Clean up all remaining internal states and the registry itself
/// This should be called during runtime shutdown to prevent memory leaks
/// Note: This is called AFTER V8 isolate is disposed, so we must skip V8 resource cleanup
pub fn cleanupRegistry() void {
    const registry = &internal_state_registry;
    registry.lock();
    var taken = registry.takeAll();
    registry.unlock();
    if (taken) |*map| {
        // Clean up any remaining internal states
        // Skip V8 cleanup (false) because the isolate is already disposed
        var iter = map.valueIterator();
        while (iter.next()) |internal_ptr| {
            internal_ptr.*.deinitEx(false);
        }
        map.deinit();
    }
}

fn getInternalFromRegistry(instance: *runtime.Instance) ?*InternalState {
    const registry = &internal_state_registry;
    registry.lock();
    const map = registry.ensure();
    const internal = map.get(@intFromPtr(instance)) orelse {
        registry.unlock();
        return null;
    };
    // INTERIM until every EventTarget impl chains init/deinit (queue): an
    // entry made lazily for an instance that has since been freed, whose slot
    // this instance now has. The listeners are the dead instance's: they go
    // now - its realm still lives, or its end would have released the entry -
    // and this instance has none.
    if (internal.lazy) |lazy| {
        if (lazy.generation != runtime.SlabAllocator.generationOf(instance)) {
            const stale = registry.take(@intFromPtr(instance));
            registry.unlock();
            if (stale) |entry| releaseEntry(entry);
            return null;
        }
    }
    registry.unlock();
    return internal;
}

fn setInternalInRegistry(instance: *runtime.Instance, internal: *InternalState) !void {
    const registry = &internal_state_registry;
    var stale: ?*InternalState = null;
    defer if (stale) |entry| releaseEntry(entry);
    registry.lock();
    defer registry.unlock();
    const map = registry.ensure();
    // A lazily made entry still under this address is a freed instance's
    // (see `LazyEntry`): it goes before the new one takes its place, rather
    // than being overwritten with its listeners still held.
    if (map.get(@intFromPtr(instance))) |old| {
        if (old != internal and old.lazy != null) stale = registry.take(@intFromPtr(instance));
    }
    registry.guard.beforeInsert(map);
    try map.put(@intFromPtr(instance), internal);
}

/// The entry for an instance that never ran EventTarget's init (see
/// `LazyEntry`), made on its first addEventListener.
fn lazyInternal(instance: *runtime.Instance) !*InternalState {
    if (getInternalFromRegistry(instance)) |internal| return internal;
    const ArenaAllocator = @import("runtime").ArenaAllocator;
    const internal = try ArenaAllocator.get().create(InternalState);
    errdefer ArenaAllocator.get().destroy(InternalState, internal);
    internal.* = InternalState.init(std.heap.page_allocator);
    internal.lazy = .{ .realm = instance.ctx, .generation = runtime.SlabAllocator.generationOf(instance) };
    try setInternalInRegistry(instance, internal);
    return internal;
}

/// Release an entry taken out of the registry and what it holds - its
/// listeners' callbacks and its event handlers. Only for an entry whose
/// realm's agent lives, on that agent's thread, with the registry unlocked.
fn releaseEntry(internal: *InternalState) void {
    internal.deinitEx(true);
    const Arena = @import("runtime").ArenaAllocator;
    if (Arena.tryGet() catch null) |arena| arena.destroy(InternalState, internal);
}

/// EventTarget's unloading cleanup step (dom.unloading_cleanup): the entries
/// made lazily for `environment`'s instances leave with it - nothing else
/// removes them (see `LazyEntry`) - and what they hold is released now,
/// while the realm's agent lives. A worker's agent ends right after its
/// realm, and the browser's end, which releases whatever is left here, is
/// too late for it.
fn releaseRealmEntries(environment: runtime.Context) void {
    const registry = &internal_state_registry;
    var doomed: std.ArrayListUnmanaged(*InternalState) = .empty;
    defer doomed.deinit(std.heap.page_allocator);
    {
        registry.lock();
        defer registry.unlock();
        const map = &(registry.map orelse return);
        var keys: std.ArrayListUnmanaged(usize) = .empty;
        defer keys.deinit(std.heap.page_allocator);
        var it = map.iterator();
        while (it.next()) |entry| {
            const lazy = entry.value_ptr.*.lazy orelse continue;
            if (lazy.realm == environment) keys.append(std.heap.page_allocator, entry.key_ptr.*) catch continue;
        }
        // Room first: an entry taken out must reach `releaseEntry`. Out of
        // memory, the entries stay in the map for the Browser's end.
        doomed.ensureTotalCapacity(std.heap.page_allocator, keys.items.len) catch return;
        for (keys.items) |key| {
            const taken = registry.take(key) orelse continue;
            doomed.appendAssumeCapacity(taken);
        }
    }
    for (doomed.items) |internal| releaseEntry(internal);
}

fn removeFromRegistry(instance: *runtime.Instance) void {
    const registry = &internal_state_registry;
    registry.lock();
    const taken = registry.take(@intFromPtr(instance));
    registry.unlock();
    // Return the block, not just the map entry. EventTarget keeps its own registry
    // rather than using InstanceRegistry, so it needs its own release - and it is on
    // every DOM node, so leaving it out keeps the leak on the hottest path there is.
    if (taken) |internal| {
        const Arena = @import("runtime").ArenaAllocator;
        if (Arena.tryGet() catch null) |arena| arena.destroy(InternalState, internal);
    }
}

/// DOM §2.7 - default passive value
/// The default passive value, given an event type type and an EventTarget eventTarget
fn defaultPassiveValue(@"type": []const u8, event_target: *runtime.Instance) bool {
    _ = event_target;
    // Step 1: Return true if type is touchstart, touchmove, wheel, or mousewheel
    // AND eventTarget is Window or specific node conditions
    // For now, simplified: return true for touch/wheel events
    if (std.mem.eql(u8, @"type", "touchstart") or
        std.mem.eql(u8, @"type", "touchmove") or
        std.mem.eql(u8, @"type", "wheel") or
        std.mem.eql(u8, @"type", "mousewheel"))
    {
        // TODO: Check eventTarget conditions per spec
        return true;
    }
    // Step 2: Return false
    return false;
}

/// DOM "event listener whose callback is callback": two callback interface
/// values are the same listener's when they are the same object (SameValue).
fn callbackEquals(realm: runtime.Context, a: ?engine.CallbackInterface, b: ?engine.CallbackInterface) bool {
    const x = a orelse return b == null;
    const y = b orelse return false;
    return engine.sameValue(realm, x.object.value, y.object.value);
}

threadlocal var next_listener_id: u64 = 1;

/// Free what a listener record owns - its type string and its callback -
/// for a record that was never stored, or has just left the list.
fn releaseRecord(internal: *InternalState, record: EventListenerRecord) void {
    var record_type = record.type;
    record_type.deinit(internal.allocator);
    if (record.callback) |callback| callback.release();
}

/// The abort steps of "add an event listener" step 6, as the signal holds
/// them. The signal owns this: `run` frees it, and so does `drop` when the
/// signal is collected unaborted. The target is held by address and slab
/// generation, because it can be collected first - nothing V8 sees keeps it
/// alive for the signal's sake - and the listener by id. A listener removed
/// some other way leaves this in place until the signal aborts or dies,
/// where it finds nothing and only frees itself.
const SignalRemoval = struct {
    target: *runtime.Instance,
    target_generation: u64,
    listener_id: u64,

    fn run(ctx: *anyopaque) void {
        const self: *SignalRemoval = @ptrCast(@alignCast(ctx));
        defer std.heap.page_allocator.destroy(self);
        // "Remove an event listener with eventTarget and listener."
        if (runtime.SlabAllocator.generationOf(self.target) != self.target_generation) return;
        const internal = getInternalFromRegistry(self.target) orelse return;
        const list = internal.event_listener_list orelse return;
        const slice = list.toSliceMut();
        for (slice, 0..) |*existing, i| {
            if (existing.id != self.listener_id) continue;
            existing.removed = true;
            releaseRecord(internal, existing.*);
            _ = list.remove(i) catch unreachable;
            return;
        }
    }

    fn drop(ctx: *anyopaque) void {
        const self: *SignalRemoval = @ptrCast(@alignCast(ctx));
        std.heap.page_allocator.destroy(self);
    }
};

/// DOM §2.7 - add an event listener
/// To add an event listener, given an EventTarget object eventTarget and
/// an event listener listener, run these steps. The record's type string and
/// callback wrapper are this function's to store or free.
fn addAnEventListener(internal: *InternalState, instance: *runtime.Instance, listener: EventListenerRecord) !void {
    // Step 1: ServiceWorkerGlobalScope warning (skipped - not applicable)

    // Step 2: If listener's signal is not null and is aborted, then return
    if (listener.signal) |signal| {
        if (interfaces.AbortSignal.get_aborted(signal) catch false) {
            releaseRecord(internal, listener);
            return;
        }
    }

    // Step 3: If listener's callback is null, then return
    if (listener.callback == null) {
        releaseRecord(internal, listener);
        return;
    }

    // Step 4: If listener's passive is null, set it to default passive value
    var updated_listener = listener;
    if (updated_listener.passive == null) {
        updated_listener.passive = defaultPassiveValue(listener.type.asSlice(), instance);
    }

    // Step 5: If event listener list does not contain matching listener, append it
    const list = try internal.ensureEventListenerList();
    const slice = list.toSlice();

    var already_exists = false;
    for (slice) |existing| {
        if (existing.event_handler) continue;
        if (std.mem.eql(u8, existing.type.asSlice(), listener.type.asSlice()) and
            existing.capture == listener.capture and
            callbackEquals(instance.ctx, existing.callback, listener.callback))
        {
            already_exists = true;
            break;
        }
    }

    if (already_exists) {
        // Listener already exists - clean up the duplicate resources. Its
        // abort steps (step 6) would remove a listener that was never
        // appended, which does nothing, so none are added.
        releaseRecord(internal, updated_listener);
        return;
    }

    updated_listener.id = next_listener_id;
    next_listener_id += 1;
    list.append(updated_listener) catch |err| {
        releaseRecord(internal, updated_listener);
        return err;
    };

    // Step 6: If listener's signal is not null, then add the following abort
    // steps to it: remove an event listener with eventTarget and listener.
    if (listener.signal) |signal| {
        const removal = try std.heap.page_allocator.create(SignalRemoval);
        removal.* = .{
            .target = instance,
            .target_generation = runtime.SlabAllocator.generationOf(instance),
            .listener_id = updated_listener.id,
        };
        // The listener is stored; failing to arm its removal leaves it
        // registered, as an allocation failure anywhere else would.
        abort_algorithms.add(signal, .{ .ctx = removal, .run = SignalRemoval.run, .drop = SignalRemoval.drop }) catch
            std.heap.page_allocator.destroy(removal);
    }
}

/// DOM §2.7 - remove an event listener
/// To remove an event listener, given an EventTarget object eventTarget and
/// an event listener listener, run these steps:
fn removeAnEventListener(internal: *InternalState, realm: runtime.Context, listener: EventListenerRecord) void {
    // Step 1: ServiceWorkerGlobalScope warning (skipped - not applicable)

    // Early exit if no listeners have been added yet
    const list = internal.event_listener_list orelse return;

    // Step 2: Set listener's removed to true and remove listener from event listener list
    const slice = list.toSliceMut();
    var i: usize = 0;
    while (i < list.len) {
        const existing = &slice[i];

        // An event handler's listener is removed only by deactivating the
        // handler, never by removeEventListener (its callback is internal).
        if (existing.event_handler) {
            i += 1;
            continue;
        }

        // Match on type, callback, and capture
        if (std.mem.eql(u8, existing.type.asSlice(), listener.type.asSlice()) and
            existing.capture == listener.capture and
            callbackEquals(realm, existing.callback, listener.callback))
        {
            existing.removed = true;

            // The record's callback goes with it.
            if (existing.callback) |callback| callback.release();

            // Free the type DOMString
            var existing_type = existing.type;
            existing_type.deinit(internal.allocator);

            _ = list.remove(i) catch unreachable;
            return;
        }
        i += 1;
    }
}

/// Each Window's "current event" (HTML), which `window.event` returns: the
/// event whose listener is running in that Window's realm, else undefined.
/// DOM's inner invoke (steps 2.8-2.10, 2.13) sets it around every listener
/// call and restores the previous value afterwards, so nested dispatch unwinds
/// correctly. Kept here, beside the dispatch that owns it; entries restored to
/// null are dropped, so the list only ever holds windows mid-dispatch.
const CurrentEvent = struct {
    window: *runtime.Instance,
    event: *runtime.Instance,
};
var current_events: std.ArrayListUnmanaged(CurrentEvent) = .empty;

/// `window`'s current event, or null for undefined.
pub fn currentEvent(window: *runtime.Instance) ?*runtime.Instance {
    for (current_events.items) |entry| {
        if (entry.window == window) return entry.event;
    }
    return null;
}

/// Set `window`'s current event to `event`, returning the previous one.
fn swapCurrentEvent(window: *runtime.Instance, event: ?*runtime.Instance) ?*runtime.Instance {
    for (current_events.items, 0..) |*entry, i| {
        if (entry.window != window) continue;
        const previous = entry.event;
        if (event) |e| entry.event = e else _ = current_events.swapRemove(i);
        return previous;
    }
    if (event) |e| current_events.append(std.heap.c_allocator, .{ .window = window, .event = e }) catch {};
    return null;
}

/// The next event handler's serial. Atomic: event handlers are set on every
/// thread that runs script - a Browser's and each worker's.
var next_handler_serial: std.atomic.Value(u32) = .init(1);

/// HTML "activate an event handler", steps 3-7.
/// https://html.spec.whatwg.org/multipage/webappapis.html#activate-an-event-handler
///
/// Called whenever an event handler's value is set to non-null. If the
/// handler's listener is already in the list it stays where it is (step 3);
/// otherwise a listener for `event_type` whose callback is the event handler
/// processing algorithm is appended, AFTER every listener added so far - which
/// is the ordering "the event listeners registered with addEventListener()
/// before the first time the event handler's value was set to non-null, then
/// the callback, then the ones registered after" depends on.
pub fn activateEventHandler(instance: *runtime.Instance, event_type: []const u8) !void {
    const internal = getInternalFromRegistry(instance) orelse return;
    const list = try internal.ensureEventListenerList();

    // Step 3: If eventHandler's listener is not null, then return.
    for (list.toSlice()) |existing| {
        if (existing.event_handler and !existing.removed and
            std.mem.eql(u8, existing.type.asSlice(), event_type)) return;
    }

    // Steps 4-6: a listener whose type is the event handler event type and
    // whose callback runs the event handler processing algorithm. "Add an
    // event listener" gives it the default passive value (step 4 there).
    var serial = next_handler_serial.fetchAdd(1, .monotonic);
    // 0 means "no handler": a wrapped counter skips it.
    if (serial == 0) serial = next_handler_serial.fetchAdd(1, .monotonic);
    try list.append(.{
        .type = try runtime.DOMString.initDupe(internal.allocator, event_type),
        .callback = null,
        .passive = defaultPassiveValue(event_type, instance),
        .event_handler = true,
        .handler_serial = serial,
    });
}

/// HTML "deactivate an event handler", steps 3-5.
/// https://html.spec.whatwg.org/multipage/webappapis.html#deactivate-an-event-handler
///
/// Called when an event handler's value is set to null: its listener is
/// removed, so a later non-null assignment re-activates it at the END.
pub fn deactivateEventHandler(instance: *runtime.Instance, event_type: []const u8) void {
    const internal = getInternalFromRegistry(instance) orelse return;
    const list = internal.event_listener_list orelse return;
    const slice = list.toSliceMut();
    for (slice, 0..) |*existing, i| {
        if (!existing.event_handler) continue;
        if (!std.mem.eql(u8, existing.type.asSlice(), event_type)) continue;
        existing.removed = true;
        var existing_type = existing.type;
        existing_type.deinit(internal.allocator);
        _ = list.remove(i) catch {};
        return;
    }
}

/// HTML "erase all event listeners and handlers" given `target` (§8.1.8.1),
/// which document.open() runs over a document's nodes and its window.
/// "1. If eventTarget has an associated event handler map, then for each
/// name -> eventHandler of eventTarget's associated event handler map,
/// deactivate an event handler given eventTarget and name. 2. Remove all
/// event listeners given eventTarget."
pub fn eraseAllEventListenersAndHandlers(target: *runtime.Instance) void {
    const internal = getInternalFromRegistry(target) orelse return;
    // Step 1: every handler's value goes - the map owns each one - and so
    // does its listener, which step 2 removes with the rest.
    if (internal.event_handler_map) |map| {
        var values = map.valueIterator();
        while (values.next()) |value| value.release();
        map.clearRetainingCapacity();
    }
    // Step 2: DOM "remove all event listeners" - for each listener, "remove
    // an event listener": its removed flag set, then out of the list, and
    // what its record owns released. Dispatch looks listeners up by id in
    // this list, and the flag keeps honest anything holding a copy.
    const list = internal.event_listener_list orelse return;
    while (list.len > 0) {
        const index = list.len - 1;
        const slot = &list.toSliceMut()[index];
        slot.removed = true;
        const record = slot.*;
        _ = list.remove(index) catch break;
        releaseRecord(internal, record);
    }
}

/// "Getting the current value of the event handler" (HTML §8.1.8.1) for
/// `target`'s handler for `event_type`: its value, or null. Handlers are
/// compiled when their content attribute is set (Element's event handler
/// content attribute steps), so there is no uncompiled value to compile here.
pub fn eventHandler(comptime Handler: type, target: *runtime.Instance, event_type: []const u8) Handler {
    const address = (eventHandlerValue(target, event_type) orelse return null).address;
    // The address is the function's Global (conversions.zig stores it
    // untagged, aligned as a function pointer must be). No pointer cast turns
    // it into the callback type, so it is copied byte for byte, as
    // conversions.zig does.
    const Callable = @typeInfo(Handler).optional.child;
    comptime std.debug.assert(@sizeOf(Callable) == @sizeOf(usize));
    var handler: Callable = undefined;
    @memcpy(std.mem.asBytes(&handler), std.mem.asBytes(&address));
    return handler;
}

/// The event handler IDL attribute setter's steps 3 and 4 (HTML §8.1.8.1) on
/// `target`: null deactivates the handler; any other value becomes the
/// handler's value, which is then activated.
pub fn setEventHandler(comptime Handler: type, target: *runtime.Instance, event_type: []const u8, value: Handler) !void {
    const internal = getInternalFromRegistry(target) orelse return error.InvalidStateError;
    // Step 3: "If the given value is null, then deactivate an event handler
    // given eventTarget and name."
    const handler = value orelse {
        if (internal.event_handler_map) |map| {
            if (map.fetchRemove(event_type)) |old| old.value.release();
        }
        deactivateEventHandler(target, event_type);
        return;
    };
    // Step 4: set eventHandler's value to the given value, then activate it.
    // The map takes the binding's value over from here.
    var address: usize = undefined;
    @memcpy(std.mem.asBytes(&address), std.mem.asBytes(&handler));
    const handler_value: HandlerValue = .{
        .callback = engine.takeCallbackFunction(@ptrFromInt(address)),
        .address = address,
    };
    const map = internal.event_handler_map orelse blk: {
        const created = internal.allocator.create(std.StringHashMapUnmanaged(HandlerValue)) catch |err| {
            handler_value.release();
            return err;
        };
        created.* = .empty;
        internal.event_handler_map = created;
        break :blk created;
    };
    const old = map.fetchPut(internal.allocator, event_type, handler_value) catch |err| {
        handler_value.release();
        return err;
    };
    if (old) |replaced| replaced.value.release();
    try activateEventHandler(target, event_type);
}

fn getHandlerAddress(target: *runtime.Instance, event_type: []const u8) ?usize {
    return (eventHandlerValue(target, event_type) orelse return null).address;
}

fn setHandlerAddress(target: *runtime.Instance, event_type: []const u8, address: ?usize) anyerror!void {
    const Handler = typedefs.EventHandler;
    const Callable = @typeInfo(Handler).optional.child;
    comptime std.debug.assert(@sizeOf(Callable) == @sizeOf(usize));
    var handler: Handler = null;
    if (address) |value| {
        var function: Callable = undefined;
        @memcpy(std.mem.asBytes(&function), std.mem.asBytes(&value));
        handler = function;
    }
    try setEventHandler(Handler, target, event_type, handler);
}

/// An event handler's value in the map: the callback function the binding
/// converted the setter's argument to (OWNED by the map), and the address the
/// binding handed over, which the getter returns as it was given. A running
/// handler holds a value of its own (invokeIdlEventHandler), so
/// `this.onclick = null` inside one is safe.
const HandlerValue = struct {
    callback: engine.CallbackFunction,
    /// The binding's representation of the same function - BORROWED from
    /// `callback`, and valid while it is held.
    address: usize,

    fn release(self: HandlerValue) void {
        self.callback.release();
    }
};

/// `target`'s event handler map entry for `event_type`, for the getter and
/// for dispatch.
fn eventHandlerValue(target: *runtime.Instance, event_type: []const u8) ?HandlerValue {
    const internal = getInternalFromRegistry(target) orelse return null;
    const map = internal.event_handler_map orelse return null;
    return map.get(event_type);
}

/// Operation: addEventListener
/// Spec: https://dom.spec.whatwg.org/#dom-eventtarget-addeventlistener
/// "flatten", https://dom.spec.whatwg.org/#concept-flatten-options
///
/// The IDL type is `(AddEventListenerOptions or boolean) options = {}`. Codegen
/// does not generate WebIDL union types yet, so it arrives as a raw JSValue and
/// the impl has to resolve the union itself. WebIDL union resolution: if the
/// value is an OBJECT, convert to the dictionary; otherwise apply ECMAScript
/// ToBoolean.
///
/// ToBoolean is the part that is easy to get wrong, and
/// dom/events/EventListenerOptions-capture.html tests exactly these:
///
///     true, "AAAA", 2.3, -1000.3   -> capture      (truthy)
///     false, null, undefined, ""   -> no capture
///     NaN, +0.0, -0.0              -> no capture
///
/// An earlier version of this matched only `.boolean` and returned false for
/// everything else, so `addEventListener(t, fn, 2.3)` and
/// `addEventListener(t, fn, "AAAA")` silently registered as bubble listeners.
/// That is wrong for ordinary JavaScript, not just for any one framework.
///
/// This was previously `_ = options;` with capture hardcoded false, which
/// downgraded EVERY capture listener to a bubble listener.
fn toBoolean(value: runtime.JSValue) bool {
    return switch (value) {
        .undefined, .null => false,
        .boolean => |b| b,
        // +0, -0 and NaN are falsy; every other number is truthy.
        .number => |n| n != 0 and !std.math.isNan(n),
        .string => |sv| sv.data.len > 0,
        // Objects and functions are always truthy - but an object means the
        // DICTIONARY branch, so reaching here with one is a fallback only.
        else => true,
    };
}

/// The flattened options. `capture` is always resolved; the rest come only from
/// the dictionary form.
const FlatOptions = struct {
    capture: bool = false,
    once: bool = false,
    passive: ?bool = null,
    signal: ?*runtime.Instance = null,
};

/// DOM "flatten" (`more` false: removeEventListener reads only `capture`)
/// and "flatten more" (addEventListener).
///
/// `options` is `(EventListenerOptions or boolean)` or
/// `(AddEventListenerOptions or boolean)`, which reaches the impl
/// unconverted: an OBJECT converts to the dictionary and anything else goes
/// through ToBoolean. The dictionary's members are read as WebIDL 3.2.18
/// converts one - EventListenerOptions' `capture` first, then `once`,
/// `passive`, `signal` - and a throwing getter propagates.
fn flattenOptions(ctx: runtime.Context, options: webidl.Opt(runtime.JSValue), comptime more: bool) !FlatOptions {
    if (!options.was_passed) return .{};

    if (options.value == .handle) {
        const realm = engine.currentRealm() orelse ctx;
        const object = options.value;

        // Members are ToBoolean-converted, so `{capture: 2}` is capture and
        // `{capture: 0}` is not - EventListenerOptions-capture.html.
        var flat: FlatOptions = .{ .capture = (try engine.getPropertyBoolean(realm, object, "capture")) orelse false };
        if (!more) return flat;

        flat.once = (try engine.getPropertyBoolean(realm, object, "once")) orelse false;
        // "If options[passive] exists": absent leaves the default passive
        // value to decide, which is not the same as `passive: false`.
        flat.passive = try engine.getPropertyBoolean(realm, object, "passive");
        // `signal` is an AbortSignal, not nullable: anything else - null
        // included - fails the member's conversion.
        if (try engine.getPropertyPlatformObject(realm, object, "signal")) |signal| {
            if (signal.stateAs(interfaces.AbortSignal.State) == null) return error.TypeError;
            flat.signal = signal;
        }
        return flat;
    }

    return .{ .capture = toBoolean(options.value) };
}

pub fn call_addEventListener(instance: *runtime.Instance, @"type": runtime.DOMString, callback: ??*runtime.CallbackWrapper, options: webidl.Opt(runtime.JSValue)) anyerror!void {
    // Get the internal state, or make it for an instance that never ran
    // EventTarget's init.
    const internal = lazyInternal(instance) catch return error.OutOfMemory;

    // https://dom.spec.whatwg.org/#concept-flatten-more
    const flat = try flattenOptions(instance.ctx, options, true);
    const capture = flat.capture;
    const passive = flat.passive;
    const once = flat.once;
    const signal = flat.signal;

    // The callback interface value, with the incumbent realm now - the
    // conversion's - as its callback context. The binding's wrapper is the
    // call's; the listener keeps a value of its own.
    const callback_value: ?engine.CallbackInterface = if (callback) |cb_opt| blk: {
        const wrapper = cb_opt orelse break :blk null;
        break :blk engine.takeCallbackInterface(wrapper);
    } else null;

    // Duplicate the type string with internal allocator to ensure ownership
    // The incoming DOMString may be allocated with a different allocator (from V8 conversion layer)
    // and we need to own it to safely free it in deinit()
    const owned_type = runtime.DOMString.initDupe(internal.allocator, @"type".asSlice()) catch {
        if (callback_value) |value| value.release();
        return error.OutOfMemory;
    };

    // Create listener record with owned type string
    const listener = EventListenerRecord{
        .type = owned_type,
        .callback = callback_value,
        .capture = capture,
        .passive = passive,
        .once = once,
        .signal = signal,
    };

    // It stores or frees the record's type and callback on every path.
    try addAnEventListener(internal, instance, listener);
}

/// Operation: removeEventListener
/// Spec: https://dom.spec.whatwg.org/#dom-eventtarget-removeeventlistener
pub fn call_removeEventListener(instance: *runtime.Instance, @"type": runtime.DOMString, callback: ??*runtime.CallbackWrapper, options: webidl.Opt(runtime.JSValue)) anyerror!void {
    // The binding's wrapper, borrowed for the call.
    const raw_callback_wrapper: ?*runtime.CallbackWrapper = if (callback) |cb_opt| cb_opt else null;

    const internal = getInternalFromRegistry(instance) orelse return;

    // https://dom.spec.whatwg.org/#concept-flatten
    //
    // Removal matches on type, callback AND capture, so discarding the flag
    // here meant `removeEventListener(t, fn, true)` could never find the
    // listener that `addEventListener(t, fn, true)` added.
    const capture = (try flattenOptions(instance.ctx, options, false)).capture;

    // The callback interface value, for the comparison only.
    const callback_value: ?engine.CallbackInterface = if (raw_callback_wrapper) |wrapper| engine.takeCallbackInterface(wrapper) else null;
    defer if (callback_value) |value| value.release();

    // Create listener record for matching
    const listener = EventListenerRecord{
        .type = @"type",
        .callback = callback_value,
        .capture = capture,
    };

    removeAnEventListener(internal, instance.ctx, listener);
}

/// Operation: dispatchEvent
/// Spec: https://dom.spec.whatwg.org/#dom-eventtarget-dispatchevent
pub fn call_dispatchEvent(instance: *runtime.Instance, event: *runtime.Instance) anyerror!bool {
    return dispatchEventWithTrust(instance, event, false, null);
}

/// DOM 2.10 "fire an event", for an event the user agent has already created
/// and initialized: dispatch it with isTrusted true. Script's dispatchEvent()
/// is the only thing that makes an event untrusted. Subtypes call this
/// directly; code outside the hierarchy goes through `dom.fire_event`.
pub fn dispatchTrusted(target: *runtime.Instance, event: *runtime.Instance) !bool {
    return dispatchEventWithTrust(target, event, true, null);
}

fn dispatchTrustedWithThrows(target: *runtime.Instance, event: *runtime.Instance, did_throw: *bool) anyerror!bool {
    return dispatchEventWithTrust(target, event, true, did_throw);
}

/// dispatchEvent()'s steps with isTrusted given: false for script (DOM 2.8
/// step 2), true when the user agent fires the event.
fn dispatchEventWithTrust(instance: *runtime.Instance, event: *runtime.Instance, trusted: bool, did_throw: ?*bool) anyerror!bool {
    const EventImpl = @import("Event.zig");

    // Step 1: If event's dispatch flag is set, or if its initialized flag is not
    //         set, then throw an "InvalidStateError" DOMException.
    //
    // The initialized-flag half is not optional: `document.createEvent("Event")`
    // hands back an event with the flag UNSET, and dispatching it must throw
    // until `initEvent` runs. Skipping the check made 8 subtests of
    // EventTarget-dispatchEvent.html report "did not throw".
    if (EventImpl.getDispatchFlag(event)) return error.InvalidStateError;
    if (!EventImpl.getInitializedFlag(event)) return error.InvalidStateError;

    // Step 2: Initialize event's isTrusted attribute to false - or, for an
    // event the user agent fires, true.
    EventImpl.setIsTrusted(event, trusted);

    // Step 3: Return the result of dispatching event to this
    return dispatchWithThrowFlag(instance, event, did_throw);
}

// ============================================================================
// DOM §2.9 - Dispatching events
// https://dom.spec.whatwg.org/#concept-event-dispatch
// ============================================================================

/// One struct of the event path, per "append to an event path" (DOM §2.9).
///
/// The shadow-tree booleans and the touch target list live on Event's own
/// `EventPathItem`, which this is mirrored into so `composedPath()` can see the
/// path while listeners run.
const PathStruct = struct {
    /// invocation target: whose event listener list is consulted.
    invocation_target: *runtime.Instance,
    /// shadow-adjusted target: non-null exactly where the event is AT_TARGET.
    shadow_adjusted_target: ?*runtime.Instance,
    related_target: ?*runtime.Instance,
};

/// The two values the spec's `phase` argument to "invoke" can take.
const ListenerPhase = enum { capturing, bubbling };

/// What "inner invoke" needs from a listener, captured before any callback runs.
///
/// The spec clones the event listener LIST, whose entries are live objects: a
/// listener removed mid-dispatch is skipped through its `removed` field, and one
/// added mid-dispatch is simply not in the clone. Our records sit in the list by
/// value and `removeAnEventListener` frees the record's type string, so a value
/// copy would dangle the moment a callback removed something. Capturing identity
/// instead - and re-checking the live list immediately before each call - gives
/// both spec properties without holding a pointer into a list the callbacks we
/// are about to run can mutate.
const Invocation = struct {
    /// The listener's record id - unique per "add an event listener", so it
    /// distinguishes "still the listener we cloned" from "removed and
    /// re-added". 0 for an event handler's listener, which is identified by
    /// `handler_serial` instead.
    listener_id: u64,
    handler_serial: u32 = 0,
    capture: bool,
    once: bool,
    passive: bool,
};

/// Guard against a cycle in parent pointers turning dispatch into a hang.
/// No real tree is anywhere near this deep.
const max_event_path_depth: usize = 8192;

/// DOM §2.9 - get the parent
///
/// https://dom.spec.whatwg.org/#get-the-parent - "A node's get the parent
/// algorithm, given an event, returns the node's assigned slot, if node is
/// assigned; otherwise node's parent."
///
/// HTML overrides it for Document: return null if event's type is "load" or the
/// document has no browsing context, and the document's relevant global object
/// (its Window) otherwise. That override is the whole difference between the two
/// halves of Event-dispatch-bubbles-true.html, which expects `window` in a
/// click's path and not in a load's.
fn getTheParent(target: *runtime.Instance, event_type: []const u8) ?*runtime.Instance {
    // node_type is EventTarget's duck-typing discriminator: 0 for a plain
    // EventTarget (and for Window, which therefore ends the path).
    const node_type = getNodeType(target);
    // IndexedDB: ordinary request -> transaction; open request -> null;
    // transaction -> connection; connection -> null (ED 2.7 and 2.8).
    if (node_type == 0) return dom_module.indexeddb.getTheParent(target);

    if (node_type == interfaces.Node.get_DOCUMENT_NODE()) {
        if (std.mem.eql(u8, event_type, "load")) return null;
        // No browsing context means no defaultView, so one null covers both.
        return interfaces.Document.get_defaultView(target) catch null;
    }

    // "the node's assigned slot, if node is assigned" - the internal one, a
    // closed shadow root's included (the IDL assignedSlot hides those).
    // Element and Text nodes are the slottables.
    if (node_type == interfaces.Node.get_ELEMENT_NODE() or node_type == interfaces.Node.get_TEXT_NODE()) {
        if (dom_module.shadow_dom_algorithms.assignedSlotOf(target)) |slot| return slot;
    }

    return interfaces.Node.get_parentNode(target) catch null;
}

/// DOM §2.9 dispatch, steps 6.3 and 6.8-6.9: build the event path.
///
/// The path is computed ONCE, before any listener runs, which is what
/// Event-dispatch-target-moved.html checks: a listener that moves the target
/// elsewhere in the tree must not change where the rest of the event goes.
fn buildEventPath(
    path: *infra.List(PathStruct),
    target: *runtime.Instance,
    event_type: []const u8,
    related_target: ?*runtime.Instance,
) !void {
    // Step 6.3: append with target as BOTH invocation target and shadow-adjusted
    // target. Being the only struct with a non-null shadow-adjusted target is
    // what makes the target - and only the target - report AT_TARGET.
    try path.append(.{
        .invocation_target = target,
        .shadow_adjusted_target = target,
        .related_target = related_target,
    });

    var parent = getTheParent(target, event_type);
    var depth: usize = 0;
    while (parent) |p| {
        if (depth >= max_event_path_depth) break;
        depth += 1;

        // Step 6.9.6. Without shadow roots in the path, target's root is always
        // a shadow-including inclusive ancestor of every ancestor, so this
        // branch always wins and the shadow-adjusted target is null. The
        // retargeting branches 6.9.7 and 6.9.8 only become reachable once shadow
        // trees are in play; they are a TODO rather than a silent approximation.
        try path.append(.{
            .invocation_target = p,
            .shadow_adjusted_target = null,
            .related_target = related_target,
        });

        parent = getTheParent(p, event_type);
    }
}

/// Mirror the path onto the event so `composedPath()` reports it.
/// Dispatch step 9 empties it again.
fn publishEventPath(event: *runtime.Instance, structs: []const PathStruct, allocator: std.mem.Allocator) void {
    const EventImpl = @import("Event.zig");
    const list = EventImpl.getPath(event) orelse return;
    for (structs) |s| {
        list.append(.{
            .invocation_target = s.invocation_target,
            .invocation_target_in_shadow_tree = false,
            .shadow_adjusted_target = s.shadow_adjusted_target,
            .related_target = s.related_target,
            .touch_target_list = infra.List(*runtime.Instance).init(allocator),
            .root_of_closed_tree = false,
            .slot_in_closed_tree = false,
        }) catch return;
    }
}

/// DOM §2.9 - dispatch
/// https://dom.spec.whatwg.org/#concept-event-dispatch
///
/// Returns false if the event's canceled flag is set, true otherwise.
pub fn dispatch(target: *runtime.Instance, event: *runtime.Instance) !bool {
    return dispatchWithThrowFlag(target, event, null);
}

fn dispatchWithThrowFlag(target: *runtime.Instance, event: *runtime.Instance, did_throw: ?*bool) !bool {
    const EventImpl = @import("Event.zig");
    const allocator = target.ctx.allocator;

    // Step 1: Set event's dispatch flag.
    EventImpl.setDispatchFlag(event, true);

    // Steps 7, 8 and 10 have to happen however we leave.
    errdefer finishDispatch(event);

    // Steps 2-5. targetOverride is target: the legacy target override flag is
    // only ever passed by HTML, and only for a Window. clearTargets (steps 5,
    // 6.10-6.11) needs shadow roots, which do not exist yet.
    const related_target = EventImpl.getRelatedTarget(event);

    // `get_type` hands back a borrowed slice into the event's own storage, and
    // `initEvent` returns early while the dispatch flag is set, so no callback
    // can invalidate it mid-dispatch.
    const event_type_string = interfaces.Event.get_type(event) catch runtime.DOMString.initEmpty();
    const event_type = event_type_string.asSlice();

    // Step 6
    var path = infra.List(PathStruct).init(allocator);
    defer path.deinit();
    try buildEventPath(&path, target, event_type, related_target);
    const structs = path.toSlice();

    publishEventPath(event, structs, allocator);

    // Steps 3, 6.4, 6.5 and 6.9.6.1: activationTarget - the target, if it has
    // activation behaviour, else (for a bubbling event) the first ancestor on
    // the path that has it; only for a MouseEvent named "click". The
    // behaviours are the element types' own (dom.activation).
    const activation_target: ?ActivationTarget = activationTargetOf(structs, event, event_type);

    // Step 12 (6.12 in the spec's numbering): legacy-pre-activation behaviour.
    if (activation_target) |at| {
        if (at.behavior.legacy_pre_activation) |pre| pre(at.target);
    }

    // Step 13: for each struct of event's path, IN REVERSE ORDER, invoke with
    // "capturing".
    var i = structs.len;
    while (i > 0) {
        i -= 1;
        EventImpl.setEventPhase(event, if (structs[i].shadow_adjusted_target != null)
            interfaces.Event.get_AT_TARGET()
        else
            interfaces.Event.get_CAPTURING_PHASE());
        invoke(structs, i, event, .capturing, did_throw);
    }

    // Step 14: for each struct of event's path, in order, invoke with "bubbling".
    const bubbles = interfaces.Event.get_bubbles(event) catch false;
    for (structs, 0..) |s, index| {
        if (s.shadow_adjusted_target != null) {
            // Step 14.1 - the target itself is AT_TARGET in both passes, which
            // is how its capturing listeners run before its bubbling ones.
            EventImpl.setEventPhase(event, interfaces.Event.get_AT_TARGET());
        } else {
            // Step 14.2.1
            if (!bubbles) continue;
            // Step 14.2.2
            EventImpl.setEventPhase(event, interfaces.Event.get_BUBBLING_PHASE());
        }
        invoke(structs, index, event, .bubbling, did_throw);
    }

    // Steps 7, 8, 9 and 10
    finishDispatch(event);

    // Step 11 (clearTargets) is not reachable yet.

    // Step 12: "If activationTarget is non-null: if event's canceled flag is
    // unset, then run activationTarget's activation behavior with event;
    // otherwise, if activationTarget has legacy-canceled-activation behavior,
    // run it."
    // defaultPrevented is the canceled flag ("return true if this's canceled
    // flag is set").
    if (activation_target) |at| {
        if (!(interfaces.Event.get_defaultPrevented(event) catch false)) {
            at.behavior.run(at.target, event);
        } else if (at.behavior.legacy_canceled_activation) |canceled| {
            canceled(at.target);
        }
    }

    // Step 13: return false if event's canceled flag is set; otherwise true.
    return !EventImpl.getCanceledFlag(event);
}

const ActivationTarget = struct {
    target: *runtime.Instance,
    behavior: @import("dom").activation.Behavior,
};

/// DOM dispatch steps 6.4-6.5 and 6.9.6.1 over the built path: with no
/// shadow trees, every parent is appended through step 6.9.6, so the target
/// comes first and each ancestor after it in path order.
fn activationTargetOf(structs: []const PathStruct, event: *runtime.Instance, event_type: []const u8) ?ActivationTarget {
    // Step 6.4: "Let isActivationEvent be true, if event is a MouseEvent
    // object and event's type attribute is "click"; otherwise false."
    if (!std.mem.eql(u8, event_type, "click")) return null;
    if (event.stateAs(interfaces.MouseEvent.State) == null) return null;
    const activation = @import("dom").activation;
    if (structs.len == 0) return null;
    // Step 6.5: the target itself.
    if (activation.of(structs[0].invocation_target)) |behavior| {
        return .{ .target = structs[0].invocation_target, .behavior = behavior };
    }
    // Step 6.9.6.1: an ancestor, only when the event bubbles.
    const bubbles = interfaces.Event.get_bubbles(event) catch false;
    if (!bubbles) return null;
    for (structs[1..]) |s| {
        if (activation.of(s.invocation_target)) |behavior| {
            return .{ .target = s.invocation_target, .behavior = behavior };
        }
    }
    return null;
}

/// Dispatch steps 7-10: leave the event in a state that can be dispatched again.
fn finishDispatch(event: *runtime.Instance) void {
    const EventImpl = @import("Event.zig");
    // Step 7
    EventImpl.setEventPhase(event, interfaces.Event.get_NONE());
    // Step 8
    EventImpl.setCurrentTarget(event, null);
    // Step 9
    EventImpl.clearPath(event);
    // Step 10
    EventImpl.setDispatchFlag(event, false);
    EventImpl.clearPropagationFlags(event);
}

/// DOM §2.9 - invoke
/// https://dom.spec.whatwg.org/#concept-event-listener-invoke
fn invoke(structs: []const PathStruct, index: usize, event: *runtime.Instance, phase: ListenerPhase, did_throw: ?*bool) void {
    const EventImpl = @import("Event.zig");
    const s = structs[index];

    // Step 1: event's target is the shadow-adjusted target of the last struct at
    // or before this one whose shadow-adjusted target is non-null.
    var j = index + 1;
    while (j > 0) {
        j -= 1;
        if (structs[j].shadow_adjusted_target) |shadow_adjusted| {
            EventImpl.setTarget(event, shadow_adjusted);
            break;
        }
    }

    // Step 2
    EventImpl.setRelatedTarget(event, s.related_target);

    // Step 3: event's touch target list - needs UI Events, TODO.

    // Step 4: stopPropagation() ends the walk here, but the caller still has to
    // run steps 7-10, so this returns rather than unwinding.
    if (EventImpl.getStopPropagationFlag(event)) return;

    // Step 5
    EventImpl.setCurrentTarget(event, s.invocation_target);

    // Steps 6-8.
    //
    // Event handler IDL attributes (onclick, onload, ...) run from inside
    // here too: HTML specifies them as ordinary event listeners in the same
    // list, and `activateEventHandler` puts one there, so a handler runs in
    // registration order among the addEventListener listeners - and, being
    // non-capturing, only in the bubbling pass.
    const found = innerInvoke(event, s.invocation_target, phase, did_throw);

    // Step 9: "If found is false and event's isTrusted attribute is true:"
    if (found or !(interfaces.Event.get_isTrusted(event) catch false)) return;
    const event_type = interfaces.Event.get_type(event) catch return;
    // Step 9.2: rename a legacy-mapped type, "and return otherwise".
    const legacy = dom_module.event_dispatch.legacyEventType(event_type.asSlice()) orelse return;
    // Step 9.1: "Let originalEventType be event's type attribute value" -
    // the value the event held, handed back by the rename.
    const original_event_type = dom_module.event_dispatch.swapType(event, runtime.DOMString.initInterned(legacy)) orelse return;
    // Step 9.3: "Inner invoke with event, listeners, phase,
    // invocationTargetInShadowTree, and legacyOutputDidListenersThrowFlag if
    // given." found was false, so no listener ran and the list is still the
    // one step 6 cloned; innerInvoke's own snapshot is that clone.
    _ = innerInvoke(event, s.invocation_target, phase, did_throw);
    // Step 9.4: "Set event's type attribute value to originalEventType."
    _ = dom_module.event_dispatch.swapType(event, original_event_type);
}

/// DOM §2.9 - inner invoke
/// https://dom.spec.whatwg.org/#concept-event-listener-inner-invoke
///
/// Returns `found`: whether any listener matched the event's type, regardless of
/// phase. Only step 9 of "invoke" consumes it.
fn innerInvoke(event: *runtime.Instance, current_target: *runtime.Instance, phase: ListenerPhase, did_throw: ?*bool) bool {
    const EventImpl = @import("Event.zig");

    const internal = getInternalFromRegistry(current_target) orelse return false;
    const list = internal.event_listener_list orelse return false;
    if (list.len == 0) return false;

    const event_type_string = interfaces.Event.get_type(event) catch return false;
    const event_type = event_type_string.asSlice();

    // Step 6 of "invoke": let listeners be a clone of the listener list. See
    // Invocation for why this clones identity rather than the records.
    var snapshot = infra.List(Invocation).init(internal.allocator);
    defer snapshot.deinit();

    var found = false;
    for (list.toSlice()) |record| {
        // Step 2: "for each listener whose removed is false"
        if (record.removed) continue;
        // Step 2.1
        if (!std.mem.eql(u8, record.type.asSlice(), event_type)) continue;
        // Step 2.2
        found = true;
        if (record.callback == null and !record.event_handler) continue;
        snapshot.append(.{
            .listener_id = if (record.event_handler) 0 else record.id,
            .handler_serial = if (record.event_handler) record.handler_serial else 0,
            .capture = record.capture,
            .once = record.once,
            .passive = record.passive orelse false,
        }) catch return found;
    }

    for (snapshot.toSlice()) |candidate| {
        // Steps 2.3 and 2.4 - a capturing listener runs only in the capturing
        // pass, a bubbling one only in the bubbling pass. At the target both
        // passes run, which is why [capture, bubble, capture] fires 1, 3, 2.
        if (phase == .capturing and !candidate.capture) continue;
        if (phase == .bubbling and candidate.capture) continue;

        // The spec's clone holds live listeners, so one an earlier callback
        // removed during this same dispatch is skipped via its removed field.
        // The listener's callback, as the record holds it now.
        const index = findListener(internal, candidate) orelse continue;
        const callback = internal.event_listener_list.?.toSlice()[index].callback;

        // Step 2.5: remove a once listener BEFORE invoking it, so a re-entrant
        // dispatch cannot reach it. Its callback is then this call's to
        // release, after the call.
        var expired: ?engine.CallbackInterface = null;
        if (candidate.once) expired = detachListener(internal, candidate);
        defer if (expired) |value| value.release();

        // Step 2.9
        if (candidate.passive) EventImpl.setInPassiveListenerFlag(event, true);

        // Step 2.11 - an exception is reported, never propagated. An event
        // handler's listener runs the event handler processing algorithm.
        if (candidate.listener_id != 0) {
            if (expired orelse callback) |value| callListener(value, event, current_target, did_throw);
        } else {
            invokeIdlEventHandler(current_target, event, did_throw);
        }

        // Step 2.12
        if (candidate.passive) EventImpl.setInPassiveListenerFlag(event, false);

        // Step 2.14
        if (EventImpl.getStopImmediatePropagationFlag(event)) break;
    }

    // Step 3
    return found;
}

/// Index of a still-registered listener matching `candidate`, or null.
///
/// Identity is the record's id, not the JavaScript function: every "add an
/// event listener" gives a new one, so a listener removed and re-added during
/// a dispatch is correctly treated as one added after the clone was taken.
fn findListener(internal: *InternalState, candidate: Invocation) ?usize {
    const list = internal.event_listener_list orelse return null;
    for (list.toSlice(), 0..) |record, i| {
        if (record.removed) continue;
        if (record.capture != candidate.capture) continue;
        if (candidate.listener_id != 0) {
            if (!record.event_handler and record.id == candidate.listener_id) return i;
        } else if (record.event_handler and record.handler_serial == candidate.handler_serial) {
            return i;
        }
    }
    return null;
}

/// DOM §2.7 "remove an event listener", for inner invoke's step 2.5.
///
/// Returns the callback WITHOUT releasing it - the caller owns it until the
/// callback has finished running.
fn detachListener(internal: *InternalState, candidate: Invocation) ?engine.CallbackInterface {
    const index = findListener(internal, candidate) orelse return null;
    const list = internal.event_listener_list orelse return null;

    list.toSliceMut()[index].removed = true;
    const removed = list.remove(index) catch return null;
    var removed_type = removed.type;
    removed_type.deinit(internal.allocator);

    return removed.callback;
}

/// Inner invoke step 2.11 - "call a user object's operation" with the listener's
/// callback, "handleEvent", « event », and event's currentTarget.
///
/// `callback` is BORROWED: the record's, or the detached once listener's. The
/// call holds a value of its own, since the callback can remove its listener
/// and so release the record's.
fn callListener(callback: engine.CallbackInterface, event: *runtime.Instance, current_target: *runtime.Instance, did_throw: ?*bool) void {
    const realm = current_target.ctx;
    const object = engine.retainValue(realm, callback.object.value) catch |err| {
        log.debug("listener not called: {}", .{err});
        return;
    };
    const held: engine.CallbackInterface = .{ .object = object, .context = callback.context };
    defer held.release();

    // Steps 2.8-2.10: the global of the listener callback's associated realm
    // has the event as its current event for the duration of the call
    // (`window.event`), and step 2.13 restores whatever it was before.
    const listener_window = windowOfRealm(associatedRealm(held.object.value) orelse held.context orelse realm);
    const previous_event = if (listener_window) |w| swapCurrentEvent(w, event) else null;
    defer if (listener_window) |w| {
        _ = swapCurrentEvent(w, previous_event);
    };

    // Step 2.11: call a user object's operation with the listener's callback,
    // "handleEvent", « event », and event's currentTarget attribute value -
    // a function listener is called with `this` bound to it
    // (EventTarget-this-of-listener.html). "If this throws an exception
    // exception: report exception for listener's callback's corresponding
    // JavaScript object's associated realm's global object."
    var reporter = DispatchReporter{ .realm = realm, .did_throw = did_throw };
    const completion = engine.callUserObjectOperation(realm, &held, "handleEvent", .{ .value = .{ .instance = current_target } }, &.{.{ .instance = event }}, .{
        .report = .{ .report = DispatchReporter.report, .host = &reporter },
    }) catch |err| {
        log.debug("listener call failed: {}", .{err});
        return;
    };
    switch (completion) {
        .throw => |thrown| {
            if (did_throw) |flag| flag.* = true;
            thrown.release();
        },
        .normal => |value| value.release(),
    }
}

/// The event handler processing algorithm (HTML §8.1.8.1) for `instance`'s
/// event handler for `event`'s type - the callback of the event handler's
/// listener, run by inner invoke.
fn invokeIdlEventHandler(instance: *runtime.Instance, event: *runtime.Instance, did_throw: ?*bool) void {
    const realm = instance.ctx;
    const event_type_str = interfaces.Event.get_type(event) catch return;

    // Step 1: "Let callback be the result of getting the current value of the
    // event handler given eventTarget and name." Run a value of our own: the
    // handler can replace or clear its own attribute, which releases the
    // map's.
    const value = eventHandlerValue(instance, event_type_str.asSlice()) orelse return;
    const function = engine.retainValue(realm, value.callback.function.value) catch return;
    const callback: engine.CallbackFunction = .{ .function = function, .context = value.callback.context };
    defer callback.release();

    // Step 2: "If callback is null, then return." A non-callable object -
    // [LegacyTreatNonObjectAsNull] keeps one - is invoked as nothing (WebIDL
    // "invoke a callback function" step 4).
    if (!engine.isCallable(realm, callback.function.value)) return;

    // Step 3: special error event handling - an ErrorEvent named "error" whose
    // currentTarget is a global (WindowOrWorkerGlobalScope). Brand checks go
    // through the vtable ancestry, never through a registry keyed on a
    // recyclable address.
    const special_error_event_handling = std.mem.eql(u8, event_type_str.asSlice(), "error") and
        event.stateAs(interfaces.ErrorEvent.State) != null and
        (instance.stateAs(interfaces.Window.State) != null or
            instance.stateAs(interfaces.WorkerGlobalScope.State) != null);

    // Step 4: invoke callback with the event - or, for special error event
    // handling, with the event's message, filename, lineno, colno and error -
    // with callback this value set to event's currentTarget.
    const event_argument = [_]runtime.JSValue{.{ .instance = event }};
    var error_arguments: ErrorEventArguments = undefined;
    const args: []const runtime.JSValue = if (special_error_event_handling) blk: {
        error_arguments = ErrorEventArguments.of(event) catch return;
        break :blk &error_arguments.values;
    } else &event_argument;
    defer if (special_error_event_handling) error_arguments.deinit(event.ctx.allocator);

    // DOM inner invoke steps 2.8-2.10 / 2.13 for the event handler's listener,
    // whose callback belongs to the target's realm.
    const handler_window = windowOfRealm(realm);
    const previous_event = if (handler_window) |w| swapCurrentEvent(w, event) else null;
    defer if (handler_window) |w| {
        _ = swapCurrentEvent(w, previous_event);
    };

    // "If an exception gets thrown by the callback, it will be rethrown,
    // ending these steps. The exception will propagate to the DOM event
    // dispatch logic, which will then report it" - for the global of the
    // callback's associated realm (DOM inner invoke step 2.11): reported
    // here, and the completion is then normal undefined, which step 5 ignores.
    var reporter = DispatchReporter{ .realm = realm, .did_throw = did_throw };
    const completion = engine.invokeCallbackFunction(realm, &callback, .{ .value = .{ .instance = instance } }, args, .{
        .report = .{ .report = DispatchReporter.report, .host = &reporter },
    }) catch |err| {
        log.debug("event handler not invoked: {}", .{err});
        return;
    };
    const return_value = switch (completion) {
        .normal => |normal| normal,
        .throw => |thrown| {
            if (did_throw) |flag| flag.* = true;
            thrown.release();
            return;
        },
    };
    defer return_value.release();

    // Step 5: process the return value. Only an exact true (special error
    // handling) or an exact false (everything else) cancels - through
    // preventDefault's "set the canceled flag", which respects cancelable and
    // the passive listener flag, as Blink's and WebKit's handlers do.
    if (engine.typeOf(realm, return_value.value) != .boolean) return;
    if (engine.toBoolean(realm, return_value.value) == special_error_event_handling) {
        interfaces.Event.call_preventDefault(event) catch {};
    }
}

/// The five arguments `onerror` on a global is invoked with: the ErrorEvent's
/// message, filename, lineno, colno and error. The strings are the getters'
/// copies and the error is the getter's hold (a getter's result is its
/// caller's - retainValue().take()), all released by `deinit`.
const ErrorEventArguments = struct {
    message: runtime.DOMString,
    filename: []const u8,
    @"error": engine.Owned,
    values: [5]runtime.JSValue,

    fn of(event: *runtime.Instance) !ErrorEventArguments {
        const ErrorEvent = interfaces.ErrorEvent;
        const allocator = event.ctx.allocator;
        // Getters hand ownership of their strings to the caller (AGENTS.md).
        var message = try ErrorEvent.get_message(event);
        errdefer message.deinit(allocator);
        const filename = try ErrorEvent.get_filename(event);
        const @"error": engine.Owned = .{ .value = ErrorEvent.get_error(event) catch runtime.JSValue.jsUndefined };
        return .{
            .message = message,
            .filename = filename,
            .@"error" = @"error",
            .values = .{
                runtime.JSValue.fromStringRef(message.asSlice()),
                runtime.JSValue.fromStringRef(filename),
                runtime.JSValue.fromNumber(@floatFromInt(ErrorEvent.get_lineno(event) catch 0)),
                runtime.JSValue.fromNumber(@floatFromInt(ErrorEvent.get_colno(event) catch 0)),
                @"error".value,
            },
        };
    }

    fn deinit(self: *ErrorEventArguments, allocator: std.mem.Allocator) void {
        self.message.deinit(allocator);
        if (self.filename.len > 0) allocator.free(self.filename);
        self.@"error".release();
    }
};

/// The realm of `value`, a callback's JavaScript object: its function realm
/// where the engine knows it exactly, else null (the caller falls back to
/// the callback context).
fn associatedRealm(value: runtime.JSValue) ?runtime.Context {
    if (comptime engine.capabilities.exact_function_realm == .unsupported) return null;
    return engine.functionRealm(value);
}

/// `realm`'s global object, when it is a Window.
fn windowOfRealm(realm: runtime.Context) ?*runtime.Instance {
    const record = realm.getRealm() orelse return null;
    const global: *runtime.Instance = @ptrCast(@alignCast(record.global_object orelse return null));
    if (global.stateAs(interfaces.Window.State) == null) return null;
    return global;
}

/// The report behavior turns an abrupt completion into normal undefined.
/// Observe it where the engine reports, retaining the exact throw-site info.
const DispatchReporter = struct {
    realm: runtime.Context,
    did_throw: ?*bool,

    fn report(host: ?*anyopaque, info: *const engine.ErrorInfo) void {
        const self: *DispatchReporter = @ptrCast(@alignCast(host.?));
        // DOM inner invoke 2.13.1: report for the callback's associated realm.
        reportException(self.realm, info);
        // DOM inner invoke 2.13.2: set the legacy output flag, if given.
        if (self.did_throw) |flag| flag.* = true;
    }
};

/// DOM inner invoke step 2.11 / the event handler processing algorithm's
/// rethrow: HTML "report an exception" for the global of the realm the engine
/// names - the callback's associated realm - or else the target's (`host`).
fn reportException(host: ?*anyopaque, info: *const engine.ErrorInfo) void {
    const target_realm: runtime.Context = @ptrCast(@alignCast(host orelse return));
    const realm = info.realm orelse target_realm;
    const record = realm.getRealm() orelse return;
    const global: *runtime.Instance = @ptrCast(@alignCast(record.global_object orelse return));
    // Step 2's error information is the engine's, extracted where the
    // exception was thrown.
    const extracted: runtime.ErrorInfo = .{
        .message = info.message,
        .filename = info.filename,
        .lineno = info.lineno,
        .colno = info.colno,
        .error_value = if (info.error_value == .undefined) null else info.error_value,
    };
    _ = @import("html").report_exception.reportErrorInfo(global, &extracted, .{});
}

/// Operation: when (Observable)
/// Spec: https://wicg.github.io/observable-api/#dom-eventtarget-when
/// This is part of the Observable API proposal
pub fn call_when(instance: *runtime.Instance, @"type": runtime.DOMString, options: webidl.Opt(dictionaries.ObservableEventListenerOptions)) anyerror!*runtime.Instance {
    _ = instance;
    _ = @"type";
    _ = options;
    // TODO: Implement Observable API
    return error.NotImplemented;
}

// ============================================================================
// Helper functions for subclasses (Node, Element, etc.)
// ============================================================================

/// Get the internal state for an EventTarget instance
pub fn getInternalState(instance: *runtime.Instance) ?*InternalState {
    return getInternalFromRegistry(instance);
}

/// Set the node type for this EventTarget (used by Node)
pub fn setNodeType(instance: *runtime.Instance, node_type: u16) void {
    if (getInternalFromRegistry(instance)) |internal| {
        internal.node_type = node_type;
    }
}

/// Get the node type for this EventTarget
pub fn getNodeType(instance: *runtime.Instance) u16 {
    if (getInternalFromRegistry(instance)) |internal| {
        return internal.node_type;
    }
    return 0; // Plain EventTarget
}

/// Get all event listeners for a specific type
pub fn getEventListenersForType(instance: *runtime.Instance, @"type": []const u8) []const EventListenerRecord {
    const internal = getInternalFromRegistry(instance) orelse return &[_]EventListenerRecord{};
    const list = internal.event_listener_list orelse return &[_]EventListenerRecord{};

    // Note: This returns all listeners, caller should filter by type
    // In a real implementation, we'd return a filtered view
    _ = @"type";
    return list.toSlice();
}
