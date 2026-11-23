//! WebIDL dictionary: MediaDecodingConfiguration
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const enums = @import("enums");
const MediaCapabilitiesKeySystemConfiguration = @import("MediaCapabilitiesKeySystemConfiguration.zig").MediaCapabilitiesKeySystemConfiguration;
const MediaConfiguration = @import("MediaConfiguration.zig").MediaConfiguration;

pub const MediaDecodingConfiguration = struct {
    /// A WebIDL dictionary (the binding's dictionary rules read this marker).
    pub const webidl_dictionary = true;
    // Inherited from MediaConfiguration
    base: MediaConfiguration,

    type: enums.MediaDecodingType,
    keySystemConfiguration: ?MediaCapabilitiesKeySystemConfiguration = null,
};
