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
const v8_engine = @import("v8");
const InternalStateAccessor = @import("webidl").utils.InternalStateAccessor;
const MutationObserver = interfaces.MutationObserver;

// DOM imports for registered observer integration
const dom_module = @import("dom");
const instance_bridge = dom_module.instance_bridge;
const RegisteredObserver = dom_module.node_base.RegisteredObserverType;
const handles = dom_module.handles;

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
            .node_list = .empty,
            .record_queue = .empty,
        };
    }

    pub fn initWithAllocator(allocator: std.mem.Allocator) InternalState {
        return .{
            .allocator = allocator,
            .callback = null,
            .isolate = null,
            .node_list = .empty,
            .record_queue = .empty,
        };
    }

    pub fn deinit(self: *InternalState) void {
        // Dispose Global handle for callback
        v8_engine.disposeOptionalGlobalHandle(&self.callback);

        // Clear node list (don't free nodes, we don't own them)
        self.node_list.deinit(self.allocator);

        // Free MutationRecord instances we own
        for (self.record_queue.items) |record| {
            runtime.Instance.deinit(record);
        }
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

    // Build registered observer options
    // Note: attribute_filter conversion from DOMString[] to []const u8[] is deferred
    // For now, we skip the attribute filter matching since DOMString requires conversion
    const reg_options = RegisteredObserver.Options{
        .child_list = childList,
        .attributes = attributes,
        .character_data = characterData,
        .subtree = opts.subtree orelse false,
        .attribute_old_value = opts.attributeOldValue orelse false,
        .character_data_old_value = opts.characterDataOldValue orelse false,
        .attribute_filter = null, // TODO: Convert DOMString[] to []const u8[]
    };

    // Step 7: For each registered of target's registered observer list,
    // if registered's observer is this, update its options
    if (target_nodebase) |nodebase| {
        var found_existing = false;
        const observer_handle = handles.anyopaqueToMutationObserver(@ptrCast(instance));

        for (0..nodebase.registered_observers.len) |i| {
            if (nodebase.registered_observers.get(i)) |registered| {
                // Check if this registered observer belongs to this MutationObserver
                const registered_handle = handles.mutationObserverToAnyopaque(registered.observer);
                const instance_ptr: *anyopaque = @ptrCast(instance);
                if (registered_handle == instance_ptr) {
                    // Step 7.2: Update options - replace the registration
                    // We need to create a new RegisteredObserver with updated options
                    // Note: In the spec this also clears transient registered observers
                    const new_registered = RegisteredObserver{
                        .observer = observer_handle.?,
                        .options = reg_options,
                    };
                    _ = nodebase.registered_observers.replace(i, new_registered) catch {};
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
                    .options = reg_options,
                };
                nodebase.registered_observers.append(new_registered) catch return error.OutOfMemory;
                std.log.debug("[MutationObserver] observe: registered new observer on nodebase {*}, total observers: {}", .{ nodebase, nodebase.registered_observers.len });
            }
        }
    } else {
        std.log.debug("[MutationObserver] observe: WARNING - target_nodebase is null!", .{});
    }

    // Also maintain the observer's node list for disconnect()
    // Check if target is already in the node list
    var target_in_list = false;
    for (internal.node_list.items) |node| {
        if (node == target) {
            target_in_list = true;
            break;
        }
    }
    if (!target_in_list) {
        internal.node_list.append(internal.allocator, target) catch return error.OutOfMemory;
    }
}

/// DOM §7.1 - MutationObserver.disconnect()
///
/// Stops observer from observing any mutations. Until the observe() method
/// is used again, observer's callback will not be invoked.
///
/// Spec: https://dom.spec.whatwg.org/#dom-mutationobserver-disconnect
pub fn call_disconnect(instance: *runtime.Instance) anyerror!void {
    const internal = getInternal(instance);
    const instance_ptr: *anyopaque = @ptrCast(instance);

    // Step 1: For each node of this's node list, remove any registered
    // observer from node's registered observer list for which this is
    // the observer.
    for (internal.node_list.items) |node| {
        const nodebase = instance_bridge.getNodeBase(@ptrCast(node)) orelse continue;

        // Find and remove registered observers for this MutationObserver
        var i: usize = 0;
        while (i < nodebase.registered_observers.len) {
            if (nodebase.registered_observers.get(i)) |registered| {
                const registered_handle = handles.mutationObserverToAnyopaque(registered.observer);
                if (registered_handle == instance_ptr) {
                    // Remove this registration
                    _ = nodebase.registered_observers.remove(i) catch continue;
                    // Don't increment i, check the same index again
                    continue;
                }
            }
            i += 1;
        }
    }

    // Step 2: Empty this's record queue after freeing records we own.
    for (internal.record_queue.items) |record| {
        runtime.Instance.deinit(record);
    }
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
    defer internal.allocator.free(records);

    // Step 2: Empty this's record queue.
    // (Already emptied by toOwnedSlice)

    // Step 3: Return records as JSValue
    // TODO: Return proper V8 Array of MutationRecord - need V8 array creation utility
    // For now, ownership transfers to caller via JSValue. If not used, we'd need
    // to free the records. Since we return jsUndefined, we must free them here.
    for (records) |record| {
        runtime.Instance.deinit(record);
    }
    return runtime.JSValue.jsUndefined;
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

    // Get the callback from internal state
    const callback_global = internal.callback orelse {
        // No callback - clean up records
        std.log.debug("[MutationObserver.invokeCallback] No callback stored, cleaning up records", .{});
        for (records) |record| {
            runtime.Instance.deinit(record);
        }
        return;
    };

    const isolate = internal.isolate orelse {
        // No isolate - clean up records
        for (records) |record| {
            runtime.Instance.deinit(record);
        }
        return;
    };

    const context = v8_engine.ffi.v8_Isolate_GetCurrentContext(isolate) orelse {
        // No context - clean up records
        for (records) |record| {
            runtime.Instance.deinit(record);
        }
        return;
    };

    // Create a HandleScope for V8 operations - all Local handles must be within a scope
    const handle_scope = v8_engine.ffi.v8_HandleScope_New(isolate) orelse {
        for (records) |record| {
            runtime.Instance.deinit(record);
        }
        return;
    };
    defer v8_engine.ffi.v8_HandleScope_Dispose(handle_scope);

    // Create a V8 array for the mutation records
    const records_array = v8_engine.ffi.v8_Array_New(isolate, @intCast(records.len));

    // Populate the array with wrapped MutationRecord objects
    const conv = v8_engine.conversions;
    for (records, 0..) |record, idx| {
        const wrapped = conv.instanceToV8(isolate, record);
        _ = v8_engine.ffi.v8_Array_Set(records_array, context, @intCast(idx), wrapped);
    }

    // Wrap the observer instance as V8 object for the second argument
    const observer_v8 = conv.instanceToV8(isolate, instance);

    // Get undefined for 'this' value
    // v8_Undefined returns a Global<Value>*
    const recv_global = v8_engine.ffi.v8_Undefined(isolate) orelse {
        for (records) |record| {
            runtime.Instance.deinit(record);
        }
        return error.OutOfMemory;
    };

    // All values are already Global handles from V8 API:
    // - records_array: Global<Array>* from v8_Array_New
    // - observer_v8: Global<Value>* from instanceToV8
    // - recv_global: Global<Value>* from v8_Undefined
    // v8_Function_Call_Safe expects Global handles, so we can use them directly

    // Prepare arguments: [records, observer]
    var global_args: [2]*v8_engine.ffi.Value = .{
        @ptrCast(records_array),
        observer_v8,
    };

    // Get the callback function - callback_global is a GlobalHandle which wraps a Global<Function>*
    // We need to get its raw pointer for the FFI call
    const func_ptr = callback_global.ptr;

    // Call the callback function
    // All arguments are Global handles as expected by v8_Function_Call_Safe
    const result = v8_engine.ffi.v8_Function_Call_Safe(
        @ptrCast(func_ptr),
        context,
        @ptrCast(recv_global),
        2,
        @ptrCast(&global_args),
    );
    defer v8_engine.ffi.v8_FreeFunctionCallResult(result);

    // Check for errors but don't propagate - per spec, callback errors
    // should be reported but not stop other observers
    _ = result.error_info;

    // Note: Records are V8 garbage collected after wrapping, we don't need to free them
    // The V8 wrapper cache maintains the instance lifetime
}

// ============================================================================
// Microtask Queueing (for proper async MutationObserver callback delivery)
// ============================================================================

/// Context for the mutation observer microtask callback
const MutationMicrotaskContext = struct {
    allocator: std.mem.Allocator,
};

/// Microtask trampoline callback that invokes notifyMutationObservers
/// This is called by V8's microtask queue with C calling convention.
fn mutationMicrotaskCallback(data: ?*anyopaque) callconv(.c) void {
    std.log.debug("[MutationObserver] mutationMicrotaskCallback called", .{});

    const ctx: *MutationMicrotaskContext = @ptrCast(@alignCast(data orelse {
        std.log.err("[MutationObserver] mutationMicrotaskCallback: null data!", .{});
        return;
    }));
    const allocator = ctx.allocator;

    // Free the context first (we've captured what we need)
    allocator.destroy(ctx);

    // Now invoke the notify algorithm from the dom module
    std.log.debug("[MutationObserver] Calling notifyMutationObservers", .{});
    const mutation_observer_algorithms = @import("dom").mutation_observer_algorithms;
    mutation_observer_algorithms.notifyMutationObservers(allocator) catch |err| {
        std.log.err("MutationObserver: notifyMutationObservers failed: {}", .{err});
    };
    std.log.debug("[MutationObserver] notifyMutationObservers returned", .{});
}

/// Queue a microtask to notify mutation observers
///
/// This is called by mutation_observer_algorithms.queueMutationObserverMicrotask
/// to properly queue the notification as a V8 microtask.
///
/// Spec: https://dom.spec.whatwg.org/#queue-a-mutation-observer-compound-microtask
pub fn queueNotifyMicrotask(allocator: std.mem.Allocator) !void {
    std.log.debug("[MutationObserver] queueNotifyMicrotask called", .{});

    // Get the current V8 isolate
    const isolate = v8_engine.ffi.v8_Isolate_GetCurrent() orelse {
        std.log.debug("[MutationObserver] No V8 isolate, calling notifyMutationObservers directly", .{});
        // No V8 isolate available - call notifyMutationObservers directly
        // This handles edge cases like unit tests without V8
        const mutation_observer_algorithms = @import("dom").mutation_observer_algorithms;
        try mutation_observer_algorithms.notifyMutationObservers(allocator);
        return;
    };

    // Allocate context for the microtask
    const ctx = allocator.create(MutationMicrotaskContext) catch return error.OutOfMemory;
    ctx.* = .{ .allocator = allocator };

    // Queue the microtask with V8
    std.log.debug("[MutationObserver] Queuing microtask with V8", .{});
    const callback_fn: ?*const anyopaque = @ptrCast(&mutationMicrotaskCallback);
    v8_engine.ffi.v8_Isolate_EnqueueMicrotask(isolate, callback_fn, ctx);
    std.log.debug("[MutationObserver] Microtask queued successfully", .{});
}
