//! WebIDL dictionary: TransitionEventInit
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const typedefs = @import("typedefs");
const EventInit = @import("EventInit.zig").EventInit;

pub const TransitionEventInit = struct {
    // Inherited from EventInit
    base: EventInit,

    propertyName: ?typedefs.CSSOMString = null,
    elapsedTime: ?f64 = null,
    pseudoElement: ?typedefs.CSSOMString = null,
    animation: ?*runtime.Instance = null,

    /// WebIDL `double` and `float` members (not `unrestricted`): NaN and the
    /// infinities throw a TypeError when the dictionary is converted.
    pub const restricted_members = .{"elapsedTime"};

    /// Optional members' IDL default values: a member the value leaves
    /// unset is written with its default when converted to script.
    pub const member_defaults = .{
        .{ "propertyName", .{ .string = "" } },
        .{ "elapsedTime", .{ .number = 0 } },
        .{ "pseudoElement", .{ .string = "" } },
        .{ "animation", .null },
    };

    /// Optional members whose IDL type is nullable: a present null is the
    /// value null. Any other member's present null converts by its type.
    pub const nullable_members = .{"animation"};

    /// WebIDL interface types: the interface each interface-typed member
    /// converts to - a TypeError unless the value implements it.
    pub const interface_members = .{
        .{ "animation", "CSSTransition" },
    };
};
