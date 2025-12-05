//! WebIDL typedef: RequestInfo
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");

pub const RequestInfo = union(enum) {
    request: *runtime.Instance,
    usvstring: runtime.USVString,
};
