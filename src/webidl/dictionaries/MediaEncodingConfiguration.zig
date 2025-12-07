//! WebIDL dictionary: MediaEncodingConfiguration
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const enums = @import("enums");
const MediaConfiguration = @import("MediaConfiguration.zig").MediaConfiguration;

pub const MediaEncodingConfiguration = struct {
    // Inherited from MediaConfiguration
    base: MediaConfiguration,

    @"type": enums.MediaEncodingType,
};
