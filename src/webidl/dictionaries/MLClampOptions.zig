//! WebIDL dictionary: MLClampOptions
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const v8 = @import("v8");
const typedefs = @import("typedefs");
const MLOperatorOptions = @import("MLOperatorOptions.zig").MLOperatorOptions;

pub const MLClampOptions = struct {
    // Inherited from MLOperatorOptions
    base: MLOperatorOptions,

    minValue: ?typedefs.MLNumber = null,
    maxValue: ?typedefs.MLNumber = null,
};
