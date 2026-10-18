//! WebIDL dictionary: NavigationCurrentEntryChangeEventInit
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const enums = @import("enums");
const EventInit = @import("EventInit.zig").EventInit;

pub const NavigationCurrentEntryChangeEventInit = struct {
    // Inherited from EventInit
    base: EventInit,

    navigationType: ?enums.NavigationType = null,
    from: *runtime.Instance,

    /// Optional members' IDL default values: a member the value leaves
    /// unset is written with its default when converted to script.
    pub const member_defaults = .{
        .{ "navigationType", .null },
    };

    /// Optional members whose IDL type is nullable: a present null is the
    /// value null. Any other member's present null converts by its type.
    pub const nullable_members = .{"navigationType"};

    /// WebIDL interface types: the interface each interface-typed member
    /// converts to - a TypeError unless the value implements it.
    pub const interface_members = .{
        .{ "from", "NavigationHistoryEntry" },
    };
};
