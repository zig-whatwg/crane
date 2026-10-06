//! WebIDL 3.7.12: set iteration must observe mutation without revisiting holes.
const std = @import("std");
const States = @import("html").custom_elements.States;
const testing = std.testing;

test "CE2 custom states: duplicate, delete/readd, and clear during iteration" {
    var states = States.init(testing.allocator);
    defer states.deinit();
    try states.add("a");
    try states.add("b");
    try states.add("a");
    try testing.expectEqual(@as(usize, 2), states.size);
    states.beginIteration();
    var cursor: usize = 0;
    try testing.expectEqualStrings("a", states.next(&cursor).?);
    try testing.expect(states.remove("b"));
    try states.add("b");
    try testing.expectEqualStrings("b", states.next(&cursor).?);
    states.clear();
    try states.add("after-clear");
    try testing.expectEqualStrings("after-clear", states.next(&cursor).?);
    try testing.expectEqual(@as(?[]const u8, null), states.next(&cursor));
    states.endIteration();
    try testing.expectEqual(@as(usize, 1), states.values.items.len);
    try testing.expect(!states.has("a"));
    try testing.expect(states.has("after-clear"));
    states.clear();
    try testing.expectEqual(@as(usize, 0), states.values.items.len);
}

test "CE2 custom states: nested iterators preserve each cursor until both finish" {
    var states = States.init(testing.allocator);
    defer states.deinit();
    try states.add("");
    try states.add("ready");
    states.beginIteration();
    var outer: usize = 0;
    _ = states.next(&outer);
    states.beginIteration();
    states.clear();
    try states.add("again");
    states.endIteration();
    try testing.expectEqualStrings("again", states.next(&outer).?);
    states.endIteration();
    try testing.expectEqual(@as(usize, 1), states.values.items.len);
}
