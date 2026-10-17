//! WebIDL typedef: MediaStreamTrackOrHandle
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");

pub const MediaStreamTrackOrHandle = union(enum) {
    media_stream_track: *runtime.Instance,
    media_stream_track_handle: *runtime.Instance,
};
