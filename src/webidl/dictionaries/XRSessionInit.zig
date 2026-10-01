//! WebIDL dictionary: XRSessionInit
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const typedefs = @import("typedefs");
const XRDepthStateInit = @import("XRDepthStateInit.zig").XRDepthStateInit;
const XRDOMOverlayInit = @import("XRDOMOverlayInit.zig").XRDOMOverlayInit;

pub const XRSessionInit = struct {
    requiredFeatures: ?[]const runtime.DOMString = null,
    optionalFeatures: ?[]const runtime.DOMString = null,
    depthSensing: ?XRDepthStateInit = null,
    domOverlay: ?XRDOMOverlayInit = null,
};
