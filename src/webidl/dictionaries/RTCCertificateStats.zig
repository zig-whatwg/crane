//! WebIDL dictionary: RTCCertificateStats
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const RTCStats = @import("RTCStats.zig").RTCStats;

pub const RTCCertificateStats = struct {
    // Inherited from RTCStats
    base: RTCStats,

    fingerprint: runtime.DOMString,
    fingerprintAlgorithm: runtime.DOMString,
    base64Certificate: runtime.DOMString,
    issuerCertificateId: ?runtime.DOMString = null,
};
