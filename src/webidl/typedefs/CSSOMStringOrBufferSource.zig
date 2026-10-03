//! WebIDL typedef: CSSOMStringOrBufferSource
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const typedefs = @import("root.zig");

pub const CSSOMStringOrBufferSource = union(enum) {
    cssomstring: typedefs.CSSOMString,
    buffer_source: typedefs.BufferSource,
};
