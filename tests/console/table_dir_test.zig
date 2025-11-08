//! Tests for console.table() and console.dir() with runtime integration

const std = @import("std");
const console = @import("console");
const webidl = @import("webidl");
const mock_runtime = @import("mock_runtime.zig");

test "console.table() - without runtime (fallback)" {
    const allocator = std.testing.allocator;

    var console_obj = try console.Console.init(allocator);
    defer console_obj.deinit();

    // No runtime - should fall back to logging
    const data = webidl.JSValue{ .string = "test data" };
    console_obj.call_table(&data, null);

    // Verify message was buffered
    try std.testing.expectEqual(@as(usize, 1), console_obj.message_buffer.size());
}

test "console.table() - with runtime (array)" {
    const allocator = std.testing.allocator;

    var console_obj = try console.Console.init(allocator);
    defer console_obj.deinit();

    const runtime = try mock_runtime.createMockRuntime(allocator);
    defer mock_runtime.destroyMockRuntime(runtime, allocator);

    console_obj.runtime = runtime;

    // Set up mock to return array with 3 elements
    mock_runtime.setTestArrayLength(runtime, 3);

    // Note: MockRuntime.isArray returns false for simple JSValue
    // This test verifies the fallback behavior
    const data = webidl.JSValue{ .string = "array data" };
    console_obj.call_table(&data, null);

    // Should have logged (fallback since isArray returns false)
    try std.testing.expectEqual(@as(usize, 1), console_obj.message_buffer.size());
}

test "console.table() - null data" {
    const allocator = std.testing.allocator;

    var console_obj = try console.Console.init(allocator);
    defer console_obj.deinit();

    // Null data - should log empty
    console_obj.call_table(null, null);

    try std.testing.expectEqual(@as(usize, 1), console_obj.message_buffer.size());
}

test "console.dir() - without runtime" {
    const allocator = std.testing.allocator;

    var console_obj = try console.Console.init(allocator);
    defer console_obj.deinit();

    // No runtime - should use simple logging
    const item = webidl.JSValue{ .string = "test object" };
    console_obj.call_dir(&item, null);

    // Verify message was buffered
    try std.testing.expectEqual(@as(usize, 1), console_obj.message_buffer.size());
}

test "console.dir() - with runtime" {
    const allocator = std.testing.allocator;

    var console_obj = try console.Console.init(allocator);
    defer console_obj.deinit();

    const runtime = try mock_runtime.createMockRuntime(allocator);
    defer mock_runtime.destroyMockRuntime(runtime, allocator);

    console_obj.runtime = runtime;

    // dir() should use runtime's toString
    const item = webidl.JSValue{ .string = "test object" };
    console_obj.call_dir(&item, null);

    // Verify message was buffered
    try std.testing.expectEqual(@as(usize, 1), console_obj.message_buffer.size());
}

test "console.dir() - with options" {
    const allocator = std.testing.allocator;

    var console_obj = try console.Console.init(allocator);
    defer console_obj.deinit();

    const runtime = try mock_runtime.createMockRuntime(allocator);
    defer mock_runtime.destroyMockRuntime(runtime, allocator);

    console_obj.runtime = runtime;

    // dir() with options (options are currently ignored but accepted)
    const item = webidl.JSValue{ .string = "test object" };
    const options = webidl.JSValue{ .string = "{depth: 2}" };
    console_obj.call_dir(&item, &options);

    // Verify message was buffered
    try std.testing.expectEqual(@as(usize, 1), console_obj.message_buffer.size());
}

test "console.dir() - null item" {
    const allocator = std.testing.allocator;

    var console_obj = try console.Console.init(allocator);
    defer console_obj.deinit();

    // Null item - should log empty
    console_obj.call_dir(null, null);

    try std.testing.expectEqual(@as(usize, 1), console_obj.message_buffer.size());
}

test "console.dir() - number value" {
    const allocator = std.testing.allocator;

    var console_obj = try console.Console.init(allocator);
    defer console_obj.deinit();

    const runtime = try mock_runtime.createMockRuntime(allocator);
    defer mock_runtime.destroyMockRuntime(runtime, allocator);

    console_obj.runtime = runtime;

    // dir() should work with any value type
    const item = webidl.JSValue{ .number = 42 };
    console_obj.call_dir(&item, null);

    try std.testing.expectEqual(@as(usize, 1), console_obj.message_buffer.size());
}

test "console.dir() - boolean value" {
    const allocator = std.testing.allocator;

    var console_obj = try console.Console.init(allocator);
    defer console_obj.deinit();

    const runtime = try mock_runtime.createMockRuntime(allocator);
    defer mock_runtime.destroyMockRuntime(runtime, allocator);

    console_obj.runtime = runtime;

    const item = webidl.JSValue{ .boolean = true };
    console_obj.call_dir(&item, null);

    try std.testing.expectEqual(@as(usize, 1), console_obj.message_buffer.size());
}
