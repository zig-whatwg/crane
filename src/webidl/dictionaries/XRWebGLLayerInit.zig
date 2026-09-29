//! WebIDL dictionary: XRWebGLLayerInit
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");

pub const XRWebGLLayerInit = struct {
    antialias: ?bool = null,
    depth: ?bool = null,
    stencil: ?bool = null,
    alpha: ?bool = null,
    ignoreDepthValues: ?bool = null,
    framebufferScaleFactor: ?f64 = null,

    /// WebIDL `double` and `float` members (not `unrestricted`): NaN and the
    /// infinities throw a TypeError when the dictionary is converted.
    pub const restricted_members = .{"framebufferScaleFactor"};
};
