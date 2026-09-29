//! WebIDL dictionary: AudioTimestamp
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const typedefs = @import("typedefs");

pub const AudioTimestamp = struct {
    contextTime: ?f64 = null,
    performanceTime: ?typedefs.DOMHighResTimeStamp = null,

    /// WebIDL `double` and `float` members (not `unrestricted`): NaN and the
    /// infinities throw a TypeError when the dictionary is converted.
    pub const restricted_members = .{ "contextTime", "performanceTime" };
};
