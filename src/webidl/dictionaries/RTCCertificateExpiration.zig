//! WebIDL dictionary: RTCCertificateExpiration
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");

pub const RTCCertificateExpiration = struct {
    /// A WebIDL dictionary (the binding's dictionary rules read this marker).
    pub const webidl_dictionary = true;
    expires: ?u64 = null,

    /// [EnforceRange] members: converted with that branch of ConvertToInt.
    pub const enforce_range_members = .{"expires"};
};
