//! WebIDL dictionary: RTCOutboundRtpStreamStats
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const v8 = @import("v8");
const typedefs = @import("typedefs");
const enums = @import("enums");
const RTCSentRtpStreamStats = @import("RTCSentRtpStreamStats.zig").RTCSentRtpStreamStats;

pub const RTCOutboundRtpStreamStats = struct {
    // Inherited from RTCSentRtpStreamStats
    base: RTCSentRtpStreamStats,

    mid: ?runtime.DOMString = null,
    mediaSourceId: ?runtime.DOMString = null,
    remoteId: ?runtime.DOMString = null,
    rid: ?runtime.DOMString = null,
    encodingIndex: ?u32 = null,
    headerBytesSent: ?u64 = null,
    retransmittedPacketsSent: ?u64 = null,
    retransmittedBytesSent: ?u64 = null,
    rtxSsrc: ?u32 = null,
    targetBitrate: ?f64 = null,
    totalEncodedBytesTarget: ?u64 = null,
    frameWidth: ?u32 = null,
    frameHeight: ?u32 = null,
    framesPerSecond: ?f64 = null,
    framesSent: ?u32 = null,
    hugeFramesSent: ?u32 = null,
    framesEncoded: ?u32 = null,
    keyFramesEncoded: ?u32 = null,
    qpSum: ?u64 = null,
    psnrSum: ?[]const struct { key: runtime.DOMString, value: f64 } = null,
    psnrMeasurements: ?u64 = null,
    totalEncodeTime: ?f64 = null,
    totalPacketSendDelay: ?f64 = null,
    qualityLimitationReason: ?enums.RTCQualityLimitationReason = null,
    qualityLimitationDurations: ?[]const struct { key: runtime.DOMString, value: f64 } = null,
    qualityLimitationResolutionChanges: ?u32 = null,
    nackCount: ?u32 = null,
    firCount: ?u32 = null,
    pliCount: ?u32 = null,
    encoderImplementation: ?runtime.DOMString = null,
    powerEfficientEncoder: ?bool = null,
    active: ?bool = null,
    scalabilityMode: ?runtime.DOMString = null,
    packetsSentWithEct1: ?u64 = null,
};
