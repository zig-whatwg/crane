//! WebIDL typedef: CanvasImageSource
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const webidl = @import("webidl");
const typedefs = @import("root.zig");

pub const CanvasImageSource = union(enum) {
    htmlor_svgimage_element: typedefs.HTMLOrSVGImageElement,
    htmlvideo_element: *runtime.Instance,
    htmlcanvas_element: *runtime.Instance,
    image_bitmap: *runtime.Instance,
    offscreen_canvas: *runtime.Instance,
    video_frame: *runtime.Instance,

    /// What each field's member type is, for the binding's union conversion
    /// (WebIDL 3.2.25; webidl.union_arms).
    pub const arms = [_]webidl.UnionArm{
        .{ .field = "htmlor_svgimage_element", .kind = .@"union" },
        .{ .field = "htmlvideo_element", .kind = .{ .interface = "HTMLVideoElement" } },
        .{ .field = "htmlcanvas_element", .kind = .{ .interface = "HTMLCanvasElement" } },
        .{ .field = "image_bitmap", .kind = .{ .interface = "ImageBitmap" } },
        .{ .field = "offscreen_canvas", .kind = .{ .interface = "OffscreenCanvas" } },
        .{ .field = "video_frame", .kind = .{ .interface = "VideoFrame" } },
    };
};
