//! Tests migrated from webidl/src/dom/MutationObserver.zig
//! WebIDL interface tests

const std = @import("std");
const dom = @import("dom");

const source = @import("../../webidl/src/dom/MutationObserver.zig");

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