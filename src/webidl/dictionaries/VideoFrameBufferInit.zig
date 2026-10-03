//! WebIDL dictionary: VideoFrameBufferInit
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const enums = @import("enums");
const PlaneLayout = @import("PlaneLayout.zig").PlaneLayout;
const VideoFrameMetadata = @import("VideoFrameMetadata.zig").VideoFrameMetadata;
const VideoColorSpaceInit = @import("VideoColorSpaceInit.zig").VideoColorSpaceInit;
const DOMRectInit = @import("DOMRectInit.zig").DOMRectInit;

pub const VideoFrameBufferInit = struct {
    format: enums.VideoPixelFormat,
    codedWidth: u32,
    codedHeight: u32,
    timestamp: i64,
    duration: ?u64 = null,
    layout: ?[]const PlaneLayout = null,
    visibleRect: ?DOMRectInit = null,
    rotation: ?f64 = null,
    flip: ?bool = null,
    displayWidth: ?u32 = null,
    displayHeight: ?u32 = null,
    colorSpace: ?VideoColorSpaceInit = null,
    transfer: ?[]const runtime.JSValue = null,
    metadata: ?VideoFrameMetadata = null,

    /// WebIDL `double` and `float` members (not `unrestricted`): NaN and the
    /// infinities throw a TypeError when the dictionary is converted.
    pub const restricted_members = .{"rotation"};

    /// [EnforceRange] members: converted with that branch of ConvertToInt.
    pub const enforce_range_members = .{ "codedWidth", "codedHeight", "timestamp", "duration", "displayWidth", "displayHeight" };
};
