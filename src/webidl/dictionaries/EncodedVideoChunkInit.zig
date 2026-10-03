//! WebIDL dictionary: EncodedVideoChunkInit
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const typedefs = @import("typedefs");
const enums = @import("enums");

pub const EncodedVideoChunkInit = struct {
    type: enums.EncodedVideoChunkType,
    timestamp: i64,
    duration: ?u64 = null,
    data: typedefs.AllowSharedBufferSource,
    transfer: ?[]const runtime.JSValue = null,

    /// [EnforceRange] members: converted with that branch of ConvertToInt.
    pub const enforce_range_members = .{ "timestamp", "duration" };
};
