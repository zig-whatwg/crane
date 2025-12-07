//! WebIDL typedef: ReadableStreamController
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");

pub const ReadableStreamController = union(enum) {
    readable_stream_default_controller: *runtime.Instance,
    readable_byte_stream_controller: *runtime.Instance,
};
