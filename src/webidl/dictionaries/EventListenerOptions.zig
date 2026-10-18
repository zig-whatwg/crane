//! WebIDL dictionary: EventListenerOptions
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");

pub const EventListenerOptions = struct {
    capture: ?bool = null,

    /// Optional members' IDL default values: a member the value leaves
    /// unset is written with its default when converted to script.
    pub const member_defaults = .{
        .{ "capture", .{ .boolean = false } },
    };
};
