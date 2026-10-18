//! WebIDL dictionary: PaymentCredentialInstrument
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");

pub const PaymentCredentialInstrument = struct {
    displayName: runtime.USVString,
    icon: runtime.USVString,
    iconMustBeShown: ?bool = null,
    details: ?runtime.USVString = null,

    /// Optional members' IDL default values: a member the value leaves
    /// unset is written with its default when converted to script.
    pub const member_defaults = .{
        .{ "iconMustBeShown", .{ .boolean = true } },
    };
};
