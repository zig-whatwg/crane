//! Type Definition Tests
//!
//! Tests for Console supporting types (Group, LogLevel, JSValue, JSObject).

const std = @import("std");
const console_mod = @import("console");
const types = console.types;
const infra = @import("infra");

const Group = types.Group;
const LogLevel = types.LogLevel;

test "Group - init expanded" {
    const allocator = std.testing.allocator;
    const label = try infra.string.utf8ToUtf16(allocator, "Test Group");
    defer allocator.free(label);

    const group = Group.init(label);
    try std.testing.expect(group.label != null);
    try std.testing.expect(!group.collapsed);
}

test "Group - init collapsed" {
    const allocator = std.testing.allocator;
    const label = try infra.string.utf8ToUtf16(allocator, "Test Group");
    defer allocator.free(label);

    const group = Group.initCollapsed(label);
    try std.testing.expect(group.label != null);
    try std.testing.expect(group.collapsed);
}

test "Group - init without label" {
    const group = Group.init(null);
    try std.testing.expect(group.label == null);
    try std.testing.expect(!group.collapsed);
}

test "LogLevel - all values exist" {
    // Logging methods
    _ = LogLevel.assert_level;
    _ = LogLevel.clear;
    _ = LogLevel.debug;
    _ = LogLevel.error_level;
    _ = LogLevel.info;
    _ = LogLevel.log;
    _ = LogLevel.warn;
    _ = LogLevel.dir;
    _ = LogLevel.dirxml;
    _ = LogLevel.trace;

    // Counting methods
    _ = LogLevel.count;
    _ = LogLevel.count_reset;

    // Grouping methods
    _ = LogLevel.group;
    _ = LogLevel.group_collapsed;

    // Timing methods
    _ = LogLevel.time;
    _ = LogLevel.time_log;
    _ = LogLevel.time_end;

    // Table method
    _ = LogLevel.table;
}

test "LogLevel - severity groupings" {
    // Log severity
    try std.testing.expectEqual(LogLevel.Severity.log, LogLevel.log.getSeverity());
    try std.testing.expectEqual(LogLevel.Severity.log, LogLevel.debug.getSeverity());
    try std.testing.expectEqual(LogLevel.Severity.log, LogLevel.trace.getSeverity());
    try std.testing.expectEqual(LogLevel.Severity.log, LogLevel.dir.getSeverity());
    try std.testing.expectEqual(LogLevel.Severity.log, LogLevel.dirxml.getSeverity());
    try std.testing.expectEqual(LogLevel.Severity.log, LogLevel.group.getSeverity());
    try std.testing.expectEqual(LogLevel.Severity.log, LogLevel.group_collapsed.getSeverity());
    try std.testing.expectEqual(LogLevel.Severity.log, LogLevel.time_log.getSeverity());

    // Info severity
    try std.testing.expectEqual(LogLevel.Severity.info, LogLevel.info.getSeverity());
    try std.testing.expectEqual(LogLevel.Severity.info, LogLevel.count.getSeverity());
    try std.testing.expectEqual(LogLevel.Severity.info, LogLevel.time_end.getSeverity());

    // Warn severity
    try std.testing.expectEqual(LogLevel.Severity.warn, LogLevel.warn.getSeverity());
    try std.testing.expectEqual(LogLevel.Severity.warn, LogLevel.count_reset.getSeverity());

    // Error severity
    try std.testing.expectEqual(LogLevel.Severity.@"error", LogLevel.error_level.getSeverity());
    try std.testing.expectEqual(LogLevel.Severity.@"error", LogLevel.assert_level.getSeverity());
}

test "Console - init and deinit" {
    const allocator = std.testing.allocator;
    var console_obj = try console_mod.console.console.init(allocator);
    defer console_obj.deinit();

    // Verify state is initialized empty
    try std.testing.expect(console_obj.count_map.isEmpty());
    try std.testing.expect(console_obj.timer_table.isEmpty());
    try std.testing.expect(console_obj.group_stack.isEmpty());
}

test "Console - multiple instances" {
    const allocator = std.testing.allocator;

    var console1 = try console_mod.console.console.init(allocator);
    defer console1.deinit();

    var console2 = try console_mod.console.console.init(allocator);
    defer console2.deinit();

    // Verify state isolation
    try std.testing.expect(console1.count_map.isEmpty());
    try std.testing.expect(console2.count_map.isEmpty());
}
