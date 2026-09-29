//! WebIDL dictionary: MLResample2dOptions
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const enums = @import("enums");
const MLOperatorOptions = @import("MLOperatorOptions.zig").MLOperatorOptions;

pub const MLResample2dOptions = struct {
    // Inherited from MLOperatorOptions
    base: MLOperatorOptions,

    mode: ?enums.MLInterpolationMode = null,
    scales: ?[]const f32 = null,
    sizes: ?[]const runtime.JSValue = null,
    axes: ?[]const runtime.JSValue = null,

    /// WebIDL `double` and `float` members (not `unrestricted`): NaN and the
    /// infinities throw a TypeError when the dictionary is converted.
    pub const restricted_members = .{"scales"};
};
