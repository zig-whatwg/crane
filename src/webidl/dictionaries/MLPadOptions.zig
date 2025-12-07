//! WebIDL dictionary: MLPadOptions
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const v8 = @import("v8");
const typedefs = @import("typedefs");
const enums = @import("enums");
const MLOperatorOptions = @import("MLOperatorOptions.zig").MLOperatorOptions;

pub const MLPadOptions = struct {
    // Inherited from MLOperatorOptions
    base: MLOperatorOptions,

    mode: ?enums.MLPaddingMode = null,
    value: ?typedefs.MLNumber = null,
};
