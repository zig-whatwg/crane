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

    /// Optional members' IDL default values: a member the value leaves
    /// unset is written with its default when converted to script.
    pub const member_defaults = .{
        .{ "resetAfter", .{ .boolean = true } },
        .{ "layout", .{ .string = "zrn" } },
    };

    /// WebIDL interface types: the interface each interface-typed member
    /// converts to - a TypeError unless the value implements it.
    pub const interface_members = .{
        .{ "bias", "MLOperand" },
        .{ "recurrentBias", "MLOperand" },
    };
};
