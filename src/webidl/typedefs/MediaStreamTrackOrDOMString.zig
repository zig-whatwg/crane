//! WebIDL typedef: MediaStreamTrackOrDOMString
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const typedefs = @import("root.zig");

pub const MediaStreamTrackOrDOMString = union(enum) {
    media_stream_track: *runtime.Instance,
    domstring: runtime.DOMString,
};
