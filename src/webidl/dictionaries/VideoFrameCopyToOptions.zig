//! WebIDL dictionary: VideoFrameCopyToOptions
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const v8 = @import("v8");
const enums = @import("enums");
const PlaneLayout = @import("PlaneLayout.zig").PlaneLayout;
const DOMRectInit = @import("DOMRectInit.zig").DOMRectInit;

pub const VideoFrameCopyToOptions = struct {
    rect: ?DOMRectInit = null,
    layout: ?[]const PlaneLayout = null,
    format: ?enums.VideoPixelFormat = null,
    colorSpace: ?enums.PredefinedColorSpace = null,
};
