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

    /// WebIDL `double` and `float` members (not `unrestricted`): NaN and the
    /// infinities throw a TypeError when the dictionary is converted.
    pub const restricted_members = .{ "timestamp", "audioLevel" };
};
