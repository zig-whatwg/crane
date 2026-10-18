//! WebIDL dictionary: BaseComputedKeyframe
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const enums = @import("enums");

pub const BaseComputedKeyframe = struct {
    offset: ?f64 = null,
    computedOffset: ?f64 = null,
    easing: ?runtime.DOMString = null,
    composite: ?enums.CompositeOperationOrAuto = null,

    /// WebIDL `double` and `float` members (not `unrestricted`): NaN and the
    /// infinities throw a TypeError when the dictionary is converted.
    pub const restricted_members = .{ "offset", "computedOffset" };

    /// Optional members' IDL default values: a member the value leaves
    /// unset is written with its default when converted to script.
    pub const member_defaults = .{
        .{ "offset", .null },
        .{ "easing", .{ .string = "linear" } },
        .{ "composite", .{ .string = "auto" } },
    };

    /// Optional members whose IDL type is nullable: a present null is the
    /// value null. Any other member's present null converts by its type.
    pub const nullable_members = .{"offset"};
};
