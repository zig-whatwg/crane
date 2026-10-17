//! WebIDL dictionary: XRSessionInit
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const XRDepthStateInit = @import("XRDepthStateInit.zig").XRDepthStateInit;
const XRDOMOverlayInit = @import("XRDOMOverlayInit.zig").XRDOMOverlayInit;

pub const XRSessionInit = struct {
    requiredFeatures: ?[]const runtime.DOMString = null,
    optionalFeatures: ?[]const runtime.DOMString = null,
    depthSensing: ?XRDepthStateInit = null,
    domOverlay: ?XRDOMOverlayInit = null,

    /// Optional members whose IDL type is nullable: a present null is the
    /// value null. Any other member's present null converts by its type.
    pub const nullable_members = .{"domOverlay"};
};
