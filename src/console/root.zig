//! WHATWG Console Standard Implementation
//!
//! Spec: https://console.spec.whatwg.org/
//!
//! This library implements the console namespace object as defined by the
//! WHATWG Console Standard. The console provides logging, timing, counting,
//! and grouping operations for debugging and development.
//!
//! `printer` is the Standard's Formatter and Printer: what the console
//! namespace's impl prints for `console.log` and its siblings, and what the
//! browser console (tools/repl.zig) prints for a result - one printer for both.

const std = @import("std");

// Re-export generated console namespace (from webidl/namespaces/console.zig)
pub const console = @import("namespaces").console;

/// The Console Standard's Formatter and Printer (printer.zig).
pub const printer = @import("printer.zig");

test {
    std.testing.refAllDecls(@This());
}
