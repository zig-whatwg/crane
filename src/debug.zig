//! Debug Logging Module
//!
//! Provides compile-time configurable debug output that is completely
//! eliminated from release builds. Debug output only appears when
//! compiled with `-Ddebug=true`.
//!
//! ## Usage
//!
//! For modules with their own debug.zig (the engine adapter, webidl):
//! ```zig
//! const debug = @import("debug.zig");
//! debug.print("Message: {s}\n", .{value});
//! ```
//!
//! For other modules, import from root:
//! ```zig
//! const debug = @import("root").debug;
//! debug.scoped(.dom).print("Node: {d}\n", .{node_type});
//! ```
//!
//! ## Build Options
//!
//! - `zig build -Ddebug=true` - Enable all debug output
//! - `zig build -Ddebug=true -Ddebug-scope=webidl` - Only show webidl debug output
//! - `zig build -Ddebug=true -Ddebug-scope=webidl,dom` - Show webidl and dom output
//!
//! ## Available Scopes
//!
//! webidl, dom, css, html, url, encoding, streams, fetch, runtime, gc, wpt, general;
//! and the engine adapter's own, which its debug.zig matches and its build
//! file names (`facts.debug_scope`: `zig build --help` lists it under
//! -Ddebug-scope).

const std = @import("std");
const debug_options = @import("debug_options");

/// Debug scopes for filtering output
pub const Scope = enum {
    webidl,
    dom,
    css,
    html,
    url,
    encoding,
    streams,
    fetch,
    runtime,
    gc,
    wpt,
    general,
};

/// Check if debug output is enabled at compile time
pub const enabled: bool = debug_options.debug_enabled;

/// Check if a specific scope is enabled
pub fn scopeEnabled(comptime scope: Scope) bool {
    if (!enabled) return false;
    const filter = debug_options.debug_scope;
    if (filter.len == 0) return true;
    const scope_name = @tagName(scope);
    var iter = std.mem.splitSequence(u8, filter, ",");
    while (iter.next()) |allowed| {
        const trimmed = std.mem.trim(u8, allowed, " ");
        if (std.mem.eql(u8, trimmed, scope_name)) return true;
    }
    return false;
}

/// Scoped debug logger
pub fn scoped(comptime scope: Scope) type {
    return struct {
        pub fn print(comptime fmt: []const u8, args: anytype) void {
            if (comptime scopeEnabled(scope)) {
                std.debug.print("[" ++ @tagName(scope) ++ "] " ++ fmt, args);
            }
        }
    };
}

/// Print debug message (general scope)
pub fn print(comptime fmt: []const u8, args: anytype) void {
    if (comptime scopeEnabled(.general)) {
        std.debug.print("[debug] " ++ fmt, args);
    }
}
