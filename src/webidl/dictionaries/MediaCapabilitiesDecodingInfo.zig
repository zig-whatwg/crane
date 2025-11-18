//! WebIDL dictionary: MediaCapabilitiesDecodingInfo
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const MediaCapabilitiesInfo = @import("MediaCapabilitiesInfo.zig").MediaCapabilitiesInfo;

pub const MediaCapabilitiesDecodingInfo = struct {
    // Inherited from MediaCapabilitiesInfo
    base: MediaCapabilitiesInfo,

    keySystemAccess: anyopaque,
    configuration: anyopaque,
};
