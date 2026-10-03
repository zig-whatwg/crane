//! WebIDL dictionary: FlacEncoderConfig
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");

pub const FlacEncoderConfig = struct {
    blockSize: ?u32 = null,
    compressLevel: ?u32 = null,

    /// [EnforceRange] members: converted with that branch of ConvertToInt.
    pub const enforce_range_members = .{ "blockSize", "compressLevel" };
};
