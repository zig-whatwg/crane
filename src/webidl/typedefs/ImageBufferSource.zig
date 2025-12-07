//! WebIDL typedef: ImageBufferSource
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const v8 = @import("v8");
const typedefs = @import("root.zig");

pub const ImageBufferSource = union(enum) {
    allow_shared_buffer_source: typedefs.AllowSharedBufferSource,
    readable_stream: *runtime.Instance,
};
