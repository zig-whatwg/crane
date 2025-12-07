//! WebIDL typedef: BodyInit
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const v8 = @import("v8");
const typedefs = @import("root.zig");

pub const BodyInit = union(enum) {
    readable_stream: *runtime.Instance,
    xmlhttp_request_body_init: typedefs.XMLHttpRequestBodyInit,
};
