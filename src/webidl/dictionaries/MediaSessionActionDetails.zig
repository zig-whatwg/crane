//! WebIDL dictionary: MediaSessionActionDetails
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");

pub const MediaSessionActionDetails = struct {
    action: anyopaque,
    seekOffset: ?f64 = null,
    seekTime: ?f64 = null,
    fastSeek: ?bool = null,
    isActivating: ?bool = null,
    enterPictureInPictureReason: ?anyopaque = null,
};
