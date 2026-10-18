//! WebIDL dictionary: EventInit
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");

pub const EventInit = struct {
    bubbles: ?bool = null,
    cancelable: ?bool = null,
    composed: ?bool = null,

    /// Optional members' IDL default values: a member the value leaves
    /// unset is written with its default when converted to script.
    pub const member_defaults = .{
        .{ "bubbles", .{ .boolean = false } },
        .{ "cancelable", .{ .boolean = false } },
        .{ "composed", .{ .boolean = false } },
    };
};
