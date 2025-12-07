//! WebIDL dictionary: XRSessionInit
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const typedefs = @import("typedefs");
const XRDOMOverlayInit = @import("XRDOMOverlayInit.zig").XRDOMOverlayInit;
const XRDepthStateInit = @import("XRDepthStateInit.zig").XRDepthStateInit;

pub const XRSessionInit = struct {
    requiredFeatures: ?[]const runtime.DOMString = null,
    optionalFeatures: ?[]const runtime.DOMString = null,
    domOverlay: ?XRDOMOverlayInit = null,
    depthSensing: ?XRDepthStateInit = null,
};
