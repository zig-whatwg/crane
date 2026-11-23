//! WebIDL dictionary: RTCCertificateStats
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const RTCStats = @import("RTCStats.zig").RTCStats;

pub const RTCCertificateStats = struct {
    /// A WebIDL dictionary (the binding's dictionary rules read this marker).
    pub const webidl_dictionary = true;
    // Inherited from RTCStats
    base: RTCStats,

    fingerprint: runtime.DOMString,
    fingerprintAlgorithm: runtime.DOMString,
    base64Certificate: runtime.DOMString,
    issuerCertificateId: ?runtime.DOMString = null,
};
