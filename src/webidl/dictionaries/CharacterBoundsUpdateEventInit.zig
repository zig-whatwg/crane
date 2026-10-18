//! WebIDL dictionary: CharacterBoundsUpdateEventInit
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const EventInit = @import("EventInit.zig").EventInit;

pub const CharacterBoundsUpdateEventInit = struct {
    // Inherited from EventInit
    base: EventInit,

    rangeStart: ?u32 = null,
    rangeEnd: ?u32 = null,

    /// Optional members' IDL default values: a member the value leaves
    /// unset is written with its default when converted to script.
    pub const member_defaults = .{
        .{ "rangeStart", .{ .number = 0 } },
        .{ "rangeEnd", .{ .number = 0 } },
    };
};
