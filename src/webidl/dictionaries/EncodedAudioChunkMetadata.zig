//! WebIDL dictionary: EncodedAudioChunkMetadata
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const AudioDecoderConfig = @import("AudioDecoderConfig.zig").AudioDecoderConfig;

pub const EncodedAudioChunkMetadata = struct {
    /// A WebIDL dictionary (the binding's dictionary rules read this marker).
    pub const webidl_dictionary = true;
    decoderConfig: ?AudioDecoderConfig = null,
};
