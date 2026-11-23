//! WebIDL dictionary: InputDeviceCapabilitiesInit
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");

pub const InputDeviceCapabilitiesInit = struct {
    /// A WebIDL dictionary (the binding's dictionary rules read this marker).
    pub const webidl_dictionary = true;
    firesTouchEvents: ?bool = null,
    pointerMovementScrolls: ?bool = null,

    /// Optional members' IDL default values: a member the value leaves
    /// unset is written with its default when converted to script.
    pub const member_defaults = .{
        .{ "firesTouchEvents", .{ .boolean = false } },
        .{ "pointerMovementScrolls", .{ .boolean = false } },
    };
};
