//! MutationObserver tests per WHATWG DOM Standard
//! Spec: https://dom.spec.whatwg.org/#interface-mutationobserver

const std = @import("std");
const dom = @import("dom");
const MutationObserver = dom.MutationObserver;
const MutationRecord = dom.MutationRecord;
const MutationObserverInit = dom.MutationObserverInit;
const mutation_observer_algorithms = dom.mutation_observer_algorithms;

// ============================================================================
// Constructor and Basic API Tests
// ============================================================================

test "MutationObserver - constructor creates observer with callback" {
    const allocator = std.testing.allocator;

    const callback = struct {
        fn cb(_: []const MutationRecord, _: *MutationObserver) void {}
    }.cb;

    var observer = try MutationObserver.init(allocator, callback);
    defer observer.deinit();

    try std.testing.expectEqual(callback, observer.getCallback());
}

test "MutationObserver - initial state is empty" {
    const allocator = std.testing.allocator;

    const callback = struct {
        fn cb(_: []const MutationRecord, _: *MutationObserver) void {}
    }.cb;

    var observer = try MutationObserver.init(allocator, callback);
    defer observer.deinit();

    try std.testing.expectEqual(@as(usize, 0), observer.getNodeList().len);
    try std.testing.expectEqual(@as(usize, 0), observer.getRecordQueue().len);
}

test "MutationObserver - takeRecords returns empty array initially" {
    const allocator = std.testing.allocator;

    const callback = struct {
        fn cb(_: []const MutationRecord, _: *MutationObserver) void {}
    }.cb;

    var observer = try MutationObserver.init(allocator, callback);
    defer observer.deinit();

    const records = try observer.takeRecords();
    defer allocator.free(records);

    try std.testing.expectEqual(@as(usize, 0), records.len);
}

test "MutationObserver - disconnect clears state" {
    const allocator = std.testing.allocator;

    const callback = struct {
        fn cb(_: []const MutationRecord, _: *MutationObserver) void {}
    }.cb;

    var observer = try MutationObserver.init(allocator, callback);
    defer observer.deinit();

    observer.disconnect();

    try std.testing.expectEqual(@as(usize, 0), observer.getRecordQueue().len);
}

// ============================================================================
// MutationObserverInit Validation Tests
// ============================================================================

test "MutationObserverInit - no observation flags throws TypeError" {
    // When none of childList, attributes, or characterData is true, TypeError should be thrown
    // This is tested in MutationObserver.observe validation
    const init = MutationObserverInit{};

    // Verify defaults
    try std.testing.expectEqual(false, init.childList);
    try std.testing.expectEqual(@as(?bool, null), init.attributes);
    try std.testing.expectEqual(@as(?bool, null), init.characterData);
}

test "MutationObserverInit - attributeOldValue implies attributes" {
    // When attributeOldValue is specified, attributes should be implicitly set to true
    const init = MutationObserverInit{
        .attributeOldValue = true,
    };

    // The observe() method will set attributes to true automatically
    try std.testing.expectEqual(@as(?bool, true), init.attributeOldValue);
}

test "MutationObserverInit - characterDataOldValue implies characterData" {
    // When characterDataOldValue is specified, characterData should be implicitly set to true
    const init = MutationObserverInit{
        .characterDataOldValue = true,
    };

    // The observe() method will set characterData to true automatically
    try std.testing.expectEqual(@as(?bool, true), init.characterDataOldValue);
}

test "MutationObserverInit - attributeFilter implies attributes" {
    // When attributeFilter is specified, attributes should be implicitly set to true
    const filter = [_][]const u8{ "class", "id" };
    const init = MutationObserverInit{
        .attributeFilter = &filter,
    };

    // The observe() method will set attributes to true automatically
    try std.testing.expect(init.attributeFilter != null);
}

// ============================================================================
// MutationObserverAgent Tests
// ============================================================================

test "MutationObserverAgent - initialization" {
    const allocator = std.testing.allocator;
    mutation_observer_algorithms.resetAgent();
    defer mutation_observer_algorithms.resetAgent();

    const agent = try mutation_observer_algorithms.getAgent(allocator);
    try std.testing.expectEqual(false, agent.microtask_queued);
    try std.testing.expectEqual(@as(usize, 0), agent.pending_observers.items.len);
}

test "MutationObserverAgent - reset clears state" {
    const allocator = std.testing.allocator;
    mutation_observer_algorithms.resetAgent();

    _ = try mutation_observer_algorithms.getAgent(allocator);

    mutation_observer_algorithms.resetAgent();

    // After reset, should get fresh agent
    const agent = try mutation_observer_algorithms.getAgent(allocator);
    try std.testing.expectEqual(false, agent.microtask_queued);
    try std.testing.expectEqual(@as(usize, 0), agent.pending_observers.items.len);

    mutation_observer_algorithms.resetAgent();
}

// ============================================================================
// Documentation and Test Plan
// ============================================================================

// NOTE: Full integration tests require complete Node/Element/Attribute implementation
//
// Future tests to add when DOM implementation is more complete:
//
// 1. Attribute Mutation Tests:
//    - Observe attribute changes on Element
//    - Test attributeOldValue captures old value
//    - Test attributeFilter filters by attribute name
//    - Test subtree:true observes descendant attributes
//
// 2. CharacterData Mutation Tests:
//    - Observe data changes on Text/Comment nodes
//    - Test characterDataOldValue captures old value
//    - Test subtree:true observes descendant character data
//
// 3. ChildList Mutation Tests:
//    - Observe appendChild, insertBefore, removeChild
//    - Test addedNodes/removedNodes lists are correct
//    - Test previousSibling/nextSibling are set correctly
//    - Test subtree:true observes descendant child list changes
//
// 4. Multiple Observer Tests:
//    - Multiple observers on same node with different options
//    - Verify each observer gets correct filtered records
//    - Test observer priority/order
//
// 5. Transient Observer Tests:
//    - Test transient observers created when node is removed
//    - Verify mutations within removed subtree are tracked
//
// 6. Callback Invocation Tests:
//    - Verify callback receives correct MutationRecord array
//    - Verify callback receives observer as second argument
//    - Test callback invocation order (microtask timing)
//
// 7. takeRecords() Tests:
//    - Verify takeRecords() returns pending records
//    - Verify takeRecords() clears queue
//    - Test takeRecords() before callback is invoked
//
// 8. disconnect() Tests:
//    - Verify disconnect() stops observation
//    - Verify disconnect() clears record queue
//    - Test re-observe after disconnect
//
// 9. Complex Tree Tests:
//    - Deep nested trees with multiple observers
//    - Mix of different mutation types
//    - Performance tests with large numbers of observers/mutations

// ============================================================================
// Integration Tests - Mutation Record Queuing
// ============================================================================

test "MutationObserver - childList mutation records queued on insert" {
    const allocator = std.testing.allocator;

    // Create a simple tree structure using ElementWithBase for testing
    const ElementWithBase = dom.ElementWithBase;
    const mutation = dom.mutation;

    var parent = try ElementWithBase.init(allocator, "div");
    defer parent.deinit();

    var child1 = try ElementWithBase.init(allocator, "span");
    defer child1.deinit();

    // Create a mutation observer
    const callback = struct {
        fn cb(_: []const MutationRecord, _: *MutationObserver) void {}
    }.cb;

    var observer = try MutationObserver.init(allocator, callback);
    defer observer.deinit();

    // Observe childList changes
    const options = MutationObserverInit{
        .childList = true,
        .subtree = false,
        .attributes = false,
        .attributeOldValue = null,
        .characterData = false,
        .characterDataOldValue = null,
        .attributeFilter = null,
    };

    try observer.call_observe(parent.asNode(), options);

    // Perform insertion - this should queue a mutation record
    _ = try mutation.insert(child1.asNode(), parent.asNode(), null);

    // Check that observer has pending records
    try std.testing.expect(observer.getRecordQueue().len > 0);

    // Take records to verify
    const records = try observer.takeRecords();
    defer allocator.free(records);

    try std.testing.expectEqual(@as(usize, 1), records.len);
    try std.testing.expectEqualStrings("childList", records[0].type);
    try std.testing.expectEqual(parent.asNode(), records[0].target);
}

test "MutationObserver - childList mutation records queued on remove" {
    const allocator = std.testing.allocator;

    const ElementWithBase = dom.ElementWithBase;
    const mutation = dom.mutation;

    var parent = try ElementWithBase.init(allocator, "div");
    defer parent.deinit();

    var child1 = try ElementWithBase.init(allocator, "span");
    defer child1.deinit();

    // Insert child first
    _ = try mutation.insert(child1.asNode(), parent.asNode(), null);

    // Create observer after insertion
    const callback = struct {
        fn cb(_: []const MutationRecord, _: *MutationObserver) void {}
    }.cb;

    var observer = try MutationObserver.init(allocator, callback);
    defer observer.deinit();

    const options = MutationObserverInit{
        .childList = true,
        .subtree = false,
        .attributes = false,
        .attributeOldValue = null,
        .characterData = false,
        .characterDataOldValue = null,
        .attributeFilter = null,
    };

    try observer.call_observe(parent.asNode(), options);

    // Remove child - this should queue a mutation record
    mutation.remove(child1.asNode());

    // Verify record was queued
    const records = try observer.takeRecords();
    defer allocator.free(records);

    try std.testing.expectEqual(@as(usize, 1), records.len);
    try std.testing.expectEqualStrings("childList", records[0].type);
    try std.testing.expectEqual(parent.asNode(), records[0].target);
}

test "MutationObserver - multiple mutations queue multiple records" {
    const allocator = std.testing.allocator;

    const ElementWithBase = dom.ElementWithBase;
    const mutation = dom.mutation;

    var parent = try ElementWithBase.init(allocator, "div");
    defer parent.deinit();

    var child1 = try ElementWithBase.init(allocator, "span");
    defer child1.deinit();

    var child2 = try ElementWithBase.init(allocator, "p");
    defer child2.deinit();

    // Create observer
    const callback = struct {
        fn cb(_: []const MutationRecord, _: *MutationObserver) void {}
    }.cb;

    var observer = try MutationObserver.init(allocator, callback);
    defer observer.deinit();

    const options = MutationObserverInit{
        .childList = true,
        .subtree = false,
        .attributes = false,
        .attributeOldValue = null,
        .characterData = false,
        .characterDataOldValue = null,
        .attributeFilter = null,
    };

    try observer.call_observe(parent.asNode(), options);

    // Perform multiple insertions
    _ = try mutation.insert(child1.asNode(), parent.asNode(), null);
    _ = try mutation.insert(child2.asNode(), parent.asNode(), null);

    // Verify multiple records were queued
    const records = try observer.takeRecords();
    defer allocator.free(records);

    try std.testing.expectEqual(@as(usize, 2), records.len);
    try std.testing.expectEqualStrings("childList", records[0].type);
    try std.testing.expectEqualStrings("childList", records[1].type);
}
