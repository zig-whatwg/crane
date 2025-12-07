//! WebIDL dictionary: MLLstmCellOptions
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const v8 = @import("v8");
const enums = @import("enums");
const MLOperatorOptions = @import("MLOperatorOptions.zig").MLOperatorOptions;

pub const MLLstmCellOptions = struct {
    // Inherited from MLOperatorOptions
    base: MLOperatorOptions,

    bias: ?*runtime.Instance = null,
    recurrentBias: ?*runtime.Instance = null,
    peepholeWeight: ?*runtime.Instance = null,
    layout: ?enums.MLLstmWeightLayout = null,
    activations: ?[]const enums.MLRecurrentNetworkActivation = null,
};
