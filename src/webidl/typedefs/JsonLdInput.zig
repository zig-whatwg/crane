//! WebIDL typedef: JsonLdInput
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const v8 = @import("v8");
const typedefs = @import("root.zig");

pub const JsonLdInput = union(enum) {
    json_ld_record: typedefs.JsonLdRecord,
    json_ld_record_sequence: []const typedefs.JsonLdRecord,
    usvstring: runtime.USVString,
    remote_document: *runtime.Instance,
};
