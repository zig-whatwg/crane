//! WebIDL dictionary: FocusOptions
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");

pub const FocusOptions = struct {
    preventScroll: ?bool = null,
    focusVisible: ?bool = null,

    /// Optional members' IDL default values: a member the value leaves
    /// unset is written with its default when converted to script.
    pub const member_defaults = .{
        .{ "preventScroll", .{ .boolean = false } },
    };
};
