//! Tests for MutationObserver lifetime management and weak references
//! Spec: https://dom.spec.whatwg.org/#mutationobserver-node-list

const std = @import("std");
const dom = @import("dom");
const infra = @import("infra");
const webidl = @import("webidl");
// Type aliases
const MutationRecord = dom.MutationRecord;

const MutationObserver = dom.MutationObserver;
const Node = Node;
const Element = Element;
const Document = Document;

fn testCallback(_: []const dom.MutationRecord, _: *MutationObserver) void {
    // Empty callback for testing
}

test "MutationObserver: node list stores weak references (doesn't own nodes)" {
    const allocator = std.testing.allocator;

    // Create observer
    var observer = try MutationObserver.init(allocator, testCallback);
    defer observer.deinit();

    // Create document and node
    var doc = try Document.init(allocator);
    defer doc.deinit();

    const elem = try doc.call_createElement("div");
    defer {
        elem.deinit();
        allocator.destroy(elem);
    }

    // Observe the node
    const options = MutationObserver.Init{
        .childList = true,
        .attributes = null,
        .characterData = null,
        .subtree = null,
        .attributeOldValue = null,
        .characterDataOldValue = null,
        .attributeFilter = null,
    };
    try observer.observe(@ptrCast(elem), options);

    // Verify node is in observation list
    try std.testing.expect(observer.isObserving(@ptrCast(elem)));

    // IMPORTANT: In Zig's manual memory management model, we must either:
    // 1. Keep the node alive while observer exists, OR
    // 2. Call disconnect() before freeing the node, OR
    // 3. Call unobserveNode() before freeing the node
    
    // For this test, we disconnect before the node is freed (by defer)
    observer.disconnect();
    
    // Verify node is no longer observed
    try std.testing.expect(!observer.isObserving(@ptrCast(elem)));
}

test "MutationObserver: isObserving checks if node is observed" {
    const allocator = std.testing.allocator;

    // Create observer
    var observer = try MutationObserver.init(allocator, testCallback);
    defer observer.deinit();

    // Create document and nodes
    var doc = try Document.init(allocator);
    defer doc.deinit();

    const elem1 = try doc.call_createElement("div");
    defer {
        elem1.deinit();
        allocator.destroy(elem1);
    }

    const elem2 = try doc.call_createElement("p");
    defer {
        elem2.deinit();
        allocator.destroy(elem2);
    }

    // Initially, nothing is observed
    try std.testing.expect(!observer.isObserving(@ptrCast(elem1)));
    try std.testing.expect(!observer.isObserving(@ptrCast(elem2)));

    // Observe first element
    const options = MutationObserver.Init{
        .childList = true,
        .attributes = null,
        .characterData = null,
        .subtree = null,
        .attributeOldValue = null,
        .characterDataOldValue = null,
        .attributeFilter = null,
    };
    try observer.observe(@ptrCast(elem1), options);

    // Only elem1 should be observed
    try std.testing.expect(observer.isObserving(@ptrCast(elem1)));
    try std.testing.expect(!observer.isObserving(@ptrCast(elem2)));

    // Observe second element
    try observer.observe(@ptrCast(elem2), options);

    // Both should be observed
    try std.testing.expect(observer.isObserving(@ptrCast(elem1)));
    try std.testing.expect(observer.isObserving(@ptrCast(elem2)));

    // Disconnect to clean up before nodes are freed
    observer.disconnect();
}

test "MutationObserver: unobserveNode removes specific node" {
    const allocator = std.testing.allocator;

    // Create observer
    var observer = try MutationObserver.init(allocator, testCallback);
    defer observer.deinit();

    // Create document and nodes
    var doc = try Document.init(allocator);
    defer doc.deinit();

    const elem1 = try doc.call_createElement("div");
    defer {
        elem1.deinit();
        allocator.destroy(elem1);
    }

    const elem2 = try doc.call_createElement("p");
    defer {
        elem2.deinit();
        allocator.destroy(elem2);
    }

    // Observe both elements
    const options = MutationObserver.Init{
        .childList = true,
        .attributes = null,
        .characterData = null,
        .subtree = null,
        .attributeOldValue = null,
        .characterDataOldValue = null,
        .attributeFilter = null,
    };
    try observer.observe(@ptrCast(elem1), options);
    try observer.observe(@ptrCast(elem2), options);

    // Both observed
    try std.testing.expect(observer.isObserving(@ptrCast(elem1)));
    try std.testing.expect(observer.isObserving(@ptrCast(elem2)));

    // Unobserve just elem1
    observer.unobserveNode(@ptrCast(elem1));

    // Only elem2 should be observed
    try std.testing.expect(!observer.isObserving(@ptrCast(elem1)));
    try std.testing.expect(observer.isObserving(@ptrCast(elem2)));

    // Clean up remaining observation
    observer.unobserveNode(@ptrCast(elem2));
}

test "MutationObserver: disconnect removes all observations" {
    const allocator = std.testing.allocator;

    // Create observer
    var observer = try MutationObserver.init(allocator, testCallback);
    defer observer.deinit();

    // Create document and nodes
    var doc = try Document.init(allocator);
    defer doc.deinit();

    const elem1 = try doc.call_createElement("div");
    defer {
        elem1.deinit();
        allocator.destroy(elem1);
    }

    const elem2 = try doc.call_createElement("p");
    defer {
        elem2.deinit();
        allocator.destroy(elem2);
    }

    // Observe both elements
    const options = MutationObserver.Init{
        .childList = true,
        .attributes = null,
        .characterData = null,
        .subtree = null,
        .attributeOldValue = null,
        .characterDataOldValue = null,
        .attributeFilter = null,
    };
    try observer.observe(@ptrCast(elem1), options);
    try observer.observe(@ptrCast(elem2), options);

    // Both observed
    try std.testing.expect(observer.isObserving(@ptrCast(elem1)));
    try std.testing.expect(observer.isObserving(@ptrCast(elem2)));

    // Disconnect removes all
    observer.disconnect();

    // Neither should be observed
    try std.testing.expect(!observer.isObserving(@ptrCast(elem1)));
    try std.testing.expect(!observer.isObserving(@ptrCast(elem2)));
}

test "MutationObserver: node list length via getNodeList" {
    const allocator = std.testing.allocator;

    // Create observer
    var observer = try MutationObserver.init(allocator, testCallback);
    defer observer.deinit();

    // Create document and nodes
    var doc = try Document.init(allocator);
    defer doc.deinit();

    const elem1 = try doc.call_createElement("div");
    defer {
        elem1.deinit();
        allocator.destroy(elem1);
    }

    const elem2 = try doc.call_createElement("p");
    defer {
        elem2.deinit();
        allocator.destroy(elem2);
    }

    const elem3 = try doc.call_createElement("span");
    defer {
        elem3.deinit();
        allocator.destroy(elem3);
    }

    // Initially empty
    try std.testing.expectEqual(@as(usize, 0), observer.getNodeList().len);

    // Observe nodes one by one
    const options = MutationObserver.Init{
        .childList = true,
        .attributes = null,
        .characterData = null,
        .subtree = null,
        .attributeOldValue = null,
        .characterDataOldValue = null,
        .attributeFilter = null,
    };
    
    try observer.observe(@ptrCast(elem1), options);
    try std.testing.expectEqual(@as(usize, 1), observer.getNodeList().len);

    try observer.observe(@ptrCast(elem2), options);
    try std.testing.expectEqual(@as(usize, 2), observer.getNodeList().len);

    try observer.observe(@ptrCast(elem3), options);
    try std.testing.expectEqual(@as(usize, 3), observer.getNodeList().len);

    // Disconnect clears all
    observer.disconnect();
    try std.testing.expectEqual(@as(usize, 0), observer.getNodeList().len);
}
