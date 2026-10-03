//! WebIDL dictionary: RTCCertificateExpiration
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");

pub const RTCCertificateExpiration = struct {
    expires: ?u64 = null,

    /// [EnforceRange] members: converted with that branch of ConvertToInt.
    pub const enforce_range_members = .{"expires"};
};
