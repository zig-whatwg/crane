//! WebIDL typedef: XMLHttpRequestBodyInit
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const typedefs = @import("root.zig");

pub const XMLHttpRequestBodyInit = union(enum) {
    blob: *runtime.Instance,
    buffer_source: typedefs.BufferSource,
    form_data: *runtime.Instance,
    urlsearch_params: *runtime.Instance,
    usvstring: runtime.USVString,
};
