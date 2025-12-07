//! WebIDL dictionary: EncodedVideoChunkMetadata
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const typedefs = @import("typedefs");
const SvcOutputMetadata = @import("SvcOutputMetadata.zig").SvcOutputMetadata;
const VideoDecoderConfig = @import("VideoDecoderConfig.zig").VideoDecoderConfig;

pub const EncodedVideoChunkMetadata = struct {
    decoderConfig: ?VideoDecoderConfig = null,
    svc: ?SvcOutputMetadata = null,
    alphaSideData: ?typedefs.BufferSource = null,
};
