//! Mutation Observer Algorithms (WHATWG DOM Standard §7)
//!
//! Spec: https://dom.spec.whatwg.org/#mutation-observers
//!
//! This module implements the mutation observation algorithms:
//! - Queue a mutation record
//! - Queue a tree mutation record
//! - Queue a mutation observer microtask
//! - Notify mutation observers
//!
//! These algorithms are called by DOM mutation operations to notify observers
//! of changes to the tree.

const std = @import("std");
const infra = @import("infra");
const Allocator = std.mem.Allocator;

// Import DOM types from interfaces (via root.zig re-exports)
const interfaces = @import("interfaces");
const Node = interfaces.Node;
const NodeList = interfaces.NodeList;
const MutationObserver = interfaces.MutationObserver;
const MutationRecord = interfaces.MutationRecord;

// Import dictionary from dictionaries module
const dictionaries = @import("dictionaries");
const MutationObserverInit = dictionaries.MutationObserverInit;

/// Global mutation observer state (per similar-origin window agent)
/// In a real implementation, this would be per-agent state
/// For now, we use thread-local state (one agent per thread)
pub const MutationObserverAgent = struct {
    /// Whether a mutation observer microtask has been queued
    microtask_queued: bool = false,

    /// Set of mutation observers with pending records
    /// Stores *runtime.Instance pointers to MutationObserver instances
    pending_observers: infra.List(*runtime.Instance),

    allocator: Allocator,

    pub fn init(allocator: Allocator) MutationObserverAgent {
        return .{
            .microtask_queued = false,
            .pending_observers = infra.List(*runtime.Instance).init(allocator),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *MutationObserverAgent) void {
        self.pending_observers.deinit();
    }
};

// Thread-local agent state
// TODO: Replace with proper agent-per-window mechanism
threadlocal var global_agent: ?MutationObserverAgent = null;

/// Get the current agent's mutation observer state
/// Initializes on first access
pub fn getAgent(allocator: Allocator) !*MutationObserverAgent {
    if (global_agent == null) {
        global_agent = MutationObserverAgent.init(allocator);
    }
    return &global_agent.?;
}

/// Reset the agent state (for testing)
pub fn resetAgent() void {
    if (global_agent) |*agent| {
        agent.deinit();
    }
    global_agent = null;
}

/// DOM §7.3 - Queue a mutation record
///
/// Queue a mutation record of type for target with name, namespace, oldValue,
/// addedNodes, removedNodes, previousSibling, and nextSibling.
///
/// Spec: https://dom.spec.whatwg.org/#queueing-a-mutation-record
pub fn queueMutationRecord(
    allocator: Allocator,
    mutation_type: []const u8,
    target: *Node,
    name: ?[]const u8,
    namespace: ?[]const u8,
    old_value: ?[]const u8,
    added_nodes: *NodeList,
    removed_nodes: *NodeList,
    previous_sibling: ?*Node,
    next_sibling: ?*Node,
) !void {
    // Step 1: Let interestedObservers be an empty map
    var interested_observers = std.AutoHashMap(*MutationObserver, ?[]const u8).init(allocator);
    defer interested_observers.deinit();

    // Step 2: Let nodes be the inclusive ancestors of target
    const tree_helpers = @import("tree_helpers.zig");
    var nodes = try tree_helpers.getInclusiveAncestors(allocator, target);
    defer nodes.deinit();

    // Step 3: For each node in nodes, and then for each registered of node's registered observer list
    for (nodes.items()) |node| {
        for (0..node.registered_observers.len) |i| {
            const registered = node.registered_observers.get(i) orelse continue;
            const options = registered.options;

            // Step 3.2: If none of the following are true, then:
            var should_skip = false;

            // - node is not target and options["subtree"] is false
            if (node != target and !options.subtree) {
                should_skip = true;
            }

            // - type is "attributes" and options["attributes"] either does not exist or is false
            if (std.mem.eql(u8, mutation_type, "attributes")) {
                if (options.attributes == null or !options.attributes.?) {
                    should_skip = true;
                }
                // - type is "attributes", options["attributeFilter"] exists, and
                //   options["attributeFilter"] does not contain name or namespace is non-null
                if (options.attributeFilter) |filter| {
                    if (namespace != null) {
                        should_skip = true;
                    } else if (name) |attr_name| {
                        var found = false;
                        for (filter) |filter_name| {
                            if (std.mem.eql(u8, filter_name, attr_name)) {
                                found = true;
                                break;
                            }
                        }
                        if (!found) should_skip = true;
                    }
                }
            }

            // - type is "characterData" and options["characterData"] either does not exist or is false
            if (std.mem.eql(u8, mutation_type, "characterData")) {
                if (options.characterData == null or !options.characterData.?) {
                    should_skip = true;
                }
            }

            // - type is "childList" and options["childList"] is false
            if (std.mem.eql(u8, mutation_type, "childList")) {
                if (!options.childList) {
                    should_skip = true;
                }
            }

            if (should_skip) continue;

            // Step 3.2.1: Let mo be registered's observer
            // Cast from opaque type to concrete MutationObserver struct
            const mo: *MutationObserver = @ptrCast(@alignCast(registered.observer));

            // Step 3.2.2: If interestedObservers[mo] does not exist, then set interestedObservers[mo] to null
            if (!interested_observers.contains(mo)) {
                try interested_observers.put(mo, null);
            }

            // Step 3.2.3: If either type is "attributes" and options["attributeOldValue"] is true,
            // or type is "characterData" and options["characterDataOldValue"] is true,
            // then set interestedObservers[mo] to oldValue
            if (std.mem.eql(u8, mutation_type, "attributes") and (options.attributeOldValue orelse false)) {
                try interested_observers.put(mo, old_value);
            } else if (std.mem.eql(u8, mutation_type, "characterData") and (options.characterDataOldValue orelse false)) {
                try interested_observers.put(mo, old_value);
            }
        }
    }

    // Step 4: For each observer → mappedOldValue of interestedObservers
    var it = interested_observers.iterator();
    while (it.next()) |entry| {
        const observer = entry.key_ptr.*;
        const mapped_old_value = entry.value_ptr.*;

        // Step 4.1: Let record be a new MutationRecord object with...
        const record = try MutationRecord.init(
            allocator,
            mutation_type,
            target,
            added_nodes,
            removed_nodes,
            previous_sibling,
            next_sibling,
            name,
            namespace,
            mapped_old_value,
        );

        // Step 4.2: Enqueue record to observer's record queue
        try observer.enqueueRecord(record);

        // Step 4.3: Append observer to the surrounding agent's pending mutation observers
        const agent = try getAgent(allocator);
        // Check if observer is already in pending list
        var already_pending = false;
        for (agent.pending_observers.items()) |pending| {
            if (pending == observer) {
                already_pending = true;
                break;
            }
        }
        if (!already_pending) {
            try agent.pending_observers.append(observer);
        }
    }

    // Step 5: Queue a mutation observer microtask
    try queueMutationObserverMicrotask(allocator);
}

/// DOM §7.3 - Queue a tree mutation record
///
/// Queue a tree mutation record for target with addedNodes, removedNodes,
/// previousSibling, and nextSibling.
///
/// Spec: https://dom.spec.whatwg.org/#queue-a-tree-mutation-record
///
/// Note: This function uses *runtime.Instance for all node parameters to support
/// the unified DOM tree model where mutation.zig operates on NodeBase but needs
/// to integrate with the WebIDL MutationObserver system.
pub fn queueTreeMutationRecord(
    allocator: Allocator,
    target: *runtime.Instance,
    added_nodes: *runtime.Instance,
    removed_nodes: *runtime.Instance,
    previous_sibling: ?*runtime.Instance,
    next_sibling: ?*runtime.Instance,
) !void {
    // Step 1: Assert: either addedNodes or removedNodes is not empty
    // Get lengths from NodeList impls
    const added_len = NodeListImpl.get_length(added_nodes) catch 0;
    const removed_len = NodeListImpl.get_length(removed_nodes) catch 0;
    std.debug.assert(added_len > 0 or removed_len > 0);

    // Step 2: Queue a mutation record of "childList" for target with null, null, null,
    // addedNodes, removedNodes, previousSibling, and nextSibling
    try queueMutationRecordInternal(
        allocator,
        "childList",
        target,
        null, // name
        null, // namespace
        null, // oldValue
        added_nodes,
        removed_nodes,
        previous_sibling,
        next_sibling,
    );
}

// Import NodeList impl for accessing length
const NodeListImpl = @import("impls").NodeList;
const runtime = @import("runtime");

/// Internal version of queueMutationRecord that uses runtime.Instance
/// This avoids the architectural mismatch with the old interface-based signatures
fn queueMutationRecordInternal(
    allocator: Allocator,
    mutation_type: []const u8,
    target: *runtime.Instance,
    name: ?[]const u8,
    namespace: ?[]const u8,
    old_value: ?[]const u8,
    added_nodes: *runtime.Instance,
    removed_nodes: *runtime.Instance,
    previous_sibling: ?*runtime.Instance,
    next_sibling: ?*runtime.Instance,
) !void {
    // TODO: Full implementation requires updating the registered observer system
    // to work with runtime.Instance instead of NodeBase.
    //
    // For now, create the MutationRecord and queue it if there are any interested observers.
    // The full observer matching logic is deferred until the node-observer bridge is complete.

    // Get the MutationRecord impl
    const MutationRecordImpl = @import("impls").MutationRecord;
    const ctx = target.ctx;

    // Create the mutation record
    const record = try MutationRecordImpl.create(
        allocator,
        ctx,
        mutation_type,
        target,
        added_nodes,
        removed_nodes,
        previous_sibling,
        next_sibling,
        name,
        namespace,
        old_value,
    );

    // TODO: The full algorithm requires iterating through target's inclusive ancestors
    // and checking each node's registered observer list. This needs the node-observer
    // bridge to be completed (converting runtime.Instance to NodeBase to access
    // registered_observers field).
    //
    // For now, the MutationRecord is created but not dispatched to observers.
    // This will be completed when the transient observer support is implemented.
    //
    // MEMORY FIX: Since we're not dispatching the record, we must free it immediately
    // to avoid leaking. When observer dispatch is implemented, this defer should be
    // removed and ownership transferred to the observer's record queue.
    defer runtime.Instance.deinit(record);

    // Queue a mutation observer microtask
    try queueMutationObserverMicrotask(allocator);
}

/// DOM §7.1 - Queue a mutation observer microtask
///
/// Queue a microtask to notify mutation observers.
///
/// Spec: https://dom.spec.whatwg.org/#queue-a-mutation-observer-compound-microtask
fn queueMutationObserverMicrotask(allocator: Allocator) !void {
    const agent = try getAgent(allocator);

    // Step 1: If the surrounding agent's mutation observer microtask queued is true, then return
    if (agent.microtask_queued) return;

    // Step 2: Set the surrounding agent's mutation observer microtask queued to true
    agent.microtask_queued = true;

    // Step 3: Queue a microtask to notify mutation observers
    // TODO: Integrate with actual microtask queue
    // For now, we'll call notifyMutationObservers immediately
    // In a real implementation, this would be deferred to the microtask queue
    try notifyMutationObservers(allocator);
}

/// DOM §7.1 - Notify mutation observers
///
/// Invoke callbacks for all pending mutation observers.
///
/// Spec: https://dom.spec.whatwg.org/#notify-mutation-observers
pub fn notifyMutationObservers(allocator: Allocator) !void {
    const agent = try getAgent(allocator);

    // Step 1: Set the surrounding agent's mutation observer microtask queued to false
    agent.microtask_queued = false;

    // Step 2: Let notifySet be a clone of the surrounding agent's pending mutation observers
    var notify_set = infra.List(*runtime.Instance).init(allocator);
    defer notify_set.deinit();
    try notify_set.appendSlice(agent.pending_observers.items());

    // Step 3: Empty the surrounding agent's pending mutation observers
    agent.pending_observers.clear();

    // Step 4: (signal slots - not implemented yet, skip)

    // Step 6: For each mo of notifySet
    for (notify_set.items()) |mo_instance| {
        // Step 6.1: Let records be a clone of mo's record queue
        // Step 6.2: Empty mo's record queue (done by takeRecords())
        // takeRecords returns a JSValue (array), not a Zig slice
        // For now we'll call it but skip the callback invocation until
        // we have proper JS callback infrastructure
        _ = MutationObserver.call_takeRecords(mo_instance) catch continue;

        // Step 6.3: For each node of mo's node list, remove all transient registered observers
        // whose observer is mo from node's registered observer list
        // TODO: Implement when we have proper observer tracking per node
        // This requires MutationObserverImpl to track which nodes it's observing

        // Step 6.4: If records is not empty, then invoke mo's callback with « records, mo »
        // TODO: Implement callback invocation - requires:
        // 1. Access to the MutationObserver's stored callback
        // 2. JS function invocation through runtime
        // For now, records are cleared by takeRecords() above
    }

    // Step 7: For each slot of signalSet, fire an event named slotchange...
    // TODO: Implement slot change events when we have slots/shadow DOM
}

/// Remove transient registered observers for a specific MutationObserver from a node
/// Spec: https://dom.spec.whatwg.org/#notify-mutation-observers step 6.3
///
/// TODO: Implement when we have proper registered observer tracking per node.
/// This requires:
/// 1. Node instances to track their list of registered observers
/// 2. Each registered observer to track its source (the MutationObserver it came from)
/// 3. Ability to identify transient observers (those added for ancestor observation)
fn removeTransientObservers(node: *runtime.Instance, observer: *runtime.Instance) void {
    // Stub implementation - no-op until we have registered observer infrastructure
    _ = node;
    _ = observer;
}

// Tests
