//! WebIDL dictionary: RTCDataChannelStats
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const v8 = @import("v8");
const typedefs = @import("typedefs");
const enums = @import("enums");
const RTCStats = @import("RTCStats.zig").RTCStats;

pub const RTCDataChannelStats = struct {
    // Inherited from RTCStats
    base: RTCStats,

    label: ?runtime.DOMString = null,
    protocol: ?runtime.DOMString = null,
    dataChannelIdentifier: ?u16 = null,
    state: enums.RTCDataChannelState,
    messagesSent: ?u32 = null,
    bytesSent: ?u64 = null,
    messagesReceived: ?u32 = null,
    bytesReceived: ?u64 = null,
};
