//! WebIDL dictionary: MLResample2dOptions
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const v8 = @import("v8");
const enums = @import("enums");
const MLOperatorOptions = @import("MLOperatorOptions.zig").MLOperatorOptions;

pub const MLResample2dOptions = struct {
    // Inherited from MLOperatorOptions
    base: MLOperatorOptions,

    mode: ?enums.MLInterpolationMode = null,
    scales: ?[]const f32 = null,
    sizes: ?[]const *const anyopaque = null,
    axes: ?[]const *const anyopaque = null,
};
