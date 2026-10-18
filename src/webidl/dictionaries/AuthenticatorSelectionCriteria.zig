//! WebIDL dictionary: AuthenticatorSelectionCriteria
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");

pub const AuthenticatorSelectionCriteria = struct {
    authenticatorAttachment: ?runtime.DOMString = null,
    residentKey: ?runtime.DOMString = null,
    requireResidentKey: ?bool = null,
    userVerification: ?runtime.DOMString = null,

    /// Optional members' IDL default values: a member the value leaves
    /// unset is written with its default when converted to script.
    pub const member_defaults = .{
        .{ "requireResidentKey", .{ .boolean = false } },
        .{ "userVerification", .{ .string = "preferred" } },
    };
};
