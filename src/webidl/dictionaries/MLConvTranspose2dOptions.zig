//! WebIDL dictionary: MLConvTranspose2dOptions
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const enums = @import("enums");
const MLOperatorOptions = @import("MLOperatorOptions.zig").MLOperatorOptions;

pub const MLConvTranspose2dOptions = struct {
    // Inherited from MLOperatorOptions
    base: MLOperatorOptions,

    padding: ?[]const runtime.JSValue = null,
    strides: ?[]const runtime.JSValue = null,
    dilations: ?[]const runtime.JSValue = null,
    outputPadding: ?[]const runtime.JSValue = null,
    outputSizes: ?[]const runtime.JSValue = null,
    groups: ?u32 = null,
    inputLayout: ?enums.MLInputOperandLayout = null,
    filterLayout: ?enums.MLConvTranspose2dFilterOperandLayout = null,
    bias: ?*runtime.Instance = null,

    /// Optional members' IDL default values: a member the value leaves
    /// unset is written with its default when converted to script.
    pub const member_defaults = .{
        .{ "groups", .{ .number = 1 } },
        .{ "inputLayout", .{ .string = "nchw" } },
        .{ "filterLayout", .{ .string = "iohw" } },
    };

    /// [EnforceRange] members: converted with that branch of ConvertToInt.
    pub const enforce_range_members = .{"groups"};

    /// WebIDL interface types: the interface each interface-typed member
    /// converts to - a TypeError unless the value implements it.
    pub const interface_members = .{
        .{ "bias", "MLOperand" },
    };
};
