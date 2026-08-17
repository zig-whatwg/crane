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
///
/// Spec: https://dom.spec.whatwg.org/#queueing-a-mutation-record
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
    const instance_bridge = @import("instance_bridge.zig");
    const handles = @import("handles.zig");
    const MutationObserverImpl = @import("impls").MutationObserver;
    const MutationRecordImpl = @import("impls").MutationRecord;

    // Get target's NodeBase for accessing registered observers
    const target_nodebase = instance_bridge.getNodeBase(@ptrCast(target)) orelse {
        // Target is not a registered node - can't dispatch mutations
        std.log.debug("[MutationObserver] queueMutationRecordInternal: target has no NodeBase", .{});
        return;
    };

    std.log.debug("[MutationObserver] queueMutationRecordInternal: type={s}, target Instance={*}, target NodeBase={*}", .{ mutation_type, target, target_nodebase });

    // Step 1: Let interestedObservers be an empty map
    // Maps observer instance to mappedOldValue
    var interested_observers = std.AutoHashMap(*runtime.Instance, ?[]const u8).init(allocator);
    defer interested_observers.deinit();

    // Step 2: Let nodes be the inclusive ancestors of target
    // Walk from target up to root
    var ancestors_count: usize = 0;
    var current: ?*@import("node_base.zig").NodeBase = target_nodebase;
    while (current) |node| : (current = node.parent_node) {
        ancestors_count += 1;
        if (node.registered_observers.len > 0) {
            std.log.debug("[MutationObserver] Checking node {*} with {} registered observers", .{ node, node.registered_observers.len });
        }
        // Step 3: For each node in nodes, for each registered of node's registered observer list
        for (0..node.registered_observers.len) |i| {
            const registered = node.registered_observers.get(i) orelse continue;
            const options = registered.options;

            // Step 3.2: If NONE of the following are true, then continue (skip this observer)
            var should_skip = false;

            // - node is not target and options["subtree"] is false
            if (node != target_nodebase and !options.subtree) {
                should_skip = true;
            }

            // - type is "attributes" and options["attributes"] is false
            if (!should_skip and std.mem.eql(u8, mutation_type, "attributes")) {
                if (!options.attributes) {
                    should_skip = true;
                }
                // - type is "attributes", options["attributeFilter"] exists, and
                //   options["attributeFilter"] does not contain name or namespace is non-null
                if (!should_skip) {
                    if (options.attribute_filter) |filter| {
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
            }

            // - type is "characterData" and options["characterData"] is false
            if (!should_skip and std.mem.eql(u8, mutation_type, "characterData")) {
                if (!options.character_data) {
                    should_skip = true;
                }
            }

            // - type is "childList" and options["childList"] is false
            if (!should_skip and std.mem.eql(u8, mutation_type, "childList")) {
                if (!options.child_list) {
                    should_skip = true;
                    std.log.debug("[MutationObserver] Skipping observer: childList=false", .{});
                }
            }

            if (should_skip) {
                std.log.debug("[MutationObserver] Observer skipped for mutation type '{s}'", .{mutation_type});
                continue;
            }

            std.log.debug("[MutationObserver] Found interested observer! node={*}, options.childList={}", .{ node, options.child_list });

            // Step 3.2.1: Let mo be registered's observer
            const observer_ptr = handles.mutationObserverToAnyopaque(registered.observer) orelse {
                std.log.debug("[MutationObserver] WARNING: mutationObserverToAnyopaque returned null!", .{});
                continue;
            };
            const mo: *runtime.Instance = @ptrCast(@alignCast(observer_ptr));
            std.log.debug("[MutationObserver] Observer instance: {*}", .{mo});

            // Step 3.2.2: If interestedObservers[mo] does not exist, then set it to null
            if (!interested_observers.contains(mo)) {
                try interested_observers.put(mo, null);
                std.log.debug("[MutationObserver] Added observer to interested_observers map", .{});
            }

            // Step 3.2.3: If either type is "attributes" and options["attributeOldValue"] is true,
            // or type is "characterData" and options["characterDataOldValue"] is true,
            // then set interestedObservers[mo] to oldValue
            if (std.mem.eql(u8, mutation_type, "attributes") and options.attribute_old_value) {
                try interested_observers.put(mo, old_value);
            } else if (std.mem.eql(u8, mutation_type, "characterData") and options.character_data_old_value) {
                try interested_observers.put(mo, old_value);
            }
        }
    }

    // Step 4: For each observer → mappedOldValue of interestedObservers
    std.log.debug("[MutationObserver] interested_observers count: {}", .{interested_observers.count()});
    var it = interested_observers.iterator();
    while (it.next()) |entry| {
        const observer = entry.key_ptr.*;
        const mapped_old_value = entry.value_ptr.*;
        std.log.debug("[MutationObserver] Processing interested observer: {*}", .{observer});

        // Step 4.1: Let record be a new MutationRecord object
        const ctx = target.ctx;
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
            mapped_old_value,
        );

        // Step 4.2: Enqueue record to observer's record queue
        std.log.debug("[MutationObserver] Enqueueing record to observer", .{});
        MutationObserverImpl.enqueueRecord(observer, record) catch {
            // If enqueueing fails, clean up the record
            std.log.debug("[MutationObserver] Failed to enqueue record!", .{});
            runtime.Instance.deinit(record);
            continue;
        };
        std.log.debug("[MutationObserver] Record enqueued successfully", .{});

        // Step 4.3: Append observer to the surrounding agent's pending mutation observers
        const agent = try getAgent(allocator);
        var already_pending = false;
        for (agent.pending_observers.items()) |pending| {
            if (pending == observer) {
                already_pending = true;
                break;
            }
        }
        if (!already_pending) {
            try agent.pending_observers.append(observer);
            std.log.debug("[MutationObserver] Added observer to pending_observers, total: {}", .{agent.pending_observers.len});
        } else {
            std.log.debug("[MutationObserver] Observer already pending", .{});
        }
    }

    std.log.debug("[MutationObserver] queueMutationRecordInternal complete, pending_observers: {}", .{(getAgent(allocator) catch unreachable).pending_observers.len});

    // Step 5: Queue a mutation observer microtask
    try queueMutationObserverMicrotask(allocator);
}

/// DOM §7.1 - Queue a mutation observer microtask
///
/// Queue a microtask to notify mutation observers.
///
/// Spec: https://dom.spec.whatwg.org/#queue-a-mutation-observer-compound-microtask
fn queueMutationObserverMicrotask(allocator: Allocator) !void {
    const MutationObserverImpl = @import("impls").MutationObserver;

    const agent = try getAgent(allocator);

    // Step 1: If the surrounding agent's mutation observer microtask queued is true, then return
    if (agent.microtask_queued) return;

    // Step 2: Set the surrounding agent's mutation observer microtask queued to true
    agent.microtask_queued = true;

    // Step 3: Queue a microtask to notify mutation observers
    // Delegate to the impl which has access to V8 for proper microtask queueing
    MutationObserverImpl.queueNotifyMicrotask(allocator) catch {
        // If queueing fails, fall back to synchronous execution
        std.log.err("MutationObserver: failed to queue microtask, falling back to synchronous", .{});
        try notifyMutationObservers(allocator);
    };
}

/// DOM §7.1 - Notify mutation observers
///
/// Invoke callbacks for all pending mutation observers.
///
/// Spec: https://dom.spec.whatwg.org/#notify-mutation-observers
pub fn notifyMutationObservers(allocator: Allocator) !void {
    const MutationObserverImpl = @import("impls").MutationObserver;

    std.log.debug("[MutationObserver] notifyMutationObservers called", .{});

    const agent = try getAgent(allocator);

    // Step 1: Set the surrounding agent's mutation observer microtask queued to false
    agent.microtask_queued = false;

    // Step 2: Let notifySet be a clone of the surrounding agent's pending mutation observers
    var notify_set = infra.List(*runtime.Instance).init(allocator);
    defer notify_set.deinit();
    try notify_set.appendSlice(agent.pending_observers.items());

    std.log.debug("[MutationObserver] notifySet has {} observers", .{notify_set.len});

    // Step 3: Empty the surrounding agent's pending mutation observers
    agent.pending_observers.clear();

    // Step 4: (signal slots - not implemented yet, skip)

    // Step 6: For each mo of notifySet
    for (notify_set.items()) |mo_instance| {
        // Step 6.1: Let records be a clone of mo's record queue
        const records = MutationObserverImpl.getRecordQueue(mo_instance);

        std.log.debug("[MutationObserver] Processing observer {*}, records.len={}", .{ mo_instance, records.len });

        // Skip if no records
        if (records.len == 0) {
            std.log.debug("[MutationObserver] No records for observer, skipping", .{});
            continue;
        }

        // Step 6.2: Empty mo's record queue
        // We need to take ownership of the records before clearing
        var records_copy = infra.List(*runtime.Instance).init(allocator);
        defer records_copy.deinit();
        for (records) |record| {
            records_copy.append(record) catch continue;
        }
        MutationObserverImpl.clearRecordQueue(mo_instance);

        // Step 6.3: For each node of mo's node list, remove all transient registered observers
        // whose observer is mo from node's registered observer list
        // TODO: Implement transient observer removal

        // Step 6.4: If records is not empty, then invoke mo's callback with « records, mo »
        if (records_copy.len > 0) {
            // Delegate callback invocation to the impl layer which has V8 access
            std.log.debug("[MutationObserver] Invoking callback with {} records", .{records_copy.len});
            MutationObserverImpl.invokeCallback(mo_instance, records_copy.items()) catch |err| {
                std.log.err("[MutationObserver] invokeCallback failed: {}", .{err});
                // If callback invocation fails, clean up records
                for (records_copy.items()) |record| {
                    runtime.Instance.deinit(record);
                }
            };
            std.log.debug("[MutationObserver] Callback invocation completed", .{});
            // Note: Records ownership is transferred to invokeCallback, which will clean them up
        }
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
