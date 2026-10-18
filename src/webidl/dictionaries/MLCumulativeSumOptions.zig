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

    /// Optional members' IDL default values: a member the value leaves
    /// unset is written with its default when converted to script.
    pub const member_defaults = .{
        .{ "exclusive", .{ .boolean = false } },
        .{ "reversed", .{ .boolean = false } },
    };
};
