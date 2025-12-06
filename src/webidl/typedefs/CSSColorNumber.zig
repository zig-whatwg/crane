//! WebIDL typedef: CSSColorNumber
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const typedefs = @import("root.zig");

pub const CSSColorNumber = union(enum) {
    cssnumberish: typedefs.CSSNumberish,
    csskeywordish: typedefs.CSSKeywordish,
};
