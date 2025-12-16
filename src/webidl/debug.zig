//! WebIDL Debug Logging
//!
//! Compile-time configurable debug output for WebIDL implementation.
//! Debug output is completely eliminated when not enabled.
//!
//! Usage:
//! ```zig
//! const debug = @import("debug.zig");
//! debug.print("Interface: {s}\n", .{name});
//! ```
//!
//! Enable with: `zig build -Ddebug=true -Ddebug-scope=webidl`

const std = @import("std");
const debug_options = @import("debug_options");

/// Check if WebIDL debug output is enabled at compile time
pub const enabled: bool = blk: {
    if (!debug_options.debug_enabled) break :blk false;
    const filter = debug_options.debug_scope;
    if (filter.len == 0) break :blk true;
    var iter = std.mem.splitSequence(u8, filter, ",");
    while (iter.next()) |scope| {
        const trimmed = std.mem.trim(u8, scope, " ");
        if (std.mem.eql(u8, trimmed, "webidl")) break :blk true;
    }
    break :blk false;
};

/// Print debug message if WebIDL scope is enabled
pub fn print(comptime fmt: []const u8, args: anytype) void {
    if (comptime enabled) {
        std.debug.print("[webidl] " ++ fmt, args);
    }
}

/// Print without prefix
pub fn printRaw(comptime fmt: []const u8, args: anytype) void {
    if (comptime enabled) {
        std.debug.print(fmt, args);
    }
}
