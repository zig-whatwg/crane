//! WebIDL dictionary: XRTransientInputHitTestOptionsInit
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const enums = @import("enums");

pub const XRTransientInputHitTestOptionsInit = struct {
    profile: runtime.DOMString,
    entityTypes: ?[]const enums.XRHitTestTrackableType = null,
    offsetRay: ?*runtime.Instance = null,

    /// WebIDL interface types: the interface each interface-typed member
    /// converts to - a TypeError unless the value implements it.
    pub const interface_members = .{
        .{ "offsetRay", "XRRay" },
    };
};
