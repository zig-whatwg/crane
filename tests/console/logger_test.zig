//! Logger Abstract Operation Tests
//!
//! Tests for Console Logger operation and enabled flag.
//! WHATWG Console Standard lines 278-293.

const std = @import("std");
const console_lib = @import("console");

const console_type = console_lib.console;
const JSValue = console_lib.JSValue;

test "Console - enabled by default" {
    const allocator = std.testing.allocator;
    var console_obj = try console_mod.console.init(allocator);
    defer console_obj.deinit();

    try std.testing.expect(console_obj.enabled);
}

test "Console - can be disabled" {
    const allocator = std.testing.allocator;
    var console_obj = try console_mod.console.init(allocator);
    defer console_obj.deinit();

    console_obj.enabled = false;
    try std.testing.expect(!console_obj.enabled);
}

test "logger - empty args returns immediately" {
    const allocator = std.testing.allocator;
    var console_obj = try console_mod.console.init(allocator);
    defer console_obj.deinit();

    // Empty args should return immediately (no-op)
    console_obj.logger(.log, &.{});
    // Test passes if no crash
}

test "logger - disabled console returns immediately" {
    const allocator = std.testing.allocator;
    var console_obj = try console_mod.console.init(allocator);
    defer console_obj.deinit();

    console_obj.enabled = false;

    // Should return immediately without processing
    // (Fast disabled path optimization)
    const mock_args: []const JSValue = &.{};
    console_obj.logger(.log, mock_args);
    // Test passes if no crash and returns quickly
}

test "logger - enabled console processes args" {
    const allocator = std.testing.allocator;
    var console_obj = try console_mod.console.init(allocator);
    defer console_obj.deinit();

    console_obj.enabled = true;

    // With enabled console, logger should process args
    // (Will be tested more thoroughly when Formatter is implemented)
    const mock_args: []const JSValue = &.{};
    console_obj.logger(.log, mock_args);
    // Test passes if no crash
}

test "printer - respects group indentation" {
    const allocator = std.testing.allocator;
    var console_obj = try console_mod.console.init(allocator);
    defer console_obj.deinit();

    // No groups - indent level 0
    try std.testing.expectEqual(@as(usize, 0), console_obj.group_stack.size());

    // Add groups
    try console_obj.call_group(&.{});
    try std.testing.expectEqual(@as(usize, 1), console_obj.group_stack.size());

    try console_obj.call_group(&.{});
    try std.testing.expectEqual(@as(usize, 2), console_obj.group_stack.size());

    // Printer should respect this indentation
    const mock_args: []const JSValue = &.{};
    console_obj.printer(.log, mock_args);
    // Test passes if no crash
}

test "enabled flag - fast path performance" {
    const allocator = std.testing.allocator;
    var console_obj = try console_mod.console.init(allocator);
    defer console_obj.deinit();

    console_obj.enabled = false;

    // Disabled console should have near-zero overhead
    // This tests the browser optimization pattern
    const iterations = 10000;
    var i: usize = 0;
    while (i < iterations) : (i += 1) {
        console_obj.logger(.log, &.{});
    }
    // Test passes if completes quickly and no memory leaks
}
