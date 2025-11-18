//! WebIDL dictionary: MLCumulativeSumOptions
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const MLOperatorOptions = @import("MLOperatorOptions.zig").MLOperatorOptions;

pub const MLCumulativeSumOptions = struct {
    // Inherited from MLOperatorOptions
    base: MLOperatorOptions,

    exclusive: ?bool = null,
    reversed: ?bool = null,
};
