//! WHATWG Console Standard Implementation
//!
//! Spec: https://console.spec.whatwg.org/
//!
//! This library implements the console namespace object as defined by the
//! WHATWG Console Standard. The console provides logging, timing, counting,
//! and grouping operations for debugging and development.

const std = @import("std");

// TODO: Re-implement console interfaces using the runtime system
// Re-export generated console module (from webidl/generated/console/console.zig)
// pub const console = @import("console");

// Re-export supporting types (from webidl/src/console/types.zig)
// pub const types = @import("types");
// pub const Group = types.Group;
// pub const LogLevel = types.LogLevel;

test {
    std.testing.refAllDecls(@This());
}
