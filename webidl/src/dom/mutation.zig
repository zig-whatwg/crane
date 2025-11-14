const std = @import("std");
const Node = @import("node").Node;
const MutationObserver = @import("mutation_observer").MutationObserver;
const MutationRecord = @import("mutation_record").MutationRecord;
const dom_types = @import("dom_types");

/// Queue a mutation record per DOM spec
/// Spec: https://dom.spec.whatwg.org/#queue-a-mutation-record
pub fn queueMutationRecord(
    record_type: []const u8,
    target: *Node,
    name: ?[]const u8,
    namespace: ?[]const u8,
    old_value: ?[]const u8,
    added_nodes: []const *Node,
    removed_nodes: []const *Node,
    previous_sibling: ?*Node,
    next_sibling: ?*Node,
) !void {
    // Step 1: Let interestedObservers be an empty map
    var interested_observers = std.AutoHashMap(*MutationObserver, ?[]const u8).init(target.allocator);
    defer interested_observers.deinit();

    // Step 2: Let nodes be the inclusive ancestors of target
    var nodes = infra.List(*Node).init(target.allocator);
    defer nodes.deinit();

    var current: ?*Node = target;
    while (current) |node| {
        try nodes.append(node);
        current = node.parent_node;
    }

    // Step 3: For each node in nodes, and then for each registered of node's registered observer list
    for (nodes.items) |node| {
        const registered_list = node.getRegisteredObservers();
        for (registered_list) |registered| {
            const options = registered.options;

            // Step 3.2: Check if this observer is interested
            var interested = true;

            // node is not target and options["subtree"] is false
            if (node != target and !options.subtree) {
                interested = false;
            }

            // type is "attributes" and options["attributes"] is false/missing
            if (std.mem.eql(u8, record_type, "attributes")) {
                if (!options.attributes) {
                    interested = false;
                }
                // Check attributeFilter if it exists
                if (options.attribute_filter) |filter| {
                    if (name) |attr_name| {
                        var found = false;
                        for (filter) |filter_name| {
                            if (std.mem.eql(u8, filter_name, attr_name)) {
                                found = true;
                                break;
                            }
                        }
                        if (!found or namespace != null) {
                            interested = false;
                        }
                    }
                }
            }

            // type is "characterData" and options["characterData"] is false/missing
            if (std.mem.eql(u8, record_type, "characterData")) {
                if (!options.character_data) {
                    interested = false;
                }
            }

            // type is "childList" and options["childList"] is false
            if (std.mem.eql(u8, record_type, "childList")) {
                if (!options.child_list) {
                    interested = false;
                }
            }

            if (interested) {
                // Step 3.2.1: Let mo be registered's observer
                const mo = registered.observer;

                // Step 3.2.2: If interestedObservers[mo] does not exist, set to null
                const entry = try interested_observers.getOrPut(mo);
                if (!entry.found_existing) {
                    entry.value_ptr.* = null;
                }

                // Step 3.2.3: Set mappedOldValue if conditions met
                if ((std.mem.eql(u8, record_type, "attributes") and options.attribute_old_value) or
                    (std.mem.eql(u8, record_type, "characterData") and options.character_data_old_value))
                {
                    entry.value_ptr.* = old_value;
                }
            }
        }
    }

    // Step 4: For each observer → mappedOldValue of interestedObservers
    var iter = interested_observers.iterator();
    while (iter.next()) |entry| {
        const observer = entry.key_ptr.*;
        const mapped_old_value = entry.value_ptr.*;

        // Step 4.1: Create new MutationRecord
        const record = MutationRecord{
            .record_type = record_type,
            .target = target,
            .attribute_name = name,
            .attribute_namespace = namespace,
            .old_value = mapped_old_value,
            .added_nodes = added_nodes,
            .removed_nodes = removed_nodes,
            .previous_sibling = previous_sibling,
            .next_sibling = next_sibling,
        };

        // Step 4.2: Enqueue record to observer's record queue
        try observer.enqueueRecord(record);
    }
}

/// Queue a tree mutation record (specialized helper)
pub fn queueTreeMutationRecord(
    parent: *Node,
    added_nodes: []const *Node,
    removed_nodes: []const *Node,
    previous_sibling: ?*Node,
    next_sibling: ?*Node,
) !void {
    try queueMutationRecord(
        "childList",
        parent,
        null, // name
        null, // namespace
        null, // oldValue
        added_nodes,
        removed_nodes,
        previous_sibling,
        next_sibling,
    );
}
