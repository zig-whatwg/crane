//! WebIDL dictionary: PhotoSettings
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const enums = @import("enums");

pub const PhotoSettings = struct {
    fillLightMode: ?enums.FillLightMode = null,
    imageHeight: ?f64 = null,
    imageWidth: ?f64 = null,
    redEyeReduction: ?bool = null,

    /// WebIDL `double` and `float` members (not `unrestricted`): NaN and the
    /// infinities throw a TypeError when the dictionary is converted.
    pub const restricted_members = .{ "imageHeight", "imageWidth" };
};
