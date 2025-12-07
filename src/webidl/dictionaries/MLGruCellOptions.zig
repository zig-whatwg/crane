//! WebIDL dictionary: MLGruCellOptions
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const enums = @import("enums");
const MLOperatorOptions = @import("MLOperatorOptions.zig").MLOperatorOptions;

pub const MLGruCellOptions = struct {
    // Inherited from MLOperatorOptions
    base: MLOperatorOptions,

    bias: ?*runtime.Instance = null,
    recurrentBias: ?*runtime.Instance = null,
    resetAfter: ?bool = null,
    layout: ?enums.MLGruWeightLayout = null,
    activations: ?[]const enums.MLRecurrentNetworkActivation = null,
};
