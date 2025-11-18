//! WebIDL dictionary: MediaDecodingConfiguration
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const MediaConfiguration = @import("MediaConfiguration.zig").MediaConfiguration;

pub const MediaDecodingConfiguration = struct {
    // Inherited from MediaConfiguration
    base: MediaConfiguration,

    type: anyopaque,
    keySystemConfiguration: ?anyopaque = null,
};
