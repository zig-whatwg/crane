//! WebIDL dictionary: XRVisibilityMaskChangeEventInit
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const enums = @import("enums");
const EventInit = @import("EventInit.zig").EventInit;

pub const XRVisibilityMaskChangeEventInit = struct {
    /// A WebIDL dictionary (the binding's dictionary rules read this marker).
    pub const webidl_dictionary = true;
    // Inherited from EventInit
    base: EventInit,

    session: *runtime.Instance,
    eye: enums.XREye,
    index: u32,
    vertices: runtime.JSValue,
    indices: runtime.JSValue,

    /// WebIDL interface types: the interface each interface-typed member
    /// converts to - a TypeError unless the value implements it.
    pub const interface_members = .{
        .{ "session", "XRSession" },
    };
};
