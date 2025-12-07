//! WebIDL typedef: ImageBitmapSource
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const v8 = @import("v8");
const typedefs = @import("root.zig");

pub const ImageBitmapSource = union(enum) {
    canvas_image_source: typedefs.CanvasImageSource,
    blob: *runtime.Instance,
    image_data: *runtime.Instance,
};
