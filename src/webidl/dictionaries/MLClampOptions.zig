//! WebIDL dictionary: MLClampOptions
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const MLOperatorOptions = @import("MLOperatorOptions.zig").MLOperatorOptions;

pub const MLClampOptions = struct {
    // Inherited from MLOperatorOptions
    base: MLOperatorOptions,

    minValue: ?anyopaque = null,
    maxValue: ?anyopaque = null,
};
