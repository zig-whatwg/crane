//! WebIDL dictionary: RTCIceGatherOptions
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const v8 = @import("v8");
const enums = @import("enums");
const RTCIceServer = @import("RTCIceServer.zig").RTCIceServer;

pub const RTCIceGatherOptions = struct {
    gatherPolicy: ?enums.RTCIceTransportPolicy = null,
    iceServers: ?[]const RTCIceServer = null,
};
