//! WebIDL dictionary: MediaStreamTrackProcessorInit
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const typedefs = @import("typedefs");

pub const MediaStreamTrackProcessorInit = struct {
    track: typedefs.MediaStreamTrackOrHandle,
    maxBufferSize: ?u16 = null,

    /// [EnforceRange] members: converted with that branch of ConvertToInt.
    pub const enforce_range_members = .{"maxBufferSize"};
};
