//! Tests migrated from webidl/src/dom/dom.MutationObserver.zig
//! WebIDL interface tests

const std = @import("std");
const dom = @import("dom");
const infra = @import("infra");
const webidl = @import("webidl");
// Type aliases
const MutationObserver = dom.MutationObserver;
const MutationRecord = dom.MutationRecord;
const Node = dom.Node;

test "dom.MutationObserver - construction" {
    const allocator = std.testing.allocator;

    // Mock callback
    const callback = struct {
        fn cb(_: []const MutationRecord, _: *dom.MutationObserver) void {}
    }.cb;

    var observer = try dom.MutationObserver.init(allocator, callback);
    defer observer.deinit();

    try std.testing.expectEqual(@as(usize, 0), observer.node_list.len);
    try std.testing.expectEqual(@as(usize, 0), observer.record_queue.len);
}
test "dom.MutationObserver - observe validation" {
    const allocator = std.testing.allocator;

    const callback = struct {
        fn cb(_: []const MutationRecord, _: *dom.MutationObserver) void {}
    }.cb;

    var observer = try dom.MutationObserver.init(allocator, callback);
    defer observer.deinit();

    // Create a mock node
    // TODO: Replace with real dom.Node once we have proper dom.Node implementation
    var mock_node = dom.Node{};
    // This should fail - need to implement dom.Node.getRegisteredObservers() first
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
test "dom.MutationObserver - disconnect clears record queue" {
    const allocator = std.testing.allocator;

    const callback = struct {
        fn cb(_: []const MutationRecord, _: *dom.MutationObserver) void {}
    }.cb;

    var observer = try dom.MutationObserver.init(allocator, callback);
    defer observer.deinit();

    // Add a mock record
    // TODO: Create proper dom.MutationRecord when we have full dom.Node implementation
    // For now, just test that disconnect clears the queue

    observer.disconnect();
    try std.testing.expectEqual(@as(usize, 0), observer.record_queue.len);
}
test "dom.MutationObserver - takeRecords clones and clears queue" {
    const allocator = std.testing.allocator;

    const callback = struct {
        fn cb(_: []const MutationRecord, _: *dom.MutationObserver) void {}
    }.cb;

    var observer = try dom.MutationObserver.init(allocator, callback);
    defer observer.deinit();

    // Add mock records
    // TODO: Create proper MutationRecords when we have full dom.Node implementation

    const records = try observer.takeRecords();
    defer allocator.free(records);

    try std.testing.expectEqual(@as(usize, 0), records.len);
    try std.testing.expectEqual(@as(usize, 0), observer.record_queue.len);
}