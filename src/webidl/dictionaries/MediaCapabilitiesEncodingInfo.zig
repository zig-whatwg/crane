//! WebIDL dictionary: MediaCapabilitiesEncodingInfo
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const v8 = @import("v8");
const MediaEncodingConfiguration = @import("MediaEncodingConfiguration.zig").MediaEncodingConfiguration;
const MediaCapabilitiesInfo = @import("MediaCapabilitiesInfo.zig").MediaCapabilitiesInfo;

pub const MediaCapabilitiesEncodingInfo = struct {
    // Inherited from MediaCapabilitiesInfo
    base: MediaCapabilitiesInfo,

    configuration: MediaEncodingConfiguration,
};
