//! WebIDL dictionary: MediaCapabilitiesDecodingInfo
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const MediaDecodingConfiguration = @import("MediaDecodingConfiguration.zig").MediaDecodingConfiguration;
const MediaCapabilitiesInfo = @import("MediaCapabilitiesInfo.zig").MediaCapabilitiesInfo;

pub const MediaCapabilitiesDecodingInfo = struct {
    // Inherited from MediaCapabilitiesInfo
    base: MediaCapabilitiesInfo,

    keySystemAccess: *runtime.Instance,
    configuration: MediaDecodingConfiguration,
};
