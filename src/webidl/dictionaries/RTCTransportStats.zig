//! WebIDL dictionary: RTCTransportStats
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const RTCStats = @import("RTCStats.zig").RTCStats;

pub const RTCTransportStats = struct {
    // Inherited from RTCStats
    base: RTCStats,

    packetsSent: ?u64 = null,
    packetsReceived: ?u64 = null,
    bytesSent: ?u64 = null,
    bytesReceived: ?u64 = null,
    iceRole: ?anyopaque = null,
    iceLocalUsernameFragment: ?runtime.DOMString = null,
    dtlsState: anyopaque,
    iceState: ?anyopaque = null,
    selectedCandidatePairId: ?runtime.DOMString = null,
    localCertificateId: ?runtime.DOMString = null,
    remoteCertificateId: ?runtime.DOMString = null,
    tlsVersion: ?runtime.DOMString = null,
    dtlsCipher: ?runtime.DOMString = null,
    dtlsRole: ?anyopaque = null,
    srtpCipher: ?runtime.DOMString = null,
    selectedCandidatePairChanges: ?u32 = null,
    ccfbMessagesSent: ?u32 = null,
    ccfbMessagesReceived: ?u32 = null,
};
