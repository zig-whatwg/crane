//! WebIDL typedef: MediaProvider
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");

pub const MediaProvider = union(enum) {
    media_stream: *runtime.Instance,
    media_source: *runtime.Instance,
    blob: *runtime.Instance,
};
