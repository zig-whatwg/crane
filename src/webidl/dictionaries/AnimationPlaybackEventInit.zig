//! WebIDL dictionary: AnimationPlaybackEventInit
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const typedefs = @import("typedefs");
const EventInit = @import("EventInit.zig").EventInit;

pub const AnimationPlaybackEventInit = struct {
    // Inherited from EventInit
    base: EventInit,

    currentTime: ?typedefs.CSSNumberish = null,
    timelineTime: ?typedefs.CSSNumberish = null,

    /// Optional members' IDL default values: a member the value leaves
    /// unset is written with its default when converted to script.
    pub const member_defaults = .{
        .{ "currentTime", .null },
        .{ "timelineTime", .null },
    };

    /// Optional members whose IDL type is nullable: a present null is the
    /// value null. Any other member's present null converts by its type.
    pub const nullable_members = .{ "currentTime", "timelineTime" };
};
