//! WebIDL typedef: CSSColorAngle
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const v8 = @import("v8");
const typedefs = @import("root.zig");

pub const CSSColorAngle = union(enum) {
    cssnumberish: typedefs.CSSNumberish,
    csskeywordish: typedefs.CSSKeywordish,
};
