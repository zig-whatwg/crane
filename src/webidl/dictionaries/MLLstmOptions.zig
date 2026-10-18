//! WebIDL dictionary: MLLstmOptions
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const enums = @import("enums");
const MLOperatorOptions = @import("MLOperatorOptions.zig").MLOperatorOptions;

pub const MLLstmOptions = struct {
    // Inherited from MLOperatorOptions
    base: MLOperatorOptions,

    bias: ?*runtime.Instance = null,
    recurrentBias: ?*runtime.Instance = null,
    peepholeWeight: ?*runtime.Instance = null,
    initialHiddenState: ?*runtime.Instance = null,
    initialCellState: ?*runtime.Instance = null,
    returnSequence: ?bool = null,
    direction: ?enums.MLRecurrentNetworkDirection = null,
    layout: ?enums.MLLstmWeightLayout = null,
    activations: ?[]const enums.MLRecurrentNetworkActivation = null,

    /// Optional members' IDL default values: a member the value leaves
    /// unset is written with its default when converted to script.
    pub const member_defaults = .{
        .{ "returnSequence", .{ .boolean = false } },
        .{ "direction", .{ .string = "forward" } },
        .{ "layout", .{ .string = "iofg" } },
    };

    /// WebIDL interface types: the interface each interface-typed member
    /// converts to - a TypeError unless the value implements it.
    pub const interface_members = .{
        .{ "bias", "MLOperand" },
        .{ "recurrentBias", "MLOperand" },
        .{ "peepholeWeight", "MLOperand" },
        .{ "initialHiddenState", "MLOperand" },
        .{ "initialCellState", "MLOperand" },
    };
};
