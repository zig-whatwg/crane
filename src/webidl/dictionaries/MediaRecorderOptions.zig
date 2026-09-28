//! WebIDL dictionary: MediaRecorderOptions
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const typedefs = @import("typedefs");
const enums = @import("enums");

pub const MediaRecorderOptions = struct {
    mimeType: ?runtime.DOMString = null,
    audioBitsPerSecond: ?u32 = null,
    videoBitsPerSecond: ?u32 = null,
    bitsPerSecond: ?u32 = null,
    audioBitrateMode: ?enums.BitrateMode = null,
    videoKeyFrameIntervalDuration: ?typedefs.DOMHighResTimeStamp = null,
    videoKeyFrameIntervalCount: ?u32 = null,

    /// WebIDL `double` and `float` members (not `unrestricted`): NaN and the
    /// infinities throw a TypeError when the dictionary is converted.
    pub const restricted_members = .{"videoKeyFrameIntervalDuration"};
};
