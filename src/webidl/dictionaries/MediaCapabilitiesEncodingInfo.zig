//! WebIDL dictionary: MediaCapabilitiesEncodingInfo
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const MediaEncodingConfiguration = @import("MediaEncodingConfiguration.zig").MediaEncodingConfiguration;
const MediaCapabilitiesInfo = @import("MediaCapabilitiesInfo.zig").MediaCapabilitiesInfo;

pub const MediaCapabilitiesEncodingInfo = struct {
    /// A WebIDL dictionary (the binding's dictionary rules read this marker).
    pub const webidl_dictionary = true;
    // Inherited from MediaCapabilitiesInfo
    base: MediaCapabilitiesInfo,

    configuration: MediaEncodingConfiguration,
};
