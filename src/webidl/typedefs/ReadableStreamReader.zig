//! WebIDL typedef: ReadableStreamReader
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const v8 = @import("v8");

pub const ReadableStreamReader = union(enum) {
    readable_stream_default_reader: *runtime.Instance,
    readable_stream_byobreader: *runtime.Instance,
};
