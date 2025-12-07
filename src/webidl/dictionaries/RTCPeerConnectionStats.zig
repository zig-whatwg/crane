//! WebIDL dictionary: RTCPeerConnectionStats
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const RTCStats = @import("RTCStats.zig").RTCStats;

pub const RTCPeerConnectionStats = struct {
    // Inherited from RTCStats
    base: RTCStats,

    dataChannelsOpened: ?u32 = null,
    dataChannelsClosed: ?u32 = null,
};
