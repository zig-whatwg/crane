//! updateCurrentEntry writes the entry captured before serialization, even
//! when script changes the current entry while serializing the new state.
const std = @import("std");
const joint = @import("html_core").navigation.joint_history;

test "navigation API state is written to the captured entry after another entry becomes current" {
    const allocator = std.testing.allocator;
    var history = joint.JointHistory.init(allocator);
    defer history.deinit();
    try history.addInitialEntry(1, "http://example.test/", null, "http://example.test");
    try history.setCurrentApiState(1, .{ .string = try allocator.dupe(u8, "old") });
    const captured = history.currentEntry(1).?.id;
    try history.commitSameDocument(1, "http://example.test/#new", .null, .push, .{ .string = try allocator.dupe(u8, "new entry") });

    history.setEntryApiState(captured, .{ .string = try allocator.dupe(u8, "serialized") });
    try std.testing.expectEqualStrings("serialized", history.entryById(captured).?.api_state.string);
    try std.testing.expectEqualStrings("new entry", history.currentEntry(1).?.api_state.string);
    // Updating twice must release the previous serialized state too.
    history.setEntryApiState(captured, .{ .bytes = try allocator.dupe(u8, &.{ 1, 2, 3 }) });
    try std.testing.expectEqualSlices(u8, &.{ 1, 2, 3 }, history.entryById(captured).?.api_state.bytes);
}

test "writing state to an entry removed during serialization releases the supplied state" {
    const allocator = std.testing.allocator;
    var history = joint.JointHistory.init(allocator);
    defer history.deinit();
    try history.addInitialEntry(1, "http://example.test/", null, "http://example.test");
    const removed = history.currentEntry(1).?.id;
    history.removeNavigable(1);
    try std.testing.expect(history.entryById(removed) == null);
    history.setEntryApiState(removed, .{ .string = try allocator.dupe(u8, "removed") });
    history.setEntryApiState(removed, .{ .bytes = try allocator.dupe(u8, &.{ 4, 5, 6 }) });
    try std.testing.expect(history.entryById(removed) == null);
}
