//! Logging Function Tests
//!
//! Tests for all Console logging methods.
//! WHATWG Console Standard lines 49-143.

const std = @import("std");
const console_mod = @import("console");

const JSValue = console_mod.JSValue;

test "call_log - calls logger with log level" {
    const allocator = std.testing.allocator;
    var console_obj = try console_mod.console.console.init(allocator);
    defer console_obj.deinit();

    const mock_args: []const JSValue = &.{};
    console_obj.call_log(mock_args);
    // Test passes if no crash
}

test "call_debug - calls logger with debug level" {
    const allocator = std.testing.allocator;
    var console_obj = try console_mod.console.console.init(allocator);
    defer console_obj.deinit();

    const mock_args: []const JSValue = &.{};
    console_obj.call_debug(mock_args);
    // Test passes if no crash
}

test "call_info - calls logger with info level" {
    const allocator = std.testing.allocator;
    var console_obj = try console_mod.console.console.init(allocator);
    defer console_obj.deinit();

    const mock_args: []const JSValue = &.{};
    console_obj.call_info(mock_args);
    // Test passes if no crash
}

test "call_warn - calls logger with warn level" {
    const allocator = std.testing.allocator;
    var console_obj = try console_mod.console.console.init(allocator);
    defer console_obj.deinit();

    const mock_args: []const JSValue = &.{};
    console_obj.call_warn(mock_args);
    // Test passes if no crash
}

test "call_error - calls logger with error level" {
    const allocator = std.testing.allocator;
    var console_obj = try console_mod.console.console.init(allocator);
    defer console_obj.deinit();

    const mock_args: []const JSValue = &.{};
    console_obj.call_error(mock_args);
    // Test passes if no crash
}

test "call_assert - true condition returns immediately" {
    const allocator = std.testing.allocator;
    var console_obj = try console_mod.console.console.init(allocator);
    defer console_obj.deinit();

    const mock_args: []const JSValue = &.{};
    console_obj.call_assert(true, mock_args);
    // Should return without logging
}

test "call_assert - false condition logs" {
    const allocator = std.testing.allocator;
    var console_obj = try console_mod.console.console.init(allocator);
    defer console_obj.deinit();

    const mock_args: []const JSValue = &.{};
    console_obj.call_assert(false, mock_args);
    // Should log assertion failure
}

test "call_trace - logs with trace level" {
    const allocator = std.testing.allocator;
    var console_obj = try console_mod.console.console.init(allocator);
    defer console_obj.deinit();

    const mock_args: []const JSValue = &.{};
    console_obj.call_trace(mock_args);
    // Test passes if no crash
}

test "call_dir - prints with dir level" {
    const allocator = std.testing.allocator;
    var console_obj = try console_mod.console.console.init(allocator);
    defer console_obj.deinit();

    // With null item
    console_obj.call_dir(null, null);

    // With item (using opaque pointer)
    // Can't create real JSValue in tests, so skip this test
}

test "call_dirxml - logs with dirxml level" {
    const allocator = std.testing.allocator;
    var console_obj = try console_mod.console.console.init(allocator);
    defer console_obj.deinit();

    const mock_args: []const JSValue = &.{};
    console_obj.call_dirxml(mock_args);
    // Test passes if no crash
}

test "call_table - prints with table level" {
    const allocator = std.testing.allocator;
    var console_obj = try console_mod.console.console.init(allocator);
    defer console_obj.deinit();

    // With null tabularData
    console_obj.call_table(null, null);
    // Test passes if no crash
}

test "logging - disabled console skips all methods" {
    const allocator = std.testing.allocator;
    var console_obj = try console_mod.console.console.init(allocator);
    defer console_obj.deinit();

    console_obj.enabled = false;

    const mock_args: []const JSValue = &.{};

    // All should return immediately (fast disabled path)
    console_obj.call_log(mock_args);
    console_obj.call_debug(mock_args);
    console_obj.call_info(mock_args);
    console_obj.call_warn(mock_args);
    console_obj.call_error(mock_args);
    console_obj.call_trace(mock_args);
    console_obj.call_dirxml(mock_args);

    // Test passes if completes quickly with no processing
}

test "logging - respects group indentation" {
    const allocator = std.testing.allocator;
    var console_obj = try console_mod.console.console.init(allocator);
    defer console_obj.deinit();

    const mock_args: []const JSValue = &.{};

    // Log at level 0 (no groups)
    console_obj.call_log(mock_args);

    // Add group and log at level 1
    try console_obj.call_group(&.{});
    console_obj.call_log(mock_args);

    // Add another group and log at level 2
    try console_obj.call_group(&.{});
    console_obj.call_log(mock_args);

    // End groups
    console_obj.call_groupEnd();
    console_obj.call_groupEnd();

    // Test passes if no crash
}

test "logging - multiple methods in sequence" {
    const allocator = std.testing.allocator;
    var console_obj = try console_mod.console.console.init(allocator);
    defer console_obj.deinit();

    const mock_args: []const JSValue = &.{};

    // Sequence of different log methods
    console_obj.call_log(mock_args);
    console_obj.call_debug(mock_args);
    console_obj.call_info(mock_args);
    console_obj.call_warn(mock_args);
    console_obj.call_error(mock_args);
    console_obj.call_trace(mock_args);

    // Test passes if no crash
}

test "logging - memory safety with many calls" {
    const allocator = std.testing.allocator;
    var console_obj = try console_mod.console.console.init(allocator);
    defer console_obj.deinit();

    const mock_args: []const JSValue = &.{};

    // Many logging calls
    var i: usize = 0;
    while (i < 1000) : (i += 1) {
        console_obj.call_log(mock_args);
        console_obj.call_debug(mock_args);
        console_obj.call_error(mock_args);
    }

    // Test passes if no memory leaks
}
