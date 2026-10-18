//! WebIDL dictionary: AudioParamDescriptor
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const enums = @import("enums");

pub const AudioParamDescriptor = struct {
    name: runtime.DOMString,
    defaultValue: ?f32 = null,
    minValue: ?f32 = null,
    maxValue: ?f32 = null,
    automationRate: ?enums.AutomationRate = null,

    /// WebIDL `double` and `float` members (not `unrestricted`): NaN and the
    /// infinities throw a TypeError when the dictionary is converted.
    pub const restricted_members = .{ "defaultValue", "minValue", "maxValue" };

    /// Optional members' IDL default values: a member the value leaves
    /// unset is written with its default when converted to script.
    pub const member_defaults = .{
        .{ "defaultValue", .{ .number = 0 } },
        .{ "minValue", .{ .number = -340282350000000000000000000000000000000 } },
        .{ "maxValue", .{ .number = 340282350000000000000000000000000000000 } },
        .{ "automationRate", .{ .string = "a-rate" } },
    };
};
