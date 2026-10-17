//! WebIDL dictionary: StartViewTransitionOptions
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const callbacks = @import("callbacks");

pub const StartViewTransitionOptions = struct {
    update: ?callbacks.ViewTransitionUpdateCallback = null,
    types: ?[]const runtime.DOMString = null,

    /// Optional members whose IDL type is nullable: a present null is the
    /// value null. Any other member's present null converts by its type.
    pub const nullable_members = .{ "update", "types" };
};
