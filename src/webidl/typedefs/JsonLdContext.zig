//! WebIDL typedef: JsonLdContext
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const typedefs = @import("root.zig");

pub const JsonLdContext = union(enum) {
    json_ld_record: typedefs.JsonLdRecord,
    json_ld_record_or_usvstring_sequence: []const runtime.JSValue,
    usvstring: runtime.USVString,
};
