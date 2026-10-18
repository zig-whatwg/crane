//! WebIDL dictionary: RTCIdentityProviderOptions
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");

pub const RTCIdentityProviderOptions = struct {
    protocol: ?runtime.DOMString = null,
    usernameHint: ?runtime.DOMString = null,
    peerIdentity: ?runtime.DOMString = null,

    /// Optional members' IDL default values: a member the value leaves
    /// unset is written with its default when converted to script.
    pub const member_defaults = .{
        .{ "protocol", .{ .string = "default" } },
    };
};
