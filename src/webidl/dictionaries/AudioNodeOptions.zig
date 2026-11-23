//! WebIDL dictionary: AudioNodeOptions
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const enums = @import("enums");

pub const AudioNodeOptions = struct {
    /// A WebIDL dictionary (the binding's dictionary rules read this marker).
    pub const webidl_dictionary = true;
    channelCount: ?u32 = null,
    channelCountMode: ?enums.ChannelCountMode = null,
    channelInterpretation: ?enums.ChannelInterpretation = null,
};
