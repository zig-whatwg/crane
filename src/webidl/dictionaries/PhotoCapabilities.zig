//! WebIDL dictionary: PhotoCapabilities
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const enums = @import("enums");
const MediaSettingsRange = @import("MediaSettingsRange.zig").MediaSettingsRange;

pub const PhotoCapabilities = struct {
    redEyeReduction: ?enums.RedEyeReduction = null,
    imageHeight: ?MediaSettingsRange = null,
    imageWidth: ?MediaSettingsRange = null,
    fillLightMode: ?[]const enums.FillLightMode = null,
};
