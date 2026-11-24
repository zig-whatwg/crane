//! WebIDL typedef: TogglePopoverOptionsOrBoolean
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const webidl = @import("webidl");
const typedefs = @import("root.zig");
const dictionaries = @import("dictionaries");

pub const TogglePopoverOptionsOrBoolean = union(enum) {
    toggle_popover_options: dictionaries.TogglePopoverOptions,
    boolean: bool,

    /// What each field's member type is, for the binding's union conversion
    /// (WebIDL 3.2.25; webidl.union_arms).
    pub const arms = [_]webidl.UnionArm{
        .{ .field = "toggle_popover_options", .kind = .dictionary },
        .{ .field = "boolean", .kind = .boolean },
    };
};
