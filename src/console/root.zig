//! WHATWG Console Standard Implementation
//!
//! Spec: https://console.spec.whatwg.org/
//!
//! This library implements the console namespace object as defined by the
//! WHATWG Console Standard. The console provides logging, timing, counting,
//! and grouping operations for debugging and development.

const std = @import("std");

// Re-export generated console namespace (from webidl/interfaces/console.zig)
pub const console = @import("interfaces").console;

test {
    std.testing.refAllDecls(@This());
}
