//! WebIDL dictionary: RTCRtpContributingSource
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");

pub const RTCRtpContributingSource = struct {
    timestamp: *const anyopaque,
    source: u32,
    audioLevel: ?f64 = null,
    rtpTimestamp: u32,
};
