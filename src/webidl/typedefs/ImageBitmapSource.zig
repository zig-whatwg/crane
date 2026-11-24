//! WebIDL typedef: ImageBitmapSource
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const webidl = @import("webidl");
const typedefs = @import("root.zig");

pub const ImageBitmapSource = union(enum) {
    canvas_image_source: typedefs.CanvasImageSource,
    blob: *runtime.Instance,
    image_data: *runtime.Instance,

    /// What each field's member type is, for the binding's union conversion
    /// (WebIDL 3.2.25; webidl.union_arms).
    pub const arms = [_]webidl.UnionArm{
        .{ .field = "canvas_image_source", .kind = .@"union" },
        .{ .field = "blob", .kind = .{ .interface = "Blob" } },
        .{ .field = "image_data", .kind = .{ .interface = "ImageData" } },
    };
};
