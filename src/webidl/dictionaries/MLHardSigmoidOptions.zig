//! WebIDL dictionary: MLHardSigmoidOptions
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const MLOperatorOptions = @import("MLOperatorOptions.zig").MLOperatorOptions;

pub const MLHardSigmoidOptions = struct {
    // Inherited from MLOperatorOptions
    base: MLOperatorOptions,

    alpha: ?f64 = null,
    beta: ?f64 = null,

    /// WebIDL `double` and `float` members (not `unrestricted`): NaN and the
    /// infinities throw a TypeError when the dictionary is converted.
    pub const restricted_members = .{ "alpha", "beta" };

    /// Optional members' IDL default values: a member the value leaves
    /// unset is written with its default when converted to script.
    pub const member_defaults = .{
        .{ "alpha", .{ .number = 0.2 } },
        .{ "beta", .{ .number = 0.5 } },
    };
};
