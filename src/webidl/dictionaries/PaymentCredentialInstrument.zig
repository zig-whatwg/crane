//! WebIDL dictionary: PaymentCredentialInstrument
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");

pub const PaymentCredentialInstrument = struct {
    /// A WebIDL dictionary (the binding's dictionary rules read this marker).
    pub const webidl_dictionary = true;
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
