//! WebIDL dictionary: MediaDecodingConfiguration
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const v8 = @import("v8");
const enums = @import("enums");
const MediaCapabilitiesKeySystemConfiguration = @import("MediaCapabilitiesKeySystemConfiguration.zig").MediaCapabilitiesKeySystemConfiguration;
const MediaConfiguration = @import("MediaConfiguration.zig").MediaConfiguration;

pub const MediaDecodingConfiguration = struct {
    // Inherited from MediaConfiguration
    base: MediaConfiguration,

    @"type": enums.MediaDecodingType,
    keySystemConfiguration: ?MediaCapabilitiesKeySystemConfiguration = null,
};
