//! WebIDL typedef: RenderingContext
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");

pub const RenderingContext = union(enum) {
    canvas_rendering_context2d: *runtime.Instance,
    image_bitmap_rendering_context: *runtime.Instance,
    web_glrendering_context: *runtime.Instance,
    web_gl2rendering_context: *runtime.Instance,
    gpucanvas_context: *runtime.Instance,
};
