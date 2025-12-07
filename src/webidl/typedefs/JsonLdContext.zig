//! WebIDL typedef: JsonLdContext
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const v8 = @import("v8");
const typedefs = @import("root.zig");

pub const JsonLdContext = union(enum) {
    json_ld_record: typedefs.JsonLdRecord,
    json_ld_record_or_usvstring_sequence: []const *const anyopaque,
    usvstring: runtime.USVString,
};
