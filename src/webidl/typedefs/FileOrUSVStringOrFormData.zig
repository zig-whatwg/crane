//! WebIDL typedef: FileOrUSVStringOrFormData
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const typedefs = @import("root.zig");

pub const FileOrUSVStringOrFormData = union(enum) {
    file: *runtime.Instance,
    usvstring: runtime.USVString,
    form_data: *runtime.Instance,
};
