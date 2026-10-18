//! WebIDL dictionary: InputDeviceCapabilitiesInit
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");

pub const InputDeviceCapabilitiesInit = struct {
    firesTouchEvents: ?bool = null,
    pointerMovementScrolls: ?bool = null,

    /// Optional members' IDL default values: a member the value leaves
    /// unset is written with its default when converted to script.
    pub const member_defaults = .{
        .{ "firesTouchEvents", .{ .boolean = false } },
        .{ "pointerMovementScrolls", .{ .boolean = false } },
    };
};
