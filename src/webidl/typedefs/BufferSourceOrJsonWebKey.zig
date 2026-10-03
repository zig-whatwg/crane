//! WebIDL typedef: BufferSourceOrJsonWebKey
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const typedefs = @import("root.zig");
const dictionaries = @import("dictionaries");

pub const BufferSourceOrJsonWebKey = union(enum) {
    buffer_source: typedefs.BufferSource,
    json_web_key: dictionaries.JsonWebKey,
};
