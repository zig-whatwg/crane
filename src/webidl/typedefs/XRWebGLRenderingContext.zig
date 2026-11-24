//! WebIDL typedef: XRWebGLRenderingContext
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const webidl = @import("webidl");

pub const XRWebGLRenderingContext = union(enum) {
    web_glrendering_context: *runtime.Instance,
    web_gl2rendering_context: *runtime.Instance,

    /// What each field's member type is, for the binding's union conversion
    /// (WebIDL 3.2.25; webidl.union_arms).
    pub const arms = [_]webidl.UnionArm{
        .{ .field = "web_glrendering_context", .kind = .{ .interface = "WebGLRenderingContext" } },
        .{ .field = "web_gl2rendering_context", .kind = .{ .interface = "WebGL2RenderingContext" } },
    };
};
