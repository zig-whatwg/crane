//! WebIDL typedef: XMLHttpRequestBodyInit
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const webidl = @import("webidl");
const typedefs = @import("root.zig");

pub const XMLHttpRequestBodyInit = union(enum) {
    blob: *runtime.Instance,
    buffer_source: typedefs.BufferSource,
    form_data: *runtime.Instance,
    urlsearch_params: *runtime.Instance,
    usvstring: runtime.USVString,

    /// What each field's member type is, for the binding's union conversion
    /// (WebIDL 3.2.25; webidl.union_arms).
    pub const arms = [_]webidl.UnionArm{
        .{ .field = "blob", .kind = .{ .interface = "Blob" } },
        .{ .field = "buffer_source", .kind = .buffer_source },
        .{ .field = "form_data", .kind = .{ .interface = "FormData" } },
        .{ .field = "urlsearch_params", .kind = .{ .interface = "URLSearchParams" } },
        .{ .field = "usvstring", .kind = .string },
    };
};
