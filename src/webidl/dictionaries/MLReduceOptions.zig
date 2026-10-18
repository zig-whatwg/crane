//! WebIDL dictionary: MLReduceOptions
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const MLOperatorOptions = @import("MLOperatorOptions.zig").MLOperatorOptions;

pub const MLReduceOptions = struct {
    // Inherited from MLOperatorOptions
    base: MLOperatorOptions,

    axes: ?[]const runtime.JSValue = null,
    keepDimensions: ?bool = null,

    /// Optional members' IDL default values: a member the value leaves
    /// unset is written with its default when converted to script.
    pub const member_defaults = .{
        .{ "keepDimensions", .{ .boolean = false } },
    };
};
