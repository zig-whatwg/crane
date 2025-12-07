//! WebIDL dictionary: ProfilerInitOptions
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const typedefs = @import("typedefs");

pub const ProfilerInitOptions = struct {
    sampleInterval: typedefs.DOMHighResTimeStamp,
    maxBufferSize: u32,
};
