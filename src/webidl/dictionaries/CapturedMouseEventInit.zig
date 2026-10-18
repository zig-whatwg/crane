//! WebIDL dictionary: CapturedMouseEventInit
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const EventInit = @import("EventInit.zig").EventInit;

pub const CapturedMouseEventInit = struct {
    // Inherited from EventInit
    base: EventInit,

    surfaceX: ?i32 = null,
    surfaceY: ?i32 = null,

    /// Optional members' IDL default values: a member the value leaves
    /// unset is written with its default when converted to script.
    pub const member_defaults = .{
        .{ "surfaceX", .{ .number = -1 } },
        .{ "surfaceY", .{ .number = -1 } },
    };
};
