//! WebIDL dictionary: DeviceOrientationEventInit
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const EventInit = @import("EventInit.zig").EventInit;

pub const DeviceOrientationEventInit = struct {
    // Inherited from EventInit
    base: EventInit,

    alpha: ?f64 = null,
    beta: ?f64 = null,
    gamma: ?f64 = null,
    absolute: ?bool = null,

    /// WebIDL `double` and `float` members (not `unrestricted`): NaN and the
    /// infinities throw a TypeError when the dictionary is converted.
    pub const restricted_members = .{ "alpha", "beta", "gamma" };

    /// Optional members' IDL default values: a member the value leaves
    /// unset is written with its default when converted to script.
    pub const member_defaults = .{
        .{ "alpha", .null },
        .{ "beta", .null },
        .{ "gamma", .null },
        .{ "absolute", .{ .boolean = false } },
    };

    /// Optional members whose IDL type is nullable: a present null is the
    /// value null. Any other member's present null converts by its type.
    pub const nullable_members = .{ "alpha", "beta", "gamma" };
};
