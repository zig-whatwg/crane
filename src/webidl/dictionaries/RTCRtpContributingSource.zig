//! WebIDL dictionary: RTCRtpContributingSource
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const typedefs = @import("typedefs");

pub const RTCRtpContributingSource = struct {
    timestamp: typedefs.DOMHighResTimeStamp,
    source: u32,
    audioLevel: ?f64 = null,
    rtpTimestamp: u32,
};
