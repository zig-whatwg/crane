//! WebIDL dictionary: AudioDecoderConfig
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const typedefs = @import("typedefs");

pub const AudioDecoderConfig = struct {
    /// A WebIDL dictionary (the binding's dictionary rules read this marker).
    pub const webidl_dictionary = true;
    codec: runtime.DOMString,
    sampleRate: u32,
    numberOfChannels: u32,
    description: ?typedefs.AllowSharedBufferSource = null,

    /// [EnforceRange] members: converted with that branch of ConvertToInt.
    pub const enforce_range_members = .{ "sampleRate", "numberOfChannels" };
};
