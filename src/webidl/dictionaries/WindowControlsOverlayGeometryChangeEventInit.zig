//! WebIDL dictionary: WindowControlsOverlayGeometryChangeEventInit
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const EventInit = @import("EventInit.zig").EventInit;

pub const WindowControlsOverlayGeometryChangeEventInit = struct {
    // Inherited from EventInit
    base: EventInit,

    titlebarAreaRect: *runtime.Instance,
    visible: ?bool = null,

    /// Optional members' IDL default values: a member the value leaves
    /// unset is written with its default when converted to script.
    pub const member_defaults = .{
        .{ "visible", .{ .boolean = false } },
    };

    /// WebIDL interface types: the interface each interface-typed member
    /// converts to - a TypeError unless the value implements it.
    pub const interface_members = .{
        .{ "titlebarAreaRect", "DOMRect" },
    };
};
