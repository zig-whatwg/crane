//! WebIDL dictionary: XRInputSourcesChangeEventInit
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const EventInit = @import("EventInit.zig").EventInit;

pub const XRInputSourcesChangeEventInit = struct {
    // Inherited from EventInit
    base: EventInit,

    session: *runtime.Instance,
    added: []const *runtime.Instance,
    removed: []const *runtime.Instance,

    /// WebIDL interface types: the interface each interface-typed member
    /// converts to - a TypeError unless the value implements it.
    pub const interface_members = .{
        .{ "session", "XRSession" },
        .{ "added", "XRInputSource" },
        .{ "removed", "XRInputSource" },
    };
};
