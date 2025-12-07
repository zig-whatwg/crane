//! WebIDL dictionary: VideoColorSpaceInit
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const enums = @import("enums");

pub const VideoColorSpaceInit = struct {
    primaries: ?enums.VideoColorPrimaries = null,
    transfer: ?enums.VideoTransferCharacteristics = null,
    matrix: ?enums.VideoMatrixCoefficients = null,
    fullRange: ?bool = null,
};
