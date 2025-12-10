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
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const webidl = @import("webidl");
const v8_engine = @import("v8");
const InternalStateAccessor = @import("webidl").utils.InternalStateAccessor;
const MutationObserver = interfaces.MutationObserver;

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

    /// Callback invoked when mutations are observed
    /// Uses V8 Global handle to persist across HandleScope boundaries
    callback: v8_engine.OptionalGlobalHandle = null,

    /// V8 isolate for Global handle operations
    isolate: ?*v8_engine.ffi.Isolate = null,

    /// List of weak references to nodes being observed
    ///
    /// Spec: https://dom.spec.whatwg.org/#mutationobserver-node-list
    ///
    /// Implementation note:
    /// In garbage-collected languages (JavaScript), "weak references" means the GC
    /// can collect nodes even while observed. In Zig with manual memory management,
    /// "weak" means we don't own the nodes (don't call deinit on them).
    ///
    /// Lifetime contract:
    /// - MutationObserver does NOT own observed nodes
    /// - Caller must ensure nodes outlive the observer, OR
    /// - Caller must call disconnect() before freeing observed nodes
    node_list: std.ArrayListUnmanaged(*runtime.Instance),

    /// Queue of pending mutation records
    record_queue: std.ArrayListUnmanaged(*runtime.Instance),

    pub fn init(allocator: std.mem.Allocator) InternalState {
        _ = allocator;
        return .{
            .allocator = undefined,
            .callback = null,
            .isolate = null,
            .node_list = .{},
            .record_queue = .{},
        };
    }

    pub fn initWithAllocator(allocator: std.mem.Allocator) InternalState {
        return .{
            .allocator = allocator,
            .callback = null,
            .isolate = null,
            .node_list = .{},
            .record_queue = .{},
        };
    }

    pub fn deinit(self: *InternalState) void {
        // Dispose Global handle for callback
        v8_engine.disposeOptionalGlobalHandle(&self.callback);

        // Clear node list (don't free nodes, we don't own them)
        self.node_list.deinit(self.allocator);

        // Clear record queue
        // Note: MutationRecord instances should be cleaned up separately
        self.record_queue.deinit(self.allocator);
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
        internal.deinit();
        // Note: Internal state memory is managed by arena allocator - do NOT destroy
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
    // Create instance through init()
    const instance = try init(ctx.allocator, State, &MutationObserver.vtable, ctx);
    errdefer deinit(instance);

    // Store the callback as a Global handle
    // The callback parameter comes from the V8 conversion system and represents
    // a V8 Local<Function> that needs to be persisted via Global handle.
    const internal = getInternal(instance);

    // Get the current isolate for Global handle creation
    const isolate = v8_engine.ffi.v8_Isolate_GetCurrent();
    internal.isolate = isolate;

    // Extract Global handle from the callback.
    // The callback comes from V8 conversion which creates a Global handle and tags
    // the pointer. We just need to untag it and wrap in GlobalHandle struct.
    const callback_ptr: ?*const anyopaque = @ptrCast(callback);
    if (callback_ptr) |ptr| {
        const untagged = v8_engine.pointer_tag.untagPointer(ptr);
        if (untagged.tag == .global_handle or untagged.tag == .untagged) {
            internal.callback = v8_engine.GlobalHandle{ .ptr = @ptrCast(@alignCast(untagged.ptr)) };
        }
    }

    return instance;
}

/// DOM §7.1 - MutationObserver.observe(target, options)
///
/// Instructs the user agent to observe a given target (a node) and report
/// any mutations based on the criteria given by options (an object).
///
/// Spec: https://dom.spec.whatwg.org/#dom-mutationobserver-observe
pub fn call_observe(instance: *runtime.Instance, target: *runtime.Instance, options: webidl.Opt(dictionaries.MutationObserverInit)) anyerror!void {
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

    // Step 7: For each registered of target's registered observer list,
    // if registered's observer is this:
    // TODO: Access target's registered observer list once Node is bridged
    // For now, just add to node_list

    // Step 8: Otherwise, append target to this's node list
    internal.node_list.append(internal.allocator, target) catch return error.OutOfMemory;
}

/// DOM §7.1 - MutationObserver.disconnect()
///
/// Stops observer from observing any mutations. Until the observe() method
/// is used again, observer's callback will not be invoked.
///
/// Spec: https://dom.spec.whatwg.org/#dom-mutationobserver-disconnect
pub fn call_disconnect(instance: *runtime.Instance) anyerror!void {
    const internal = getInternal(instance);

    // Step 1: For each node of this's node list, remove any registered
    // observer from node's registered observer list for which this is
    // the observer.
    // TODO: Remove registered observers from nodes once Node is bridged

    // Step 2: Empty this's record queue.
    internal.record_queue.clearRetainingCapacity();

    // Clear node list
    internal.node_list.clearRetainingCapacity();
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

    // Step 2: Empty this's record queue.
    // (Already emptied by toOwnedSlice)

    // Step 3: Return records as JSValue
    // TODO: Return proper sequence<MutationRecord>
    return runtime.JSValue.fromAnyopaque(@ptrCast(records.ptr));
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

/// Get the callback for this observer
///
/// Used by the notify mutation observers algorithm.
/// Returns a Local handle from the stored Global handle.
pub fn getCallback(instance: *runtime.Instance) ?*anyopaque {
    const internal = getInternal(instance);

    // Retrieve Local handle from Global handle
    if (internal.callback) |global| {
        if (internal.isolate) |isolate| {
            return global.asAnyopaque(isolate);
        }
    }
    return null;
}

/// Get the node list for this observer
///
/// Used by the notify mutation observers algorithm.
pub fn getNodeList(instance: *runtime.Instance) []const *runtime.Instance {
    const internal = getInternal(instance);
    return internal.node_list.items;
}

/// Get the record queue for this observer
///
/// Used by the notify mutation observers algorithm.
pub fn getRecordQueue(instance: *runtime.Instance) []const *runtime.Instance {
    const internal = getInternal(instance);
    return internal.record_queue.items;
}

/// Check if this observer is observing a specific node
///
/// Useful for caller to verify observation state before node cleanup.
/// Returns true if the node is in this observer's node list.
pub fn isObserving(instance: *runtime.Instance, node: *const runtime.Instance) bool {
    const internal = getInternal(instance);
    for (internal.node_list.items) |observed_node| {
        if (observed_node == node) {
            return true;
        }
    }
    return false;
}

/// Remove a node from the observation list
///
/// This is an internal helper for cases where a node needs to be
/// removed from observation without calling disconnect().
/// Useful when node is about to be freed.
pub fn unobserveNode(instance: *runtime.Instance, node: *const runtime.Instance) void {
    const internal = getInternal(instance);
    var i: usize = 0;
    while (i < internal.node_list.items.len) {
        if (internal.node_list.items[i] == node) {
            _ = internal.node_list.orderedRemove(i);
            return;
        }
        i += 1;
    }
}

/// Clear the record queue
///
/// Used by the notify mutation observers algorithm.
pub fn clearRecordQueue(instance: *runtime.Instance) void {
    const internal = getInternal(instance);
    internal.record_queue.clearRetainingCapacity();
}
