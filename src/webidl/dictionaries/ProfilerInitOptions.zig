//! WebIDL dictionary: ProfilerInitOptions
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const typedefs = @import("typedefs");

pub const ProfilerInitOptions = struct {
    sampleInterval: typedefs.DOMHighResTimeStamp,
    maxBufferSize: u32,

    /// WebIDL `double` and `float` members (not `unrestricted`): NaN and the
    /// infinities throw a TypeError when the dictionary is converted.
    pub const restricted_members = .{"sampleInterval"};
};
