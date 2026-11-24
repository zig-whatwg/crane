//! WebIDL typedef: TexImageSource
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const webidl = @import("webidl");

pub const TexImageSource = union(enum) {
    image_bitmap: *runtime.Instance,
    image_data: *runtime.Instance,
    htmlimage_element: *runtime.Instance,
    htmlcanvas_element: *runtime.Instance,
    htmlvideo_element: *runtime.Instance,
    offscreen_canvas: *runtime.Instance,
    video_frame: *runtime.Instance,

    /// What each field's member type is, for the binding's union conversion
    /// (WebIDL 3.2.25; webidl.union_arms).
    pub const arms = [_]webidl.UnionArm{
        .{ .field = "image_bitmap", .kind = .{ .interface = "ImageBitmap" } },
        .{ .field = "image_data", .kind = .{ .interface = "ImageData" } },
        .{ .field = "htmlimage_element", .kind = .{ .interface = "HTMLImageElement" } },
        .{ .field = "htmlcanvas_element", .kind = .{ .interface = "HTMLCanvasElement" } },
        .{ .field = "htmlvideo_element", .kind = .{ .interface = "HTMLVideoElement" } },
        .{ .field = "offscreen_canvas", .kind = .{ .interface = "OffscreenCanvas" } },
        .{ .field = "video_frame", .kind = .{ .interface = "VideoFrame" } },
    };
};
