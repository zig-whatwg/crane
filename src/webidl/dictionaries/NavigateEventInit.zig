//! WebIDL dictionary: NavigateEventInit
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const typedefs = @import("typedefs");
const enums = @import("enums");
const EventInit = @import("EventInit.zig").EventInit;

pub const NavigateEventInit = struct {
    // Inherited from EventInit
    base: EventInit,

    navigationType: ?enums.NavigationType = null,
    destination: *runtime.Instance,
    canIntercept: ?bool = null,
    userInitiated: ?bool = null,
    hashChange: ?bool = null,
    signal: *runtime.Instance,
    formData: ?*runtime.Instance = null,
    downloadRequest: ?runtime.DOMString = null,
    info: ?runtime.JSValue = null,
    hasUAVisualTransition: ?bool = null,
    sourceElement: ?*runtime.Instance = null,

    /// `any` members: one present with the value null converts to `.null`,
    /// not to "not present".
    pub const any_members = .{"info"};

    /// Optional members whose IDL type is nullable: a present null is the
    /// value null. Any other member's present null converts by its type.
    pub const nullable_members = .{ "formData", "downloadRequest", "sourceElement" };

    /// WebIDL interface types: the interface each interface-typed member
    /// converts to - a TypeError unless the value implements it.
    pub const interface_members = .{
        .{ "destination", "NavigationDestination" },
        .{ "signal", "AbortSignal" },
        .{ "formData", "FormData" },
        .{ "sourceElement", "Element" },
    };
};
