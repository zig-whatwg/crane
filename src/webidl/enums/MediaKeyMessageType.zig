//! WebIDL enum: MediaKeyMessageType
//!
//! This file is AUTO-GENERATED. Do not edit manually.

pub const MediaKeyMessageType = enum {
    _license_request_,
    _license_renewal_,
    _license_release_,
    _individualization_request_,

    /// Each variant's value exactly as the IDL spells it, by variant index.
    pub const idl_values = [_][]const u8{ "license-request", "license-renewal", "license-release", "individualization-request" };
};
