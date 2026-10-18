//! WebIDL dictionary: MLBatchNormalizationOptions
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const MLOperatorOptions = @import("MLOperatorOptions.zig").MLOperatorOptions;

pub const MLBatchNormalizationOptions = struct {
    // Inherited from MLOperatorOptions
    base: MLOperatorOptions,

    scale: ?*runtime.Instance = null,
    bias: ?*runtime.Instance = null,
    axis: ?u32 = null,
    epsilon: ?f64 = null,

    /// WebIDL `double` and `float` members (not `unrestricted`): NaN and the
    /// infinities throw a TypeError when the dictionary is converted.
    pub const restricted_members = .{"epsilon"};

    /// Optional members' IDL default values: a member the value leaves
    /// unset is written with its default when converted to script.
    pub const member_defaults = .{
        .{ "axis", .{ .number = 1 } },
        .{ "epsilon", .{ .number = 0.00001 } },
    };

    /// [EnforceRange] members: converted with that branch of ConvertToInt.
    pub const enforce_range_members = .{"axis"};

    /// WebIDL interface types: the interface each interface-typed member
    /// converts to - a TypeError unless the value implements it.
    pub const interface_members = .{
        .{ "scale", "MLOperand" },
        .{ "bias", "MLOperand" },
    };
};
