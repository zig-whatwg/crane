//! WebIDL dictionary: IdentityProviderClientMetadata
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const v8 = @import("v8");

pub const IdentityProviderClientMetadata = struct {
    privacy_policy_url: ?runtime.USVString = null,
    terms_of_service_url: ?runtime.USVString = null,
    client_is_third_party_to_top_frame_origin: ?bool = null,
};
