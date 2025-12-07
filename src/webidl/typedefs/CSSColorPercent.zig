//! WebIDL typedef: CSSColorPercent
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const typedefs = @import("root.zig");

pub const CSSColorPercent = union(enum) {
    cssnumberish: typedefs.CSSNumberish,
    csskeywordish: typedefs.CSSKeywordish,
};
