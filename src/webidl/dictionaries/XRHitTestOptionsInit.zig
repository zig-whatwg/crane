//! WebIDL dictionary: XRHitTestOptionsInit
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const enums = @import("enums");

pub const XRHitTestOptionsInit = struct {
    space: *runtime.Instance,
    entityTypes: ?[]const enums.XRHitTestTrackableType = null,
    offsetRay: ?*runtime.Instance = null,

    /// WebIDL interface types: the interface each interface-typed member
    /// converts to - a TypeError unless the value implements it.
    pub const interface_members = .{
        .{ "space", "XRSpace" },
        .{ "offsetRay", "XRRay" },
    };
};
