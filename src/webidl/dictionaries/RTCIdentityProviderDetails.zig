//! WebIDL dictionary: RTCIdentityProviderDetails
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");

pub const RTCIdentityProviderDetails = struct {
    domain: runtime.DOMString,
    protocol: ?runtime.DOMString = null,

    /// Optional members' IDL default values: a member the value leaves
    /// unset is written with its default when converted to script.
    pub const member_defaults = .{
        .{ "protocol", .{ .string = "default" } },
    };
};
