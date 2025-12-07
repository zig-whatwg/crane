//! WebIDL dictionary: RTCConfiguration
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const v8 = @import("v8");
const typedefs = @import("typedefs");
const enums = @import("enums");
const RTCIceServer = @import("RTCIceServer.zig").RTCIceServer;

pub const RTCConfiguration = struct {
    iceServers: ?[]const RTCIceServer = null,
    iceTransportPolicy: ?enums.RTCIceTransportPolicy = null,
    bundlePolicy: ?enums.RTCBundlePolicy = null,
    rtcpMuxPolicy: ?enums.RTCRtcpMuxPolicy = null,
    certificates: ?[]const *runtime.Instance = null,
    iceCandidatePoolSize: ?u8 = null,
    peerIdentity: ?runtime.DOMString = null,
};
