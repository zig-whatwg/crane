//! WebIDL dictionary: MediaSessionActionDetails
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const enums = @import("enums");

pub const MediaSessionActionDetails = struct {
    action: enums.MediaSessionAction,
    seekOffset: ?f64 = null,
    seekTime: ?f64 = null,
    fastSeek: ?bool = null,
    isActivating: ?bool = null,
    enterPictureInPictureReason: ?enums.MediaSessionEnterPictureInPictureReason = null,

    /// WebIDL `double` and `float` members (not `unrestricted`): NaN and the
    /// infinities throw a TypeError when the dictionary is converted.
    pub const restricted_members = .{ "seekOffset", "seekTime" };
};
