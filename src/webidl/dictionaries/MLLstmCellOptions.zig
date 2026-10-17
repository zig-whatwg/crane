//! WebIDL dictionary: MLLstmCellOptions
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
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

    /// WebIDL interface types: the interface each interface-typed member
    /// converts to - a TypeError unless the value implements it.
    pub const interface_members = .{
        .{ "bias", "MLOperand" },
        .{ "recurrentBias", "MLOperand" },
        .{ "peepholeWeight", "MLOperand" },
    };
};
