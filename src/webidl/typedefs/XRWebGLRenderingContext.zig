//! WebIDL typedef: XRWebGLRenderingContext
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const v8 = @import("v8");

pub const XRWebGLRenderingContext = union(enum) {
    web_glrendering_context: *runtime.Instance,
    web_gl2rendering_context: *runtime.Instance,
};
