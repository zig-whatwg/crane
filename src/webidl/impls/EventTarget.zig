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
const event_dispatch = dom_module.event_dispatch;
const EventState = event_dispatch.EventState;
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

    /// HTML "event handler map" (§8.1.8.1): the event handlers whose target
    /// this is, by event type ("click" for onclick). Created with the first
    /// one - most targets never have any. A value is either owned raw source
    /// or the handler as the binding converted it (HandlerValue), so that
    /// EventHandler, OnErrorEventHandler and OnBeforeUnloadEventHandler share it. The
    /// keys borrow the activated listener's owned event type string.
    ///
    /// The map owns each value: the binding hands the setter's argument over
    /// as it is, and `setEventHandler` releases a value it replaces or clears,
    /// `deinitEx` the rest. A value is a handle to a function in some page,
    /// and one never released kept that page alive for the process.
    event_handler_map: ?*std.StringHashMapUnmanaged(HandlerEntry) = null,

    /// Set on an entry made lazily (`lazyInternal`), for an EventTarget whose
    /// impl never ran EventTarget's init - and so never runs its deinit,
    /// which is what removes an entry. Null for every other entry.
    lazy: ?LazyEntry = null,

    /// A Window's "current event" (HTML), which `window.event` returns: the
    /// event whose listener is running in the Window's realm, or null for
    /// undefined (`swapCurrentEvent`). BORROWED: set only while a dispatch
    /// that holds the event calls a listener. Null for every other target.
    current_event: ?*runtime.Instance = null,

    pub fn init(allocator: std.mem.Allocator) InternalState {
        return .{
            .allocator = allocator,
            .event_listener_list = null,
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
            // Raw source is native memory even after the engine has ended.
            var values = map.valueIterator();
            while (values.next()) |value| value.release(self.allocator, release_engine_values);
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
    // Its Browser's end releases what every entry left holds, first
    // (Browser.deinit; dom.teardown_sweeps).
    dom_module.teardown_sweeps.install(.event_targets, &sweepRemaining);
    // No event can be fired before a target exists.
    @import("dom").fire_event.install(.{
        .dispatch_trusted = dispatchTrusted,
        .dispatch_trusted_with_throws = dispatchTrustedWithThrows,
        .current_event = currentEvent,
    });
    dom_module.event_handlers.install(.{
        .get = getHandlerAddress,
        .set = setHandlerAddress,
        .set_raw = setRawEventHandler,
        .erase = eraseAllEventListenersAndHandlers,
        .has_listeners = hasListeners,
    });
    dom_module.event_listener_types.install(hasListenersOfType);
}

/// EventTarget's own construction steps, the first of every EventTarget's
/// chain: the generated root makes the instance, then this registers
/// EventTarget's internal state.
pub fn initOwn(instance: *runtime.Instance, allocator: std.mem.Allocator, comptime StateType: type, args: anytype) !void {
    _ = StateType;
    _ = args;
    // Initialize EventTarget internal state in registry
    _ = try initInternal(instance, allocator);
}

/// EventTarget's own teardown, the last of every EventTarget's destruction
/// chain. The slot itself is the collector's to free, or the queue's.
pub fn deinitOwn(instance: *runtime.Instance) void {
    // Clean up internal state from registry
    if (getInternalFromRegistry(instance)) |internal| {
        internal.deinit();
        removeFromRegistry(instance);
    }
}

/// Constructor implementation
/// Spec: https://dom.spec.whatwg.org/#dom-eventtarget-eventtarget
pub fn call_constructor(ctx: runtime.Context) !*runtime.Instance {
    const instance = try EventTarget.init(ctx.allocator, ctx);
    errdefer EventTarget.deinit(instance);

    // Note: EventTarget.State.own is empty struct, so no _internal field
    // For now, we'll manage internal state separately
    // TODO: Add _internal field to State via codegen

    return instance;
}

/// Initialize an EventTarget with internal state
/// This is called by subclasses (like Node) to set up the internal state
pub fn initInternal(instance: *runtime.Instance, allocator: std.mem.Allocator) !*InternalState {
    const internal = try runtime.arenaOf(instance).create(InternalState);
    internal.* = InternalState.init(allocator);

    // Store internal state in registry (ensure it's initialized first)
    try setInternalInRegistry(instance, internal);

    return internal;
}

/// One Browser's EventTarget states - a side table of its runtime.BrowserScope
/// (`.event_targets`, instances B1): a Browser's entries are its own, its end
/// takes them with it, and no other Browser's end reaches them. (A
/// workaround until the codegen adds the _internal field to State.)
///
/// Every EventTarget of every thread of the Browser is here - its window
/// thread and each of its workers' (docs/instances.md) - so the map is
/// reached only under `mutex`. A value is a block its instance's thread
/// allocated and frees, so a pointer read under the lock stays good after it;
/// what an entry holds of the engine (listeners' callbacks, event handlers) is
/// released OUTSIDE the lock, on the entry's own thread (`releaseEntry`).
pub const Registry = struct {
    /// Protects `map` and `guard`; held for one map operation or one sweep
    /// of the map, never across a call that can reach the engine or script.
    mutex: std.Io.Mutex = .init,
    map: ?std.AutoHashMap(usize, *InternalState) = null,
    allocator: std.mem.Allocator,
    /// Every EventTarget - every node - a page makes enters the registry and
    /// leaves it; the guard rehashes before an insert once the tombstones
    /// those removals leave could take half the free slots
    /// (webidl.utils.tombstones).
    guard: webidl.utils.tombstones.TombstoneGuard = .{},

    pub fn init(allocator: std.mem.Allocator) Registry {
        return .{ .allocator = allocator };
    }

    /// The Browser's scope ends, after its agent: what entries made since its
    /// sweep (`sweepRemaining`) still hold is released without the engine,
    /// which is gone. Their blocks go with the Browser's arena.
    pub fn deinit(self: *Registry) void {
        var map = self.takeAll() orelse return;
        var iter = map.valueIterator();
        while (iter.next()) |internal_ptr| internal_ptr.*.deinitEx(false);
        map.deinit();
    }

    fn lock(self: *Registry) void {
        std.Io.Threaded.mutexLock(&self.mutex);
    }

    fn unlock(self: *Registry) void {
        std.Io.Threaded.mutexUnlock(&self.mutex);
    }

    /// The map, made on first use. Called with `mutex` held.
    fn ensure(self: *Registry) *std.AutoHashMap(usize, *InternalState) {
        if (self.map == null) self.map = std.AutoHashMap(usize, *InternalState).init(self.allocator);
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

    /// The whole map, taken out for a final sweep. Called with `mutex` held,
    /// or by the table's own end.
    fn takeAll(self: *Registry) ?std.AutoHashMap(usize, *InternalState) {
        const map = self.map orelse return null;
        self.map = null;
        self.guard.reset();
        return map;
    }
};

/// `instance`'s Browser's registry, made on first use.
fn registryFor(instance: *runtime.Instance) !*Registry {
    return runtime.BrowserScope.ofInstance(instance).table(.event_targets, Registry);
}

/// `instance`'s Browser's registry, if it has one.
fn registryOf(instance: *runtime.Instance) ?*Registry {
    return runtime.BrowserScope.ofInstance(instance).existingTable(.event_targets, Registry);
}

/// dom.teardown_sweeps, first: at its Browser's end, release what every one
/// of `scope`'s remaining entries holds of the engine (listeners' callbacks,
/// event handlers) - BEFORE its agent ends (Browser.deinit), and after every
/// worker of the Browser has ended, so every entry left is this thread's.
fn sweepRemaining(scope: *runtime.BrowserScope) void {
    const registry = scope.existingTable(.event_targets, Registry) orelse return;
    registry.lock();
    var taken = registry.takeAll();
    registry.unlock();
    if (taken) |*map| {
        var iter = map.valueIterator();
        while (iter.next()) |internal_ptr| {
            internal_ptr.*.deinitEx(true); // the agent is alive: release its values
        }
        map.deinit();
    }
}

fn getInternalFromRegistry(instance: *runtime.Instance) ?*InternalState {
    const registry = registryOf(instance) orelse return null;
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
            if (stale) |entry| releaseEntry(@intFromPtr(instance), entry);
            return null;
        }
    }
    registry.unlock();
    return internal;
}

fn setInternalInRegistry(instance: *runtime.Instance, internal: *InternalState) !void {
    const registry = try registryFor(instance);
    var stale: ?*InternalState = null;
    defer if (stale) |entry| releaseEntry(@intFromPtr(instance), entry);
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
    const internal = try runtime.arenaOf(instance).create(InternalState);
    errdefer runtime.arenaOf(instance).destroy(InternalState, internal);
    internal.* = InternalState.init(std.heap.page_allocator);
    internal.lazy = .{ .realm = instance.ctx, .generation = runtime.SlabAllocator.generationOf(instance) };
    try setInternalInRegistry(instance, internal);
    return internal;
}

/// Release an entry taken out of the registry and what it holds - its
/// listeners' callbacks and its event handlers. Only for an entry whose
/// realm's agent lives, on that agent's thread, with the registry unlocked.
/// `address` is its instance's: the block goes back to that instance's
/// Browser's arena (runtime.arenaOf), where it was made.
fn releaseEntry(address: usize, internal: *InternalState) void {
    internal.deinitEx(true);
    const instance: *runtime.Instance = @ptrFromInt(address);
    runtime.arenaOf(instance).destroy(InternalState, internal);
}

/// EventTarget's unloading cleanup step (dom.unloading_cleanup): the entries
/// made lazily for `environment`'s instances leave with it - nothing else
/// removes them (see `LazyEntry`) - and what they hold is released now,
/// while the realm's agent lives. A worker's agent ends right after its
/// realm, and the browser's end, which releases whatever is left here, is
/// too late for it.
fn releaseRealmEntries(environment: runtime.Context) void {
    // The realm's Browser's entries: its objects are that Browser's.
    const scope = environment.browserScope() orelse return;
    const registry = scope.existingTable(.event_targets, Registry) orelse return;
    const Doomed = struct { address: usize, internal: *InternalState };
    var doomed: std.ArrayListUnmanaged(Doomed) = .empty;
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
            doomed.appendAssumeCapacity(.{ .address = key, .internal = taken });
        }
    }
    for (doomed.items) |entry| releaseEntry(entry.address, entry.internal);
}

fn removeFromRegistry(instance: *runtime.Instance) void {
    const registry = registryOf(instance) orelse return;
    registry.lock();
    const taken = registry.take(@intFromPtr(instance));
    registry.unlock();
    // Return the block, not just the map entry. EventTarget keeps its own registry
    // rather than using InstanceRegistry, so it needs its own release - and it is on
    // every DOM node, so leaving it out keeps the leak on the hottest path there is.
    if (taken) |internal| {
        runtime.arenaOf(instance).destroy(InternalState, internal);
    }
}

/// DOM §2.7 - default passive value
/// The default passive value, given an event type type and an EventTarget eventTarget
fn defaultPassiveValue(@"type": []const u8, event_target: *runtime.Instance) bool {
    // DOM default passive value step 1: the four types AND the specified
    // targets. Chrome/Safari ship this; Firefox's older target defaults lag.
    // Check the common non-passive type first, without walking any tree.
    if (!std.mem.eql(u8, @"type", "touchstart") and !std.mem.eql(u8, @"type", "touchmove") and
        !std.mem.eql(u8, @"type", "wheel") and !std.mem.eql(u8, @"type", "mousewheel")) return false;
    if (event_target.stateAs(interfaces.Window.State) != null) return true;
    const node_type = interfaces.Node.get_nodeType(event_target) catch return false;
    if (node_type == interfaces.Node.get_DOCUMENT_NODE()) return true;
    const document = (interfaces.Node.get_ownerDocument(event_target) catch null) orelse return false;
    if ((interfaces.Document.get_documentElement(document) catch null) == event_target) return true;
    if ((interfaces.Document.get_body(document) catch null) == event_target) return true;
    // Step 2: all other targets, including plain EventTargets, are false.
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

/// `window`'s current event (HTML), which `window.event` returns, or null for
/// undefined (dom.fire_event): the event whose listener is running in that
/// Window's realm. DOM's inner invoke (steps 2.9-2.10, 2.15) sets it around
/// every listener call and restores the previous value afterwards, so nested
/// dispatch unwinds correctly.
///
/// It is the Window's own state - its EventTarget entry's - reached through
/// its Browser's registry. It was one process-wide list every thread's
/// dispatch appended to without a lock, so two Browsers' listeners on two
/// threads raced on it (docs/instances.md: state has an owner).
fn currentEvent(window: *runtime.Instance) ?*runtime.Instance {
    const internal = getInternalFromRegistry(window) orelse return null;
    return internal.current_event;
}

/// Set `window`'s current event to `event`, returning the previous one. Each
/// call looks the entry up again: a listener can end the window it runs in.
fn swapCurrentEvent(window: *runtime.Instance, event: ?*runtime.Instance) ?*runtime.Instance {
    const found = if (event != null) lazyInternal(window) catch null else getInternalFromRegistry(window);
    const internal = found orelse return null;
    const previous = internal.current_event;
    internal.current_event = event;
    return previous;
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
    for (list.toSliceMut()) |*existing| {
        if (existing.event_handler and !existing.removed and
            std.mem.eql(u8, existing.type.asSlice(), event_type))
        {
            return;
        }
    }

    // Steps 4-6: a listener whose type is the event handler event type and
    // whose callback runs the event handler processing algorithm. "Add an
    // event listener" gives it the default passive value (step 4 there).
    var serial = next_handler_serial.fetchAdd(1, .monotonic);
    // 0 means "no handler": a wrapped counter skips it.
    if (serial == 0) serial = next_handler_serial.fetchAdd(1, .monotonic);
    var owned_type = try runtime.DOMString.initDupe(internal.allocator, event_type);
    errdefer owned_type.deinit(internal.allocator);
    try list.append(.{
        .type = owned_type,
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
        while (values.next()) |value| value.release(internal.allocator, true);
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

/// "Getting the current value of the event handler" (HTML §8.1.8.1):
/// compile a raw content-attribute handler on first use, in the target's
/// current document, or return the already compiled value.
pub fn eventHandler(comptime Handler: type, target: *runtime.Instance, event_type: []const u8) Handler {
    const address = (currentHandlerValue(target, event_type) orelse return null).address;
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
            if (map.fetchRemove(event_type)) |old| old.value.release(internal.allocator, true);
        }
        deactivateEventHandler(target, event_type);
        return;
    };
    // Step 4: set eventHandler's value to the given value, then activate it.
    // The map takes the binding's value over from here.
    var address: usize = undefined;
    @memcpy(std.mem.asBytes(&address), std.mem.asBytes(&handler));
    const handler_value: HandlerEntry = .{ .compiled = .{
        .callback = engine.takeCallbackFunction(@ptrFromInt(address)),
        .address = address,
    } };
    errdefer handler_value.release(internal.allocator, true);
    try storeHandlerEntry(target, internal, event_type, handler_value);
}

/// Take ownership only after every fallible allocation succeeds. Keys borrow
/// the listener's string, never an attribute-name buffer. Replacing a value
/// preserves the listener's position and releases exactly the old value.
fn storeHandlerEntry(target: *runtime.Instance, internal: *InternalState, event_type: []const u8, entry: HandlerEntry) !void {
    const map = internal.event_handler_map orelse blk: {
        const created = try internal.allocator.create(std.StringHashMapUnmanaged(HandlerEntry));
        created.* = .empty;
        internal.event_handler_map = created;
        break :blk created;
    };
    try map.ensureUnusedCapacity(internal.allocator, 1);
    try activateEventHandler(target, event_type);
    const listener = handlerListener(internal, event_type) orelse unreachable;
    const slot = map.getOrPutAssumeCapacity(listener.type.asSlice());
    if (slot.found_existing) slot.value_ptr.release(internal.allocator, true);
    slot.value_ptr.* = entry;
}

fn getHandlerAddress(target: *runtime.Instance, event_type: []const u8) ?usize {
    return (currentHandlerValue(target, event_type) orelse return null).address;
}

/// Content attribute change steps 5.2-5.6: store an owned raw body and
/// location and activate the handler, without compiling or running script.
fn setRawEventHandler(target: *runtime.Instance, event_type: []const u8, source: dom_module.event_handlers.RawSource) anyerror!void {
    const internal = getInternalFromRegistry(target) orelse return error.InvalidStateError;
    const entry: HandlerEntry = .{ .raw = try source.clone(internal.allocator) };
    errdefer entry.release(internal.allocator, true);
    try storeHandlerEntry(target, internal, event_type, entry);
}

/// `internal`'s event handler listener for `event_type`, if activated.
fn handlerListener(internal: *InternalState, event_type: []const u8) ?*EventListenerRecord {
    const list = internal.event_listener_list orelse return null;
    for (list.toSliceMut()) |*record| {
        if (record.event_handler and !record.removed and std.mem.eql(u8, record.type.asSlice(), event_type)) return record;
    }
    return null;
}

/// "Getting the current value of the event handler" (HTML 8.1.8.1) given
/// `target` and `event_type`: the map's value - or, for an internal raw
/// uncompiled handler, step 3: compile it now (`dom.event_handlers.compileRaw`,
/// which the content attribute's owner installs), which sets the value to the
/// function or - for a body that does not parse - reports the syntax error
/// and leaves it null ("This does not deactivate the event handler"). A
/// handler whose document still has no browsing context stays raw and is
/// null for now (step 3.2: "If scripting is disabled for document, then
/// return null").
///
/// The handler stops being raw BEFORE it is compiled: compiling reports
/// errors, which can run script that reads this handler again, and that read must find it
/// settled rather than compile it a second time.
fn currentHandlerValue(target: *runtime.Instance, event_type: []const u8) ?HandlerValue {
    const internal = getInternalFromRegistry(target) orelse return null;
    const map = internal.event_handler_map orelse return null;
    const entry = map.get(event_type) orelse return null;
    switch (entry) {
        .compiled => |value| return value,
        .raw => |source| {
            // Step 3.7.1: null before compilation can report an error and
            // re-enter the getter. Keep the listener and its position. The
            // source is ours during reentrancy, even if the attribute changes.
            const allocator = internal.allocator;
            const removed = map.fetchRemove(event_type).?;
            switch (dom_module.event_handlers.compileRaw(target, event_type, source)) {
                .scripting_disabled => {
                    // Step 3.2 runs no script: the map/listener are unchanged,
                    // and removal left capacity for this exact entry.
                    map.putAssumeCapacity(removed.key, entry);
                    return null;
                },
                .settled => source.deinit(allocator),
                .compiled => |callback| {
                    source.deinit(allocator);
                    // HTML getting the current value steps 3.12-3.13. Take
                    // the compiled callback directly: IDL conversion here
                    // would capture the getter's caller as the incumbent.
                    const current = getInternalFromRegistry(target) orelse {
                        callback.release();
                        return null;
                    };
                    const value: HandlerEntry = .{ .compiled = .{
                        .callback = callback,
                        .address = @intFromPtr(callback.function.value.handle.ptr),
                    } };
                    storeHandlerEntry(target, current, event_type, value) catch {
                        callback.release();
                        return null;
                    };
                },
            }
            // Compilation may have changed the map (or erased the target).
            return eventHandlerValue(target, event_type);
        },
    }
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

/// An event handler map owns either a compiled callback or its raw source.
const HandlerEntry = union(enum) {
    compiled: HandlerValue,
    raw: dom_module.event_handlers.RawSource,

    fn release(self: HandlerEntry, allocator: std.mem.Allocator, engine_alive: bool) void {
        switch (self) {
            .compiled => |value| if (engine_alive) value.release(),
            .raw => |source| source.deinit(allocator),
        }
    }
};

/// `target`'s event handler map entry for `event_type`, for the getter and
/// for dispatch.
fn eventHandlerValue(target: *runtime.Instance, event_type: []const u8) ?HandlerValue {
    const internal = getInternalFromRegistry(target) orelse return null;
    const map = internal.event_handler_map orelse return null;
    return switch (map.get(event_type) orelse return null) {
        .compiled => |value| value,
        .raw => null,
    };
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
/// is the only thing that makes an event untrusted. Everything reaches it
/// through `dom.fire_event`, which this installs.
fn dispatchTrusted(target: *runtime.Instance, event: *runtime.Instance) anyerror!bool {
    return dispatchEventWithTrust(target, event, true, null);
}

fn dispatchTrustedWithThrows(target: *runtime.Instance, event: *runtime.Instance, did_throw: *bool) anyerror!bool {
    return dispatchEventWithTrust(target, event, true, did_throw);
}

/// dispatchEvent()'s steps with isTrusted given: false for script (DOM 2.8
/// step 2), true when the user agent fires the event.
fn dispatchEventWithTrust(instance: *runtime.Instance, event: *runtime.Instance, trusted: bool, did_throw: ?*bool) anyerror!bool {
    // The event's dispatch state, taken once: every step below works on it.
    // An event with none never ran Event's constructing steps, so its
    // initialized flag is unset.
    const state = event_dispatch.of(event) orelse return error.InvalidStateError;

    // Step 1: If event's dispatch flag is set, or if its initialized flag is not
    //         set, then throw an "InvalidStateError" DOMException.
    //
    // The initialized-flag half is not optional: `document.createEvent("Event")`
    // hands back an event with the flag UNSET, and dispatching it must throw
    // until `initEvent` runs. Skipping the check made 8 subtests of
    // EventTarget-dispatchEvent.html report "did not throw".
    if (state.dispatch_flag or !state.initialized_flag) return error.InvalidStateError;

    // Step 2: Initialize event's isTrusted attribute to false - or, for an
    // event the user agent fires, true.
    state.is_trusted = trusted;

    // Step 3: Return the result of dispatching event to this
    return dispatchWithThrowFlag(instance, event, state, did_throw);
}

// ============================================================================
// DOM §2.9 - Dispatching events
// https://dom.spec.whatwg.org/#concept-event-dispatch
// ============================================================================

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

/// DOM §2.9 - dispatch
/// https://dom.spec.whatwg.org/#concept-event-dispatch
///
/// `state` is `event`'s (`dom.event_dispatch.of`), BORROWED for the dispatch.
/// Returns false if the event's canceled flag is set, true otherwise.
///
/// Steps 4-6.11 - the path across shadow trees, activationTarget and
/// clearTargets - are dom.event_path's; the passes over the path and steps
/// 1 and 7-13 are here, beside the listener lists they read.
fn dispatchWithThrowFlag(target: *runtime.Instance, event: *runtime.Instance, state: *EventState, did_throw: ?*bool) !bool {
    // Step 1: Set event's dispatch flag.
    state.dispatch_flag = true;

    // Steps 7-10 have to happen however we leave.
    errdefer state.endDispatch(event);

    // `get_type` hands back a borrowed slice into the event's own storage, and
    // `initEvent` returns early while the dispatch flag is set, so no callback
    // can invalidate it mid-dispatch.
    const event_type_string = interfaces.Event.get_type(event) catch runtime.DOMString.initEmpty();
    const event_type = event_type_string.asSlice();
    const bubbles = interfaces.Event.get_bubbles(event) catch false;

    // Steps 2-6.11. Step 2: targetOverride is target - the legacy target
    // override flag is HTML's, for a Window, and Crane's HTML does not pass
    // it. Step 6.4: isActivationEvent - "event is a MouseEvent object and
    // event's type attribute is click"; the behaviours are the element
    // types' own (dom.activation).
    const is_activation_event = std.mem.eql(u8, event_type, "click") and event.stateAs(interfaces.MouseEvent.State) != null;
    const built = try dom_module.event_path.build(state, target, .{
        .event_type = event_type,
        .composed = interfaces.Event.get_composed(event) catch false,
        .bubbles = bubbles,
        .activation_of = if (is_activation_event) &dom_module.activation.of else null,
    });
    const activation_target = built.activation_target;
    // Dispatch holds activationTarget across steps 6.12-12: step 9 empties
    // the path, which held it, before step 12 runs its activation behaviour
    // (refcount step 5g; WebKit's EventDispatcher::dispatchEvent holds
    // `Ref protectedNode` and its legacy pre-activation input in a
    // `RefPtr` for the whole dispatch, Source/WebCore/dom/
    // EventDispatcher.cpp). SHADOW MODE: counted only.
    var activation_hold: dom_module.node_holds.RefHold = .{};
    defer activation_hold.release();
    if (activation_target) |at| activation_hold.set(at.target);

    // The path does not change while it runs: nothing appends to it until
    // step 9 empties it, and a listener can neither redispatch this event
    // (step 1 of dispatchEvent) nor reinitialize it (initEvent's step 1).
    const path = state.path.toSlice();

    // Step 6.12: legacy-pre-activation behaviour.
    if (activation_target) |at| {
        if (at.behavior.legacy_pre_activation) |pre| pre(at.target);
    }

    // Step 6.13: for each item of event's path, IN REVERSE ORDER, invoke with
    // "capturing".
    var i = path.len;
    while (i > 0) {
        i -= 1;
        // Steps 6.13.1-6.13.2.
        state.phase = if (path[i].shadow_adjusted_target != null)
            interfaces.Event.get_AT_TARGET()
        else
            interfaces.Event.get_CAPTURING_PHASE();
        // Step 6.13.3.
        invoke(&path[i], event, state, .capturing, did_throw);
    }

    // Step 6.14: for each item of event's path, in order, invoke with "bubbling".
    for (path) |*item| {
        if (item.shadow_adjusted_target != null) {
            // Step 6.14.1 - a target is AT_TARGET in both passes, which is
            // how its capturing listeners run before its bubbling ones.
            state.phase = interfaces.Event.get_AT_TARGET();
        } else {
            // Step 6.14.2.1
            if (!bubbles) continue;
            // Step 6.14.2.2
            state.phase = interfaces.Event.get_BUBBLING_PHASE();
        }
        // Step 6.14.3
        invoke(item, event, state, .bubbling, did_throw);
    }

    // Steps 7-11: eventPhase NONE, currentTarget null, the path empty, the
    // flags unset and - when clearTargets - the target, relatedTarget and
    // touch target list cleared; then the values the event keeps are kept.
    state.finishDispatch(event, built.clear_targets);

    // Step 12: "If activationTarget is non-null: if event's canceled flag is
    // unset, then run activationTarget's activation behavior with event;
    // otherwise, if activationTarget has legacy-canceled-activation behavior,
    // run it."
    // defaultPrevented is the canceled flag ("return true if this's canceled
    // flag is set").
    if (activation_target) |at| {
        if (!state.canceled_flag) {
            at.behavior.run(at.target, event);
        } else if (at.behavior.legacy_canceled_activation) |canceled| {
            canceled(at.target);
        }
    }

    // Step 13: return false if event's canceled flag is set; otherwise true.
    return !state.canceled_flag;
}

/// DOM §2.9 - invoke
/// https://dom.spec.whatwg.org/#concept-event-listener-invoke
///
/// `item` is BORROWED from the event's path, which outlives the call.
fn invoke(item: *const dom_module.event_dispatch.PathItem, event: *runtime.Instance, state: *EventState, phase: ListenerPhase, did_throw: ?*bool) void {
    // Steps 1-3: event's target is the shadow-adjusted target of the last
    // item at or before this one whose shadow-adjusted target is non-null -
    // recorded on the item when the path was built. Written raw: the path
    // holds it, and the end of dispatch keeps the one the event ends with.
    state.target = item.target;

    // Step 4: "Set event's relatedTarget to pathItem's relatedTarget."
    state.related_target = item.related_target;

    // Step 5: "Set event's touch target list to pathItem's touch target
    // list." Both are empty for every event but a TouchEvent's.
    if (state.touch_target_list.len > 0 or item.touch_target_list.len > 0) {
        state.touch_target_list.clear();
        state.touch_target_list.appendSlice(item.touch_target_list.toSlice()) catch {};
    }

    // Step 6: stopPropagation() ends the walk here, but the caller still has to
    // run steps 7-10, so this returns rather than unwinding.
    if (state.stop_propagation_flag) return;

    // Step 7
    state.current_target = item.invocation_target;

    // Steps 8-10.
    //
    // Event handler IDL attributes (onclick, onload, ...) run from inside
    // here too: HTML specifies them as ordinary event listeners in the same
    // list, and `activateEventHandler` puts one there, so a handler runs in
    // registration order among the addEventListener listeners - and, being
    // non-capturing, only in the bubbling pass.
    const in_shadow_tree = item.invocation_target_in_shadow_tree;
    const found = innerInvoke(event, state, item.invocation_target, phase, in_shadow_tree, did_throw);

    // Step 11: "If found is false and event's isTrusted attribute is true:"
    if (found or !state.is_trusted) return;
    const event_type = interfaces.Event.get_type(event) catch return;
    // Step 11.2: rename a legacy-mapped type, "and return otherwise".
    const legacy = dom_module.event_dispatch.legacyEventType(event_type.asSlice()) orelse return;
    // Step 11.1: "Let originalEventType be event's type attribute value" -
    // the value the event held, handed back by the rename.
    const original_event_type = dom_module.event_dispatch.swapType(event, runtime.DOMString.initInterned(legacy)) orelse return;
    // Step 11.3: "Inner invoke with event, listeners, phase,
    // invocationTargetInShadowTree, and legacyOutputDidListenersThrowFlag if
    // given." found was false, so no listener ran and the list is still the
    // one step 8 cloned; innerInvoke's own snapshot is that clone.
    _ = innerInvoke(event, state, item.invocation_target, phase, in_shadow_tree, did_throw);
    // Step 11.4: "Set event's type attribute value to originalEventType."
    _ = dom_module.event_dispatch.swapType(event, original_event_type);
}

/// DOM §2.9 - inner invoke
/// https://dom.spec.whatwg.org/#concept-event-listener-inner-invoke
///
/// Returns `found`: whether any listener matched the event's type, regardless of
/// phase. Only step 11 of "invoke" consumes it. `in_shadow_tree` is the path
/// item's invocation-target-in-shadow-tree.
fn innerInvoke(event: *runtime.Instance, state: *EventState, current_target: *runtime.Instance, phase: ListenerPhase, in_shadow_tree: bool, did_throw: ?*bool) bool {
    const internal = getInternalFromRegistry(current_target) orelse return false;
    const list = internal.event_listener_list orelse return false;
    if (list.len == 0) return false;

    const event_type_string = interfaces.Event.get_type(event) catch return false;
    const event_type = event_type_string.asSlice();

    // Step 8 of "invoke": let listeners be a clone of the listener list. See
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

        // Step 2.11
        if (candidate.passive) state.in_passive_listener_flag = true;

        // Step 2.13 - an exception is reported, never propagated. An event
        // handler's listener runs the event handler processing algorithm.
        // Steps 2.9-2.10 and 2.15 (the listener global's current event) are
        // the callers', around the call.
        if (candidate.listener_id != 0) {
            if (expired orelse callback) |value| callListener(value, event, current_target, in_shadow_tree, did_throw);
        } else {
            invokeIdlEventHandler(current_target, event, in_shadow_tree, did_throw);
        }

        // Step 2.14
        if (candidate.passive) state.in_passive_listener_flag = false;

        // Step 2.16
        if (state.stop_immediate_propagation_flag) break;
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
fn callListener(callback: engine.CallbackInterface, event: *runtime.Instance, current_target: *runtime.Instance, in_shadow_tree: bool, did_throw: ?*bool) void {
    const realm = current_target.ctx;
    const object = engine.retainValue(realm, callback.object.value) catch |err| {
        log.debug("listener not called: {}", .{err});
        return;
    };
    const held: engine.CallbackInterface = .{ .object = object, .context = callback.context };
    defer held.release();

    // Steps 2.9-2.10: the global of the listener callback's associated realm
    // has the event as its current event for the duration of the call
    // (`window.event`) - unless invocationTargetInShadowTree, when it keeps
    // the one it has - and step 2.15 restores whatever it was before.
    const listener_window = windowOfRealm(associatedRealm(held.object.value) orelse held.context orelse realm);

    // Steps 2.6-2.8 (no listener of a Window whose associated Document is not
    // fully active) are NOT run yet. Run literally, they skipped listeners
    // that browsers run, through two defects elsewhere: an IndexedDB request
    // is made in the current realm, so a method taken from a removed frame
    // makes a request whose global is that frame's
    // (IndexedDB/idb{index,objectstore}-cross-realm-methods.html, which all
    // three browsers pass, TIMEOUT); and a frame's navigation API events fire
    // after Crane counts its document as no longer fully active, where the
    // browsers fire them during the detach
    // (navigation-api/navigate-event/signal-abort-detach-in-onnavigate.html,
    // navigation-methods/traverseTo-detach-between-navigate-and-
    // navigatesuccess.html). Lane events1 measured it: 17 subtests gained in
    // dom/events/event-listener-not-fully-active-*, 20 lost there.

    const current_event_window = if (in_shadow_tree) null else listener_window;
    const previous_event = if (current_event_window) |w| swapCurrentEvent(w, event) else null;
    defer if (current_event_window) |w| {
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
fn invokeIdlEventHandler(instance: *runtime.Instance, event: *runtime.Instance, in_shadow_tree: bool, did_throw: ?*bool) void {
    const realm = instance.ctx;
    const event_type_str = interfaces.Event.get_type(event) catch return;

    // Step 1: "Let callback be the result of getting the current value of the
    // event handler given eventTarget and name." Run a value of our own: the
    // handler can replace or clear its own attribute, which releases the
    // map's.
    const value = currentHandlerValue(instance, event_type_str.asSlice()) orelse return;
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

    // DOM inner invoke steps 2.9-2.10 and 2.15 for the event handler's
    // listener. Its listenerGlobal is the handler function's realm's global,
    // not the target's: golden rule 2 - Chrome and Safari pass
    // dom/events/event-global-is-still-set-when-reporting-exception-onerror.html
    // (window.onerror set to another frame's function sets THAT frame's
    // window.event), Firefox fails it as Crane did. No current event is set
    // for an invocation target in a shadow tree (step 2.10.2).
    // Steps 2.6-2.8 are not run yet (callListener says why).
    const listener_window = windowOfRealm(associatedRealm(callback.function.value) orelse callback.context orelse realm);
    const handler_window = if (in_shadow_tree) null else listener_window;
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
    const behavior: engine.ExceptionBehavior = .{
        .report = .{ .report = DispatchReporter.report, .host = &reporter },
    };
    // HTML event handler processing step 4: beforeunload uses DOMString?
    // even for an ordinary Event. WebIDL invoke converts before cleanup of
    // either callback scope; a throwing toString is reported by DOM here.
    const beforeunload = std.mem.eql(u8, event_type_str.asSlice(), "beforeunload");
    const invoked = if (beforeunload)
        engine.invokeCallbackFunctionWithReturnType(realm, &callback, .{ .value = .{ .instance = instance } }, args, behavior, .nullable_dom_string)
    else
        engine.invokeCallbackFunction(realm, &callback, .{ .value = .{ .instance = instance } }, args, behavior);
    const completion = invoked catch |err| {
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

    // Step 5: process the return value.
    //
    // "If event is a BeforeUnloadEvent object and event's type is
    // beforeunload": the attribute is an OnBeforeUnloadEventHandler, whose
    // callback returned DOMString?; conversion already ran inside invoke,
    // with window.event still set. "If return value is not null, then: set event's canceled flag;
    // if event's returnValue attribute's value is the empty string, then set
    // it to return value."
    if (beforeunload and event.stateAs(interfaces.BeforeUnloadEvent.State) != null) {
        switch (engine.typeOf(realm, return_value.value)) {
            .undefined, .null => return,
            else => {},
        }
        const allocator = event.ctx.allocator;
        const string = engine.convertToDOMString(realm, return_value.value, allocator) catch |err| {
            log.debug("beforeunload return value not converted: {}", .{err});
            return;
        };
        defer allocator.free(string);
        dom_module.event_construction.forceCanceledFlag(event);
        const current = interfaces.BeforeUnloadEvent.get_returnValue(event) catch return;
        if (current.asSlice().len == 0) {
            interfaces.BeforeUnloadEvent.set_returnValue(event, runtime.DOMString.initInterned(string)) catch {};
        }
        return;
    }

    // Otherwise only an exact true (special error handling) or an exact
    // false (everything else) cancels - through preventDefault's "set the
    // canceled flag", which respects cancelable and the passive listener
    // flag, as Blink's and WebKit's handlers do.
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

/// The node type of an EventTarget that is a node, 0 for one that is not:
/// its NodeBase's, which Node's construction sets (no copy is kept here).
pub fn getNodeType(instance: *runtime.Instance) u16 {
    const node_base = dom_module.instance_bridge.getNodeBase(instance) orelse return 0;
    return node_base.node_type;
}

/// dom.event_handlers: whether `instance`'s event listener list holds a
/// listener whose removed is false - an event handler's included.
fn hasListeners(instance: *runtime.Instance) bool {
    const internal = getInternalFromRegistry(instance) orelse return false;
    const list = internal.event_listener_list orelse return false;
    for (list.toSlice()) |listener| {
        if (!listener.removed) return true;
    }
    return false;
}

/// dom.event_listener_types: whether `instance`'s event listener list holds
/// a listener of `event_type` whose removed is false - an activated event
/// handler's included.
fn hasListenersOfType(instance: *runtime.Instance, event_type: []const u8) bool {
    const internal = getInternalFromRegistry(instance) orelse return false;
    const list = internal.event_listener_list orelse return false;
    for (list.toSlice()) |listener| {
        if (!listener.removed and std.mem.eql(u8, listener.type.asSlice(), event_type)) return true;
    }
    return false;
}
