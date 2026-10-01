//! Implementation for MutationObserver interface
//!
//! Spec: https://dom.spec.whatwg.org/#interface-mutationobserver
//! WHATWG DOM Standard §7.1
//!
//! MutationObservers can be used to observe mutations to the tree of nodes.
//! They maintain a list of observed nodes and a queue of pending mutation records.
//!
//! Migrated from: webidl/src/dom/MutationObserver.zig

const std = @import("std");
const log = std.log.scoped(.mutation_observer);
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const webidl = @import("webidl");
const engine = @import("engine");
const InternalStateAccessor = @import("webidl").utils.InternalStateAccessor;
const MutationObserver = interfaces.MutationObserver;

// DOM imports for registered observer integration
const dom_module = @import("dom");
const instance_bridge = dom_module.instance_bridge;
const RegisteredObserver = dom_module.node_base.RegisteredObserverType;
const handles = dom_module.handles;
const same_object = @import("same_object.zig");

pub const State = MutationObserver.State;

pub const ImplError = error{
    NotImplemented,
    TypeError,
    OutOfMemory,
};

/// Internal state for MutationObserver
/// Spec: https://dom.spec.whatwg.org/#mutationobserver
pub const InternalState = struct {
    allocator: std.mem.Allocator,

    /// The observer's callback, a MutationCallback value: OWNED, released in
    /// deinit.
    callback: ?engine.CallbackFunction = null,

    /// The nodes this observer is registered on - "a list of weak references
    /// to nodes". A node going away removes itself (through
    /// `dom.observer_registrations`); the slab generation in each link covers
    /// the teardown sweep, which frees nodes and observers in no order.
    ///
    /// Spec: https://dom.spec.whatwg.org/#mutationobserver-node-list
    node_list: std.ArrayListUnmanaged(same_object.Link),

    // The observer's own wrapper is held while any node lists it - its
    // pending activity (engine.keepPlatformObjectAlive). A node's registered
    // observers are strong references in the spec; nothing else here would
    // keep an observer alive that script no longer names, and a collected
    // observer left every node that listed it pointing into the slab -
    // `enqueueRecord` then wrote into freed memory on the next mutation, a
    // crash charged to whichever file ran next. Held by the wrapper cache,
    // not a Global of its own: a removed frame's realm turns the cache's
    // holds into edges from its global object, so a frame whose script
    // observes its own nodes is still collected once script drops it.

    /// The nodes that list a transient registered observer of this observer
    /// (DOM "remove" step 15), weak like the node list. Notify step 6.3 takes
    /// those registrations off again. The spec reaches them through the node
    /// list; they are on the removed nodes, which it does not name, so the
    /// observer keeps them itself, as Blink's MutationObserverRegistration
    /// keeps its transient registration nodes.
    transient_nodes: std.ArrayListUnmanaged(same_object.Link) = .empty,

    /// Queue of pending mutation records
    record_queue: std.ArrayListUnmanaged(*runtime.Instance),

    /// Every attributeFilter this observer has registered and not yet
    /// replaced or disconnected. The registrations on the observed nodes
    /// borrow these lists; the observer owns them.
    attribute_filters: std.ArrayListUnmanaged([]const []const u8) = .empty,

    pub fn init(allocator: std.mem.Allocator) InternalState {
        _ = allocator;
        return .{
            .allocator = undefined,
            .callback = null,
            .node_list = .empty,
            .record_queue = .empty,
        };
    }

    pub fn initWithAllocator(allocator: std.mem.Allocator) InternalState {
        return .{
            .allocator = allocator,
            .callback = null,
            .node_list = .empty,
            .record_queue = .empty,
        };
    }

    /// An owned copy of an `attributeFilter` sequence, kept until released.
    fn keepFilter(self: *InternalState, filter: []const runtime.DOMString) ![]const []const u8 {
        const names = try self.allocator.alloc([]const u8, filter.len);
        var copied: usize = 0;
        errdefer {
            for (names[0..copied]) |name| self.allocator.free(name);
            self.allocator.free(names);
        }
        for (filter) |name| {
            names[copied] = try self.allocator.dupe(u8, name.asSlice());
            copied += 1;
        }
        try self.attribute_filters.append(self.allocator, names);
        return names;
    }

    /// Free one filter `keepFilter` returned, once no registration uses it.
    fn releaseFilter(self: *InternalState, filter: []const []const u8) void {
        for (self.attribute_filters.items, 0..) |kept, i| {
            if (kept.ptr != filter.ptr) continue;
            freeFilter(self.allocator, kept);
            _ = self.attribute_filters.swapRemove(i);
            return;
        }
    }

    fn releaseAllFilters(self: *InternalState) void {
        for (self.attribute_filters.items) |kept| freeFilter(self.allocator, kept);
        self.attribute_filters.clearAndFree(self.allocator);
    }

    fn freeFilter(allocator: std.mem.Allocator, filter: []const []const u8) void {
        for (filter) |name| allocator.free(name);
        allocator.free(filter);
    }

    pub fn deinit(self: *InternalState) void {
        if (self.callback) |callback| callback.release();
        self.callback = null;

        // Clear node list (don't free nodes, we don't own them)
        self.node_list.deinit(self.allocator);
        self.transient_nodes.deinit(self.allocator);

        // Free MutationRecord instances we own
        for (self.record_queue.items) |record| {
            runtime.Instance.deinit(record);
        }
        self.record_queue.deinit(self.allocator);

        self.releaseAllFilters();
    }
};

/// Helper to access internal state from instance
/// Get internal state from instance using shared accessor (pointer cast variant)
const Accessor = InternalStateAccessor(InternalState, State, *runtime.Instance);

fn getInternal(instance: *runtime.Instance) *InternalState {
    return Accessor.getCast(instance);
}

/// Initialize instance (creates the instance)
pub fn init(
    allocator: std.mem.Allocator,
    comptime StateType: type,
    vtable: *const runtime.VTable,
    ctx: runtime.Context,
) !*runtime.Instance {
    const instance = try runtime.Instance.init(allocator, StateType, vtable, ctx);
    errdefer runtime.Instance.deinit(instance);

    // A node going away reaches its observers through this hook. Installed
    // before this observer can register anywhere.
    dom_module.observer_registrations.install(.{
        .node_released = &nodeReleasedHook,
        .transient_added = &transientAddedHook,
        .remove_transients = &removeTransientsHook,
    });

    // Initialize internal state using ArenaAllocator
    const ArenaAllocator = @import("runtime").ArenaAllocator;
    const internal = try ArenaAllocator.get().create(InternalState);
    internal.* = InternalState.initWithAllocator(allocator);

    // Store internal state in instance
    const state = instance.getState(State);
    state.own._internal = internal;

    return instance;
}

/// Deinitialize instance
pub fn deinit(instance: *runtime.Instance) void {
    const state = instance.getState(State);
    if (state.own._internal) |internal_ptr| {
        const internal: *InternalState = @ptrCast(@alignCast(internal_ptr));
        // Nothing may name this observer once it is gone: not a node it is
        // registered on, not the agent's pending mutation observers.
        unregisterFromNodes(instance, internal);
        dom_module.mutation_observer_algorithms.forgetObserver(instance);
        // Whatever pending-activity hold is left goes with it.
        engine.releasePlatformObject(instance);
        internal.deinit();
        // Note: Internal state memory is managed by arena allocator - do NOT destroy
        // Return the block itself, not just what it points to. The comment this
        // replaces said the arena manages it; the arena had no way to, so the
        // struct stayed allocated for the life of the process.
        const Arena = @import("runtime").ArenaAllocator;
        if (Arena.tryGet() catch null) |arena| arena.destroy(InternalState, internal);
        state.own._internal = null;
    }
    // NOTE: Do NOT call runtime.Instance.deinit() - GC layer handles slab freeing
}

/// Constructor implementation
/// DOM §7.1 - new MutationObserver(callback)
///
/// Constructs a MutationObserver and sets its callback to callback.
/// The callback is invoked with a list of MutationRecord objects as first
/// argument and the constructed MutationObserver object as second argument.
pub fn call_constructor(ctx: runtime.Context, callback: callbacks.MutationCallback) !*runtime.Instance {
    std.log.debug("[MutationObserver] call_constructor called with callback={*}", .{@as(?*const anyopaque, @ptrCast(callback))});
    // Create instance through init()
    const instance = try init(ctx.allocator, State, &MutationObserver.vtable, ctx);
    errdefer deinit(instance);

    // "Set this's callback to callback": the binding hands the converted
    // function over, and the observer keeps it (OWNED) with its callback
    // context.
    const internal = getInternal(instance);
    internal.callback = engine.takeCallbackFunction(@ptrCast(callback));

    std.log.debug("[MutationObserver] call_constructor returning instance={*}", .{instance});
    return instance;
}

/// DOM §7.1 - MutationObserver.observe(target, options)
///
/// Instructs the user agent to observe a given target (a node) and report
/// any mutations based on the criteria given by options (an object).
///
/// Spec: https://dom.spec.whatwg.org/#dom-mutationobserver-observe
pub fn call_observe(instance: *runtime.Instance, target: *runtime.Instance, options: webidl.Opt(dictionaries.MutationObserverInit)) anyerror!void {
    log.debug("[MO_OBSERVE] call_observe ENTRY: instance={*}, target={*}\n", .{ instance, target });

    const internal = getInternal(instance);

    // Get the options value, using defaults if not passed
    const opts = if (options.was_passed) options.value else dictionaries.MutationObserverInit{};

    // Step 1: If either options["attributeOldValue"] or options["attributeFilter"]
    // exists, and options["attributes"] does not exist, then set
    // options["attributes"] to true.
    var normalized_attributes = opts.attributes;
    if ((opts.attributeOldValue != null or opts.attributeFilter != null) and
        opts.attributes == null)
    {
        normalized_attributes = true;
    }

    // Step 2: If options["characterDataOldValue"] exists and
    // options["characterData"] does not exist, then set
    // options["characterData"] to true.
    var normalized_characterData = opts.characterData;
    if (opts.characterDataOldValue != null and opts.characterData == null) {
        normalized_characterData = true;
    }

    // Step 3: If none of options["childList"], options["attributes"], and
    // options["characterData"] is true, then throw a TypeError.
    const childList = opts.childList orelse false;
    const attributes = normalized_attributes orelse false;
    const characterData = normalized_characterData orelse false;

    if (!childList and !attributes and !characterData) {
        return error.TypeError;
    }

    // Step 4: If options["attributeOldValue"] is true and options["attributes"]
    // is false, then throw a TypeError.
    if ((opts.attributeOldValue orelse false) and !attributes) {
        return error.TypeError;
    }

    // Step 5: If options["attributeFilter"] is present and options["attributes"]
    // is false, then throw a TypeError.
    if (opts.attributeFilter != null and !attributes) {
        return error.TypeError;
    }

    // Step 6: If options["characterDataOldValue"] is true and
    // options["characterData"] is false, then throw a TypeError.
    if ((opts.characterDataOldValue orelse false) and !characterData) {
        return error.TypeError;
    }

    // Get the target node's NodeBase via instance_bridge for registering the observer
    const target_nodebase = instance_bridge.getNodeBase(@ptrCast(target));
    log.debug("[MO_OBSERVE] target_nodebase={?*}\n", .{target_nodebase});

    // The filter's strings belong to the binding and die with this call; the
    // registration keeps the observer's own copy. The observer tracks every
    // copy, so one a failed registration never used is still freed by
    // disconnect() or the observer's teardown.
    const attribute_filter: ?[]const []const u8 = if (opts.attributeFilter) |filter|
        try internal.keepFilter(filter)
    else
        null;

    const reg_options = RegisteredObserver.Options{
        .child_list = childList,
        .attributes = attributes,
        .character_data = characterData,
        .subtree = opts.subtree orelse false,
        .attribute_old_value = opts.attributeOldValue orelse false,
        .character_data_old_value = opts.characterDataOldValue orelse false,
        .attribute_filter = attribute_filter,
    };

    // Step 7: For each registered of target's registered observer list,
    // if registered's observer is this, update its options
    if (target_nodebase) |nodebase| {
        var found_existing = false;
        const observer_handle = handles.anyopaqueToMutationObserver(@ptrCast(instance));

        for (0..nodebase.registered_observers.len) |i| {
            if (nodebase.registered_observers.get(i)) |registered| {
                // Check if this registered observer belongs to this
                // MutationObserver. A transient one is not "registered" in
                // this sense: it is a copy that lasts until the next notify,
                // and Blink and Gecko keep them out of this lookup too, so
                // re-observing a removed node registers it for good.
                if (registered.transient_source != null) continue;
                const registered_handle = handles.mutationObserverToAnyopaque(registered.observer);
                const instance_ptr: *anyopaque = @ptrCast(instance);
                if (registered_handle == instance_ptr) {
                    // Step 7.1: "For each node of this's node list, remove
                    // all transient registered observers whose source is
                    // registered from node's registered observer list." They
                    // sit on the nodes removed from under target.
                    removeTransientsWhere(instance, internal, nodebase);
                    // Step 7.2: "Set registered's options to options."
                    const new_registered = RegisteredObserver{
                        .observer = observer_handle.?,
                        .observer_generation = runtime.SlabAllocator.generationOf(instance),
                        .options = reg_options,
                    };
                    const replaced_filter = registered.options.attribute_filter;
                    _ = nodebase.registered_observers.replace(i, new_registered) catch {};
                    if (replaced_filter) |filter| internal.releaseFilter(filter);
                    found_existing = true;
                    break;
                }
            }
        }

        // Step 8: If not found, append a new registered observer
        if (!found_existing) {
            if (observer_handle) |obs_handle| {
                const new_registered = RegisteredObserver{
                    .observer = obs_handle,
                    .observer_generation = runtime.SlabAllocator.generationOf(instance),
                    .options = reg_options,
                };
                nodebase.registered_observers.append(new_registered) catch return error.OutOfMemory;
                std.log.debug("[MutationObserver] observe: registered new observer on nodebase {*}, total observers: {}", .{ nodebase, nodebase.registered_observers.len });
            }
        }
    } else {
        // Not a node with a tree position: there is nothing to register on.
        return;
    }

    // Step 8's other half: "Append a weak reference to target to this's node
    // list", once per node.
    const target_in_list = for (internal.node_list.items) |link| {
        if (link.instance == target and link.isLive()) break true;
    } else false;
    if (!target_in_list) {
        internal.node_list.append(internal.allocator, same_object.Link.to(target)) catch return error.OutOfMemory;
    }

    // Registered: stay alive for as long as a node lists this observer.
    engine.keepPlatformObjectAlive(instance);
}

/// Remove every registration whose observer is `instance` from the nodes in
/// its node list that are still alive, and empty the list. The first step of
/// disconnect(), and the observer's own teardown.
fn unregisterFromNodes(instance: *runtime.Instance, internal: *InternalState) void {
    const instance_ptr: *anyopaque = @ptrCast(instance);
    for (internal.node_list.items) |link| {
        if (!link.isLive()) continue;
        const nodebase = instance_bridge.getNodeBase(@ptrCast(link.instance)) orelse continue;
        var i: usize = 0;
        while (i < nodebase.registered_observers.len) {
            const registered = nodebase.registered_observers.get(i) orelse break;
            if (handles.mutationObserverToAnyopaque(registered.observer) == instance_ptr) {
                _ = nodebase.registered_observers.remove(i) catch break;
                continue;
            }
            i += 1;
        }
    }
    internal.node_list.clearRetainingCapacity();
    // And the transient copies, which borrow this observer's attribute
    // filters: Blink's disconnect clears them with the registrations.
    removeTransientsWhere(instance, internal, null);
}

/// Take this observer's transient registered observers - those whose source
/// is `source`, or all of them when it is null - off the nodes that list
/// them.
fn removeTransientsWhere(instance: *runtime.Instance, internal: *InternalState, source: ?*const anyopaque) void {
    const instance_ptr: *anyopaque = @ptrCast(instance);
    var kept: usize = 0;
    for (internal.transient_nodes.items) |link| {
        var still_listed = false;
        if (link.isLive()) {
            if (instance_bridge.getNodeBase(@ptrCast(link.instance))) |nodebase| {
                var i: usize = 0;
                while (i < nodebase.registered_observers.len) {
                    const registered = nodebase.registered_observers.get(i) orelse break;
                    const mine = registered.transient_source != null and
                        handles.mutationObserverToAnyopaque(registered.observer) == instance_ptr;
                    if (mine and (source == null or registered.transient_source == source)) {
                        _ = nodebase.registered_observers.remove(i) catch break;
                        continue;
                    }
                    if (mine) still_listed = true;
                    i += 1;
                }
            }
        }
        if (still_listed) {
            internal.transient_nodes.items[kept] = link;
            kept += 1;
        }
    }
    internal.transient_nodes.shrinkRetainingCapacity(kept);
}

/// `dom.observer_registrations`: DOM "remove" step 15 appended a transient
/// registered observer of this observer to `node`'s list.
fn transientAddedHook(observer: *runtime.Instance, generation: u64, node: *runtime.Instance) void {
    if (runtime.SlabAllocator.generationOf(observer) != generation) return;
    const state = observer.getState(State);
    const internal_ptr = state.own._internal orelse return;
    const internal: *InternalState = @ptrCast(@alignCast(internal_ptr));
    for (internal.transient_nodes.items) |link| {
        if (link.instance == node and link.isLive()) return;
    }
    internal.transient_nodes.append(internal.allocator, same_object.Link.to(node)) catch {};
}

/// `dom.observer_registrations`: "notify mutation observers" step 6.3 - "for
/// each node of mo's node list, remove all transient registered observers
/// whose observer is mo from node's registered observer list."
fn removeTransientsHook(observer: *runtime.Instance) void {
    const state = observer.getState(State);
    const internal_ptr = state.own._internal orelse return;
    const internal: *InternalState = @ptrCast(@alignCast(internal_ptr));
    removeTransientsWhere(observer, internal, null);
}

/// `dom.observer_registrations`: `node` is going away while this observer is
/// registered on it. Forget it; with no node left, stop holding itself.
fn nodeReleasedHook(observer: *runtime.Instance, generation: u64, node: *runtime.Instance) void {
    // The teardown sweep may have freed the observer first.
    if (runtime.SlabAllocator.generationOf(observer) != generation) return;
    const state = observer.getState(State);
    const internal_ptr = state.own._internal orelse return;
    const internal: *InternalState = @ptrCast(@alignCast(internal_ptr));

    var i: usize = 0;
    while (i < internal.node_list.items.len) {
        if (internal.node_list.items[i].instance == node) {
            _ = internal.node_list.swapRemove(i);
            continue;
        }
        i += 1;
    }
    i = 0;
    while (i < internal.transient_nodes.items.len) {
        if (internal.transient_nodes.items[i].instance == node) {
            _ = internal.transient_nodes.swapRemove(i);
            continue;
        }
        i += 1;
    }
    if (internal.node_list.items.len == 0) engine.releasePlatformObject(observer);
}

/// DOM §7.1 - MutationObserver.disconnect()
///
/// Stops observer from observing any mutations. Until the observe() method
/// is used again, observer's callback will not be invoked.
///
/// Spec: https://dom.spec.whatwg.org/#dom-mutationobserver-disconnect
pub fn call_disconnect(instance: *runtime.Instance) anyerror!void {
    const internal = getInternal(instance);

    // Step 1: "For each node of this's node list, remove any registered
    // observer from node's registered observer list for which this is the
    // observer."
    unregisterFromNodes(instance, internal);

    // Step 2: Empty this's record queue after freeing records we own.
    for (internal.record_queue.items) |record| {
        runtime.Instance.deinit(record);
    }
    internal.record_queue.clearRetainingCapacity();

    // No registration is left to use a filter, or to keep this alive.
    internal.releaseAllFilters();
    engine.releasePlatformObject(instance);
}

/// DOM §7.1 - MutationObserver.takeRecords()
///
/// Empties the record queue and returns what was in there.
///
/// Spec: https://dom.spec.whatwg.org/#dom-mutationobserver-takerecords
pub fn call_takeRecords(instance: *runtime.Instance) anyerror!runtime.JSValue {
    const internal = getInternal(instance);

    // Step 1: Let records be a clone of this's record queue.
    const records = internal.record_queue.toOwnedSlice(internal.allocator) catch return error.OutOfMemory;
    defer internal.allocator.free(records);

    // Step 2: Empty this's record queue.
    // (Already emptied by toOwnedSlice)

    // Step 3: Return records - as a sequence<MutationRecord>, an Array of the
    // current realm. Wrapping hands each record to the engine, exactly as
    // `invokeCallback` does for the callback's first argument; the wrapper
    // cache owns them from here.
    const array = engine.createSequenceOfPlatformObjects(engine.currentRealm() orelse instance.ctx, records) catch |err| {
        for (records) |record| runtime.Instance.deinit(record);
        return err;
    };
    // OWNED: the binding takes it.
    return array.take();
}

// ============================================================================
// Internal methods (for mutation algorithms)
// ============================================================================

/// Enqueue a mutation record to this observer's record queue
///
/// Called by mutation observation algorithms when mutations occur.
/// This is an internal method, not exposed in the WebIDL.
pub fn enqueueRecord(instance: *runtime.Instance, record: *runtime.Instance) ImplError!void {
    const internal = getInternal(instance);
    internal.record_queue.append(internal.allocator, record) catch return error.OutOfMemory;
}

/// Get the record queue for this observer
///
/// Used by the notify mutation observers algorithm.
pub fn getRecordQueue(instance: *runtime.Instance) []const *runtime.Instance {
    const internal = getInternal(instance);
    return internal.record_queue.items;
}

/// Clear the record queue
///
/// Used by the notify mutation observers algorithm.
pub fn clearRecordQueue(instance: *runtime.Instance) void {
    const internal = getInternal(instance);
    internal.record_queue.clearRetainingCapacity();
}

/// Invoke the observer's callback with the given mutation records
///
/// This is called by the notify mutation observers algorithm to actually
/// execute the JavaScript callback. Records ownership is transferred to this
/// function which will clean them up after the callback returns.
///
/// Spec: https://dom.spec.whatwg.org/#notify-mutation-observers step 6.4
pub fn invokeCallback(instance: *runtime.Instance, records: []const *runtime.Instance) !void {
    std.log.debug("[MutationObserver.invokeCallback] Called with {} records", .{records.len});

    const internal = getInternal(instance);
    const realm = instance.ctx;

    // No callback - clean up records.
    const callback = internal.callback orelse {
        for (records) |record| runtime.Instance.deinit(record);
        return;
    };

    // The records as a sequence<MutationRecord>. Wrapping hands each to the
    // wrapper cache, which owns them from here.
    const sequence = engine.createSequenceOfPlatformObjects(realm, records) catch |err| {
        for (records) |record| runtime.Instance.deinit(record);
        return err;
    };
    defer sequence.release();

    // Step 6.4: "invoke mo's callback with « records, mo », "report", and
    // mo" - the observer is the callback this value as well as its second
    // argument. What the callback throws is reported for the global of its
    // associated realm, and does not stop the other observers.
    const observer: runtime.JSValue = .{ .instance = instance };
    const completion = try engine.invokeCallbackFunction(realm, &callback, .{ .value = observer }, &.{ sequence.value, observer }, .{
        .report = .{ .report = reportException, .host = realm },
    });
    switch (completion) {
        inline else => |value| value.release(),
    }
}

/// HTML "report an exception" for the global of the realm the engine names -
/// the callback's associated realm - or else the observer's (`host`).
fn reportException(host: ?*anyopaque, info: *const engine.ErrorInfo) void {
    const observer_realm: runtime.Context = @ptrCast(@alignCast(host orelse return));
    const realm = info.realm orelse observer_realm;
    const record = realm.getRealm() orelse return;
    const global: *runtime.Instance = @ptrCast(@alignCast(record.global_object orelse return));
    // Step 2's error information is the engine's, extracted where the
    // exception was thrown: a thrown value that is not an Error carries no
    // position of its own to extract it from again.
    const extracted: runtime.ErrorInfo = .{
        .message = info.message,
        .filename = info.filename,
        .lineno = info.lineno,
        .colno = info.colno,
        .error_value = if (info.error_value == .undefined) null else info.error_value,
    };
    _ = @import("html").report_exception.reportErrorInfo(global, &extracted, .{});
}

// ============================================================================
// Microtask Queueing (for proper async MutationObserver callback delivery)
// ============================================================================

/// Context for the mutation observer microtask callback
const MutationMicrotaskContext = struct {
    allocator: std.mem.Allocator,
};

/// The microtask's steps: notify mutation observers.
fn mutationMicrotask(data: ?*anyopaque) void {
    const ctx: *MutationMicrotaskContext = @ptrCast(@alignCast(data orelse return));
    const allocator = ctx.allocator;

    // Free the context first (we've captured what we need)
    allocator.destroy(ctx);

    const mutation_observer_algorithms = @import("dom").mutation_observer_algorithms;
    mutation_observer_algorithms.notifyMutationObservers(allocator) catch |err| {
        std.log.err("MutationObserver: notifyMutationObservers failed: {}", .{err});
    };
}

/// DOM "queue a mutation observer microtask", step 3: queue a microtask to
/// notify mutation observers, in the agent of `realm` - the surrounding
/// agent, which the caller names by a realm of it.
///
/// Spec: https://dom.spec.whatwg.org/#queue-a-mutation-observer-compound-microtask
pub fn queueNotifyMicrotask(allocator: std.mem.Allocator, realm: runtime.Context) !void {
    const ctx = allocator.create(MutationMicrotaskContext) catch return error.OutOfMemory;
    ctx.* = .{ .allocator = allocator };

    const queued: engine.Error!void = if (realm.agent) |agent| engine.queueMicrotask(agent, mutationMicrotask, ctx) else error.NotSupported;
    queued catch |err| {
        allocator.destroy(ctx);
        switch (err) {
            error.OutOfMemory => return error.OutOfMemory,
            // No engine behind the realm (unit tests of the DOM alone), so
            // no microtask queue: notify now.
            else => {
                const mutation_observer_algorithms = @import("dom").mutation_observer_algorithms;
                try mutation_observer_algorithms.notifyMutationObservers(allocator);
            },
        }
    };
}
