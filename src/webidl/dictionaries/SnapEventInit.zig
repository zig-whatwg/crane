//! WebIDL dictionary: SnapEventInit
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const EventInit = @import("EventInit.zig").EventInit;

pub const SnapEventInit = struct {
    // Inherited from EventInit
    base: EventInit,

    snapTargetBlock: ?*runtime.Instance = null,
    snapTargetInline: ?*runtime.Instance = null,

    /// Optional members whose IDL type is nullable: a present null is the
    /// value null. Any other member's present null converts by its type.
    pub const nullable_members = .{ "snapTargetBlock", "snapTargetInline" };

    /// WebIDL interface types: the interface each interface-typed member
    /// converts to - a TypeError unless the value implements it.
    pub const interface_members = .{
        .{ "snapTargetBlock", "Node" },
        .{ "snapTargetInline", "Node" },
    };
};
