//! WebIDL dictionary: XRMediaLayerInit
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const enums = @import("enums");

pub const XRMediaLayerInit = struct {
    space: *runtime.Instance,
    layout: ?enums.XRLayerLayout = null,
    invertStereo: ?bool = null,

    /// WebIDL interface types: the interface each interface-typed member
    /// converts to - a TypeError unless the value implements it.
    pub const interface_members = .{
        .{ "space", "XRSpace" },
    };
};
