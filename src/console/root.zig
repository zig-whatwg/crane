//! WHATWG Console Standard Implementation
//!
//! Spec: https://console.spec.whatwg.org/
//!
//! This library implements the console namespace object as defined by the
//! WHATWG Console Standard. The console provides logging, timing, counting,
//! and grouping operations for debugging and development.

const std = @import("std");

// Re-export generated console module (from interfaces/console/console.zig)
pub const console = @import("console");
pub const Console = console.Console;

// Re-export supporting types (from zoop_src/console/types.zig)
pub const types = @import("types");
pub const Group = types.Group;
pub const LogLevel = types.LogLevel;

test {
    std.testing.refAllDecls(@This());
}
