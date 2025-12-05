//! WebIDL typedef: PushMessageDataInit
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const typedefs = @import("root.zig");

pub const PushMessageDataInit = union(enum) {
    buffer_source: typedefs.BufferSource,
    usvstring: runtime.USVString,
};
