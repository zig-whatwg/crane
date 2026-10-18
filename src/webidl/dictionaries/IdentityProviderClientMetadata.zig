//! WebIDL dictionary: IdentityProviderClientMetadata
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");

pub const IdentityProviderClientMetadata = struct {
    privacy_policy_url: ?runtime.USVString = null,
    terms_of_service_url: ?runtime.USVString = null,
    client_is_third_party_to_top_frame_origin: ?bool = null,

    /// Optional members' IDL default values: a member the value leaves
    /// unset is written with its default when converted to script.
    pub const member_defaults = .{
        .{ "client_is_third_party_to_top_frame_origin", .{ .boolean = false } },
    };
};
