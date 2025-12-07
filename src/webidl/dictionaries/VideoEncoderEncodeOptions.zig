//! WebIDL dictionary: VideoEncoderEncodeOptions
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const v8 = @import("v8");
const VideoEncoderEncodeOptionsForHevc = @import("VideoEncoderEncodeOptionsForHevc.zig").VideoEncoderEncodeOptionsForHevc;
const VideoEncoderEncodeOptionsForAv1 = @import("VideoEncoderEncodeOptionsForAv1.zig").VideoEncoderEncodeOptionsForAv1;
const VideoEncoderEncodeOptionsForAvc = @import("VideoEncoderEncodeOptionsForAvc.zig").VideoEncoderEncodeOptionsForAvc;
const VideoEncoderEncodeOptionsForVp9 = @import("VideoEncoderEncodeOptionsForVp9.zig").VideoEncoderEncodeOptionsForVp9;

pub const VideoEncoderEncodeOptions = struct {
    keyFrame: ?bool = null,
    hevc: ?VideoEncoderEncodeOptionsForHevc = null,
    av1: ?VideoEncoderEncodeOptionsForAv1 = null,
    avc: ?VideoEncoderEncodeOptionsForAvc = null,
    vp9: ?VideoEncoderEncodeOptionsForVp9 = null,
};
