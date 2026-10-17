//! WebIDL dictionary: XRGPUCubeLayerInit
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const XRGPULayerInit = @import("XRGPULayerInit.zig").XRGPULayerInit;

pub const XRGPUCubeLayerInit = struct {
    // Inherited from XRGPULayerInit
    base: XRGPULayerInit,

    orientation: ?*runtime.Instance = null,

    /// Optional members whose IDL type is nullable: a present null is the
    /// value null. Any other member's present null converts by its type.
    pub const nullable_members = .{"orientation"};
};
