//! WebIDL typedef: FileOrUSVStringOrFormData
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const webidl = @import("webidl");
const typedefs = @import("root.zig");

pub const FileOrUSVStringOrFormData = union(enum) {
    file: *runtime.Instance,
    usvstring: runtime.USVString,
    form_data: *runtime.Instance,

    /// What each field's member type is, for the binding's union conversion
    /// (WebIDL 3.2.25; webidl.union_arms).
    pub const arms = [_]webidl.UnionArm{
        .{ .field = "file", .kind = .{ .interface = "File" } },
        .{ .field = "usvstring", .kind = .string },
        .{ .field = "form_data", .kind = .{ .interface = "FormData" } },
    };
};
