//! WebIDL typedef: CSSColorAngle
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const webidl = @import("webidl");
const typedefs = @import("root.zig");

pub const CSSColorAngle = union(enum) {
    cssnumberish: typedefs.CSSNumberish,
    csskeywordish: typedefs.CSSKeywordish,

    /// What each field's member type is, for the binding's union conversion
    /// (WebIDL 3.2.25; webidl.union_arms).
    pub const arms = [_]webidl.UnionArm{
        .{ .field = "cssnumberish", .kind = .@"union" },
        .{ .field = "csskeywordish", .kind = .@"union" },
    };
};
