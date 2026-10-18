//! WebIDL dictionary: PositionOptions
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");

pub const PositionOptions = struct {
    enableHighAccuracy: ?bool = null,
    timeout: ?u32 = null,
    maximumAge: ?u32 = null,

    /// Optional members' IDL default values: a member the value leaves
    /// unset is written with its default when converted to script.
    pub const member_defaults = .{
        .{ "enableHighAccuracy", .{ .boolean = false } },
        .{ "timeout", .{ .number = 4294967295 } },
        .{ "maximumAge", .{ .number = 0 } },
    };

    /// [Clamp] members: converted with that branch of ConvertToInt.
    pub const clamp_members = .{ "timeout", "maximumAge" };
};
