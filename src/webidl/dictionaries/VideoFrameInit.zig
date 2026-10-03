//! WebIDL dictionary: VideoFrameInit
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const enums = @import("enums");
const VideoFrameMetadata = @import("VideoFrameMetadata.zig").VideoFrameMetadata;
const DOMRectInit = @import("DOMRectInit.zig").DOMRectInit;

pub const VideoFrameInit = struct {
    duration: ?u64 = null,
    timestamp: ?i64 = null,
    alpha: ?enums.AlphaOption = null,
    visibleRect: ?DOMRectInit = null,
    rotation: ?f64 = null,
    flip: ?bool = null,
    displayWidth: ?u32 = null,
    displayHeight: ?u32 = null,
    metadata: ?VideoFrameMetadata = null,

    /// WebIDL `double` and `float` members (not `unrestricted`): NaN and the
    /// infinities throw a TypeError when the dictionary is converted.
    pub const restricted_members = .{"rotation"};

    /// [EnforceRange] members: converted with that branch of ConvertToInt.
    pub const enforce_range_members = .{ "displayWidth", "displayHeight" };
};
