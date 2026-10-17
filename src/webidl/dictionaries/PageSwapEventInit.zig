//! WebIDL dictionary: PageSwapEventInit
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const EventInit = @import("EventInit.zig").EventInit;

pub const PageSwapEventInit = struct {
    // Inherited from EventInit
    base: EventInit,

    activation: ?*runtime.Instance = null,
    viewTransition: ?*runtime.Instance = null,

    /// Optional members whose IDL type is nullable: a present null is the
    /// value null. Any other member's present null converts by its type.
    pub const nullable_members = .{ "activation", "viewTransition" };

    /// WebIDL interface types: the interface each interface-typed member
    /// converts to - a TypeError unless the value implements it.
    pub const interface_members = .{
        .{ "activation", "NavigationActivation" },
        .{ "viewTransition", "ViewTransition" },
    };
};
