//! V8 Debug Logging
//!
//! Compile-time configurable debug output for V8 bindings.
//! Debug output is completely eliminated when not enabled.
//!
//! Usage:
//! ```zig
//! const debug = @import("debug.zig");
//! debug.print("V8 context: {*}\n", .{ctx});
//! ```
//!
//! Enable with: `zig build -Ddebug=true -Ddebug-scope=v8`

const std = @import("std");
const debug_options = @import("debug_options");

/// Check if V8 debug output is enabled at compile time
pub const enabled: bool = blk: {
    if (!debug_options.debug_enabled) break :blk false;
    const filter = debug_options.debug_scope;
    if (filter.len == 0) break :blk true; // No filter = all scopes enabled
    // Check if v8 is in the filter
    var iter = std.mem.splitSequence(u8, filter, ",");
    while (iter.next()) |scope| {
        const trimmed = std.mem.trim(u8, scope, " ");
        if (std.mem.eql(u8, trimmed, "v8")) break :blk true;
    }
    break :blk false;
};

/// Print debug message if V8 scope is enabled
pub fn print(comptime fmt: []const u8, args: anytype) void {
    if (comptime enabled) {
        std.debug.print("[v8] " ++ fmt, args);
    }
}

/// Print without prefix
pub fn printRaw(comptime fmt: []const u8, args: anytype) void {
    if (comptime enabled) {
        std.debug.print(fmt, args);
    }
}
