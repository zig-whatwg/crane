//! WebIDL dictionary: MediaRecorderOptions
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");

pub const MediaRecorderOptions = struct {
    mimeType: ?runtime.DOMString = null,
    audioBitsPerSecond: ?u32 = null,
    videoBitsPerSecond: ?u32 = null,
    bitsPerSecond: ?u32 = null,
    audioBitrateMode: ?anyopaque = null,
    videoKeyFrameIntervalDuration: ?anyopaque = null,
    videoKeyFrameIntervalCount: ?u32 = null,
};
