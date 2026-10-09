//! The WPT runner's media backend: what the runner, as a host, really
//! decodes. Crane builds in no decoder (the user, 2026-10-08: "Host decoders
//! only"); a host supplies one through BrowserConfig.media_backend
//! (src/platform/media_backend.zig).
//!
//! The root of the runner's media test step in build.zig: every media file
//! of the runner is reached from here, so its tests run in `zig build test`.
const std = @import("std");
pub const wav_backend = @import("wav_backend.zig");
pub const webm_demuxer = @import("webm_demuxer.zig");
pub const webm_frames = @import("webm_frames.zig");

test {
    std.testing.refAllDecls(@This());
    _ = wav_backend;
    _ = webm_demuxer;
    _ = webm_frames;
}
