//! WebIDL typedef: CSSPerspectiveValue
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const webidl = @import("webidl");
const typedefs = @import("root.zig");

pub const CSSPerspectiveValue = union(enum) {
    cssnumeric_value: *runtime.Instance,
    csskeywordish: typedefs.CSSKeywordish,

    /// What each field's member type is, for the binding's union conversion
    /// (WebIDL 3.2.25; webidl.union_arms).
    pub const arms = [_]webidl.UnionArm{
        .{ .field = "cssnumeric_value", .kind = .{ .interface = "CSSNumericValue" } },
        .{ .field = "csskeywordish", .kind = .@"union" },
    };
};
