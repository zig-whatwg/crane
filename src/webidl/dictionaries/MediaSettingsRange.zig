//! WebIDL dictionary: MediaSettingsRange
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");

pub const MediaSettingsRange = struct {
    max: ?f64 = null,
    min: ?f64 = null,
    step: ?f64 = null,

    /// WebIDL `double` and `float` members (not `unrestricted`): NaN and the
    /// infinities throw a TypeError when the dictionary is converted.
    pub const restricted_members = .{ "max", "min", "step" };
};
