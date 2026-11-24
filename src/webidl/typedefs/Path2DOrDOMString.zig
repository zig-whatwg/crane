//! WebIDL typedef: Path2DOrDOMString
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const webidl = @import("webidl");
const typedefs = @import("root.zig");

pub const Path2DOrDOMString = union(enum) {
    path2d: *runtime.Instance,
    domstring: runtime.DOMString,

    /// What each field's member type is, for the binding's union conversion
    /// (WebIDL 3.2.25; webidl.union_arms).
    pub const arms = [_]webidl.UnionArm{
        .{ .field = "path2d", .kind = .{ .interface = "Path2D" } },
        .{ .field = "domstring", .kind = .string },
    };
};
