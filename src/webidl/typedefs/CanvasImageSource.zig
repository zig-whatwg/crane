//! WebIDL typedef: CanvasImageSource
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const typedefs = @import("root.zig");

pub const CanvasImageSource = union(enum) {
    htmlor_svgimage_element: typedefs.HTMLOrSVGImageElement,
    htmlvideo_element: *runtime.Instance,
    htmlcanvas_element: *runtime.Instance,
    image_bitmap: *runtime.Instance,
    offscreen_canvas: *runtime.Instance,
    video_frame: *runtime.Instance,
};
