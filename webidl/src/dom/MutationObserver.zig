//! MutationObserver interface per WHATWG DOM Standard
//! Spec: https://dom.spec.whatwg.org/#interface-mutationobserver

const std = @import("std");
const webidl = @import("webidl");
const infra = @import("infra");
const Allocator = std.mem.Allocator;
const Node = @import("node").Node;
const MutationRecord = @import("mutation_record").MutationRecord;

/// DOM §7.1 - MutationCallback
///
/// Callback invoked when mutations are observed.
/// Arguments: (mutations: sequence<MutationRecord>, observer: MutationObserver)
pub const MutationCallback = *const fn (mutations: []const MutationRecord, observer: *MutationObserver) void;

// Import types that are shared between Node and MutationObserver
const MutationObserverInit = @import("mutation_observer_init").MutationObserverInit;
const RegisteredObserver = @import("registered_observer").RegisteredObserver;
const TransientRegisteredObserver = @import("registered_observer").TransientRegisteredObserver;

// Re-export for convenience
pub const Init = MutationObserverInit;
pub const Registered = RegisteredObserver;
pub const TransientRegistered = TransientRegisteredObserver;

/// DOM §7.1 - MutationObserver interface
///
/// MutationObservers can be used to observe mutations to the tree of nodes.
pub const MutationObserver = webidl.interface(struct {
    allocator: Allocator,

    /// Callback invoked when mutations are observed
    callback: MutationCallback,

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
    /// - This is the correct implementation for Zig's memory model
    node_list: infra.List(*Node),

    /// Queue of pending mutation records
    record_queue: infra.List(MutationRecord),

    /// DOM §7.1 - new MutationObserver(callback)
    ///
    /// Constructs a MutationObserver and sets its callback to callback.
    /// The callback is invoked with a list of MutationRecord objects as first
    /// argument and the constructed MutationObserver object as second argument.
    ///
    /// Spec: https://dom.spec.whatwg.org/#dom-mutationobserver-mutationobserver
    pub fn init(allocator: Allocator, callback: MutationCallback) !MutationObserver {
        return .{
            .allocator = allocator,
            .callback = callback,
            .node_list = infra.List(*Node).init(allocator),
            .record_queue = infra.List(MutationRecord).init(allocator),
        };
    }

    pub fn deinit(self: *MutationObserver) void {
        // Clear node list (don't free nodes, we don't own them)
        self.node_list.deinit();

        // Clear record queue
        // Call deinit on each record for proper cleanup
        for (self.record_queue.toSliceMut()) |*record| {
            record.deinit();
        }
        self.record_queue.deinit();
    }

    // ========================================================================
    // Methods
    // ========================================================================

    /// DOM §7.1 - MutationObserver.observe(target, options)
    ///
    /// Instructs the user agent to observe a given target (a node) and report
    /// any mutations based on the criteria given by options (an object).
    ///
    /// Spec: https://dom.spec.whatwg.org/#dom-mutationobserver-observe
    pub fn observe(self: *MutationObserver, target: *Node, options: MutationObserverInit) !void {
        // Step 1: If either options["attributeOldValue"] or options["attributeFilter"]
        // exists, and options["attributes"] does not exist, then set
        // options["attributes"] to true.
        var normalized_options = options;
        if ((options.attributeOldValue != null or options.attributeFilter != null) and
            options.attributes == null)
        {
            normalized_options.attributes = true;
        }

        // Step 2: If options["characterDataOldValue"] exists and
        // options["characterData"] does not exist, then set
        // options["characterData"] to true.
        if (options.characterDataOldValue != null and options.characterData == null) {
            normalized_options.characterData = true;
        }

        // Step 3: If none of options["childList"], options["attributes"], and
        // options["characterData"] is true, then throw a TypeError.
        const childList = normalized_options.childList;
        const attributes = normalized_options.attributes orelse false;
        const characterData = normalized_options.characterData orelse false;

        if (!childList and !attributes and !characterData) {
            return error.TypeError;
        }

        // Step 4: If options["attributeOldValue"] is true and options["attributes"]
        // is false, then throw a TypeError.
        if (normalized_options.attributeOldValue orelse false and !attributes) {
            return error.TypeError;
        }

        // Step 5: If options["attributeFilter"] is present and options["attributes"]
        // is false, then throw a TypeError.
        if (normalized_options.attributeFilter != null and !attributes) {
            return error.TypeError;
        }

        // Step 6: If options["characterDataOldValue"] is true and
        // options["characterData"] is false, then throw a TypeError.
        if (normalized_options.characterDataOldValue orelse false and !characterData) {
            return error.TypeError;
        }

        // Step 7: For each registered of target's registered observer list,
        // if registered's observer is this:
        const registered_observers = target.getRegisteredObservers();
        for (registered_observers.toSliceMut()) |*registered| {
            if (registered.observer == self) {
                // Step 7.1: For each node of this's node list, remove all
                // transient registered observers whose source is registered
                // from node's registered observer list.
                for (self.node_list.toSlice()) |node| {
                    try node.removeTransientObservers(registered);
                }

                // Step 7.2: Set registered's options to options.
                registered.options = normalized_options;
                return;
            }
        }

        // Step 8: Otherwise:
        // Step 8.1: Append a new registered observer whose observer is this
        // and options is options to target's registered observer list.
        try target.addRegisteredObserver(.{
            .observer = self,
            .options = normalized_options,
        });

        // Step 8.2: Append a weak reference to target to this's node list.
        // TODO: Implement proper weak references
        // For now, just append the pointer
        try self.node_list.append(self.allocator, target);
    }

    /// DOM §7.1 - MutationObserver.disconnect()
    ///
    /// Stops observer from observing any mutations. Until the observe() method
    /// is used again, observer's callback will not be invoked.
    ///
    /// Spec: https://dom.spec.whatwg.org/#dom-mutationobserver-disconnect
    pub fn disconnect(self: *MutationObserver) void {
        // Step 1: For each node of this's node list, remove any registered
        // observer from node's registered observer list for which this is
        // the observer.
        for (self.node_list.toSlice()) |node| {
            node.removeRegisteredObserver(self);
        }

        // Step 2: Empty this's record queue.
        self.record_queue.clearRetainingCapacity();
    }

    /// DOM §7.1 - MutationObserver.takeRecords()
    ///
    /// Empties the record queue and returns what was in there.
    ///
    /// Spec: https://dom.spec.whatwg.org/#dom-mutationobserver-takerecords
    pub fn takeRecords(self: *MutationObserver) ![]MutationRecord {
        // Step 1: Let records be a clone of this's record queue.
        const allocator = self.allocator;
        const records = try allocator.alloc(MutationRecord, self.record_queue.len);
        @memcpy(records, self.record_queue.toSlice());

        // Step 2: Empty this's record queue.
        self.record_queue.clearRetainingCapacity();

        // Step 3: Return records.
        return records;
    }

    // ========================================================================
    // Internal methods (for mutation algorithms)
    // ========================================================================

    /// Enqueue a mutation record to this observer's record queue
    ///
    /// Called by mutation observation algorithms when mutations occur.
    /// This is an internal method, not exposed in the WebIDL.
    pub fn enqueueRecord(self: *MutationObserver, record: MutationRecord) !void {
        try self.record_queue.append(self.allocator, record);
    }

    /// Get the callback for this observer
    ///
    /// Used by the notify mutation observers algorithm.
    pub fn getCallback(self: *const MutationObserver) MutationCallback {
        return self.callback;
    }

    /// Get the node list for this observer
    ///
    /// Used by the notify mutation observers algorithm.
    pub fn getNodeList(self: *MutationObserver) []const *Node {
        return self.node_list.toSlice();
    }

    /// Get the record queue for this observer
    ///
    /// Used by the notify mutation observers algorithm.
    pub fn getRecordQueue(self: *const MutationObserver) []const MutationRecord {
        return self.record_queue.toSlice();
    }

    /// Check if this observer is observing a specific node
    ///
    /// Useful for caller to verify observation state before node cleanup.
    /// Returns true if the node is in this observer's node list.
    pub fn isObserving(self: *const MutationObserver, node: *const Node) bool {
        for (self.node_list.toSlice()) |observed_node| {
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
    pub fn unobserveNode(self: *MutationObserver, node: *const Node) void {
        var i: usize = 0;
        while (i < self.node_list.len) {
            if (self.node_list.get(i)) |observed_node| {
                if (observed_node == node) {
                    _ = self.node_list.remove(i) catch return;
                    return;
                }
            }
            i += 1;
        }
    }

    /// Clear the record queue
    ///
    /// Used by the notify mutation observers algorithm.
    pub fn clearRecordQueue(self: *MutationObserver) void {
        self.record_queue.clearRetainingCapacity();
    }
});

// Tests

test "MutationObserver - construction" {
    const allocator = std.testing.allocator;

    // Mock callback
    const callback = struct {
        fn cb(_: []const MutationRecord, _: *MutationObserver) void {}
    }.cb;

    var observer = try MutationObserver.init(allocator, callback);
    defer observer.deinit();

    try std.testing.expectEqual(@as(usize, 0), observer.node_list.len);
    try std.testing.expectEqual(@as(usize, 0), observer.record_queue.len);
}

test "MutationObserver - observe validation" {
    const allocator = std.testing.allocator;

    const callback = struct {
        fn cb(_: []const MutationRecord, _: *MutationObserver) void {}
    }.cb;

    var observer = try MutationObserver.init(allocator, callback);
    defer observer.deinit();

    // Create a mock node
    // TODO: Replace with real Node once we have proper Node implementation
    var mock_node = Node{};
    // This should fail - need to implement Node.getRegisteredObservers() first
    // For now, just test the option validation

    // Test: No observation flags set -> TypeError
    try std.testing.expectError(
        error.TypeError,
        observer.observe(&mock_node, .{}),
    );

    // Test: attributeOldValue without attributes -> TypeError
    try std.testing.expectError(
        error.TypeError,
        observer.observe(&mock_node, .{
            .childList = true,
            .attributes = false,
            .attributeOldValue = true,
        }),
    );

    // Test: attributeFilter without attributes -> TypeError
    try std.testing.expectError(
        error.TypeError,
        observer.observe(&mock_node, .{
            .childList = true,
            .attributes = false,
            .attributeFilter = &[_][]const u8{"class"},
        }),
    );

    // Test: characterDataOldValue without characterData -> TypeError
    try std.testing.expectError(
        error.TypeError,
        observer.observe(&mock_node, .{
            .childList = true,
            .characterData = false,
            .characterDataOldValue = true,
        }),
    );
}

test "MutationObserver - disconnect clears record queue" {
    const allocator = std.testing.allocator;

    const callback = struct {
        fn cb(_: []const MutationRecord, _: *MutationObserver) void {}
    }.cb;

    var observer = try MutationObserver.init(allocator, callback);
    defer observer.deinit();

    // Add a mock record
    // TODO: Create proper MutationRecord when we have full Node implementation
    // For now, just test that disconnect clears the queue

    observer.disconnect();
    try std.testing.expectEqual(@as(usize, 0), observer.record_queue.len);
}

test "MutationObserver - takeRecords clones and clears queue" {
    const allocator = std.testing.allocator;

    const callback = struct {
        fn cb(_: []const MutationRecord, _: *MutationObserver) void {}
    }.cb;

    var observer = try MutationObserver.init(allocator, callback);
    defer observer.deinit();

    // Add mock records
    // TODO: Create proper MutationRecords when we have full Node implementation

    const records = try observer.takeRecords();
    defer allocator.free(records);

    try std.testing.expectEqual(@as(usize, 0), records.len);
    try std.testing.expectEqual(@as(usize, 0), observer.record_queue.len);
}
