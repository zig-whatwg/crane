//! WebIDL dictionary: OTPCredentialRequestOptions
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const enums = @import("enums");

pub const OTPCredentialRequestOptions = struct {
    transport: ?[]const enums.OTPCredentialTransportType = null,

    /// Optional members' IDL default values: a member the value leaves
    /// unset is written with its default when converted to script.
    pub const member_defaults = .{
        .{ "transport", .empty_sequence },
    };
};
