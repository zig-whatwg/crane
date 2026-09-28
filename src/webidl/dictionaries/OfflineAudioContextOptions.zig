//! WebIDL dictionary: OfflineAudioContextOptions
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const enums = @import("enums");

pub const OfflineAudioContextOptions = struct {
    numberOfChannels: ?u32 = null,
    length: u32,
    sampleRate: f32,
    renderSizeHint: ?runtime.JSValue = null,

    /// WebIDL `double` and `float` members (not `unrestricted`): NaN and the
    /// infinities throw a TypeError when the dictionary is converted.
    pub const restricted_members = .{"sampleRate"};
};
