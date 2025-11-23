//! ConsoleState tests
//!
//! Tests for console state management in runtime.Context

const std = @import("std");
const runtime = @import("runtime");
const testing = std.testing;

test "ConsoleState - init and deinit" {
    var state = runtime.ConsoleState.init(testing.allocator);
    defer state.deinit(testing.allocator);

    try testing.expectEqual(@as(usize, 0), state.count_map.count());
    try testing.expectEqual(@as(usize, 0), state.timer_table.count());
    try testing.expectEqual(@as(usize, 0), state.group_stack.items.len);
}

test "ConsoleState - getIndentLevel" {
    var state = runtime.ConsoleState.init(testing.allocator);
    defer state.deinit(testing.allocator);

    try testing.expectEqual(@as(u32, 0), state.getIndentLevel());

    try state.group_stack.append(testing.allocator, 0);
    try testing.expectEqual(@as(u32, 1), state.getIndentLevel());

    try state.group_stack.append(testing.allocator, 0);
    try testing.expectEqual(@as(u32, 2), state.getIndentLevel());
}

test "ConsoleState - count_map operations" {
    var state = runtime.ConsoleState.init(testing.allocator);
    defer state.deinit(testing.allocator);

    // Add count
    const label = try testing.allocator.dupe(u8, "test");
    try state.count_map.put(label, 1);

    try testing.expectEqual(@as(u32, 1), state.count_map.get("test").?);

    // Increment
    try state.count_map.put(label, 2);
    try testing.expectEqual(@as(u32, 2), state.count_map.get("test").?);
}

test "ConsoleState - timer_table operations" {
    var state = runtime.ConsoleState.init(testing.allocator);
    defer state.deinit(testing.allocator);

    const label = try testing.allocator.dupe(u8, "timer");
    const now = std.time.milliTimestamp();

    try state.timer_table.put(label, now);
    try testing.expect(state.timer_table.contains("timer"));

    const stored_time = state.timer_table.get("timer").?;
    try testing.expectEqual(now, stored_time);
}

test "ConsoleState - group_stack push/pop" {
    var state = runtime.ConsoleState.init(testing.allocator);
    defer state.deinit(testing.allocator);

    try state.group_stack.append(testing.allocator, 1);
    try state.group_stack.append(testing.allocator, 2);
    try state.group_stack.append(testing.allocator, 3);

    try testing.expectEqual(@as(usize, 3), state.group_stack.items.len);

    _ = state.group_stack.pop();
    try testing.expectEqual(@as(usize, 2), state.group_stack.items.len);
}

test "ContextData - has console_state" {
    var ctx_data = try runtime.ContextData.init(testing.allocator, .{});
    defer ctx_data.deinit();

    // Verify console_state is initialized
    try testing.expectEqual(@as(usize, 0), ctx_data.console_state.count_map.count());
    try testing.expectEqual(@as(usize, 0), ctx_data.console_state.timer_table.count());
    try testing.expectEqual(@as(u32, 0), ctx_data.console_state.getIndentLevel());
}

test "ContextData - console_state deinit cleans up" {
    var ctx_data = try runtime.ContextData.init(testing.allocator, .{});
    defer ctx_data.deinit();

    // Add some state
    const label1 = try testing.allocator.dupe(u8, "count_label");
    try ctx_data.console_state.count_map.put(label1, 42);

    const label2 = try testing.allocator.dupe(u8, "timer_label");
    try ctx_data.console_state.timer_table.put(label2, std.time.milliTimestamp());

    try ctx_data.console_state.group_stack.append(testing.allocator, 1);

    // Context deinit should clean up all state
    // Testing allocator will detect leaks
}

test "Multiple contexts have separate console state" {
    var ctx1_data = try runtime.ContextData.init(testing.allocator, .{});
    defer ctx1_data.deinit();

    var ctx2_data = try runtime.ContextData.init(testing.allocator, .{});
    defer ctx2_data.deinit();

    const label1 = try testing.allocator.dupe(u8, "ctx1_label");
    try ctx1_data.console_state.count_map.put(label1, 10);

    const label2 = try testing.allocator.dupe(u8, "ctx2_label");
    try ctx2_data.console_state.count_map.put(label2, 20);

    // Verify separation
    try testing.expect(ctx1_data.console_state.count_map.contains("ctx1_label"));
    try testing.expect(!ctx1_data.console_state.count_map.contains("ctx2_label"));

    try testing.expect(!ctx2_data.console_state.count_map.contains("ctx1_label"));
    try testing.expect(ctx2_data.console_state.count_map.contains("ctx2_label"));
}
