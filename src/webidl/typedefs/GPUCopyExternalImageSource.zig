//! WebIDL typedef: GPUCopyExternalImageSource
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const v8 = @import("v8");

pub const GPUCopyExternalImageSource = union(enum) {
    image_bitmap: *runtime.Instance,
    image_data: *runtime.Instance,
    htmlimage_element: *runtime.Instance,
    htmlvideo_element: *runtime.Instance,
    video_frame: *runtime.Instance,
    htmlcanvas_element: *runtime.Instance,
    offscreen_canvas: *runtime.Instance,
};
