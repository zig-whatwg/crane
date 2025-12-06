//! WebIDL typedef: CSSPerspectiveValue
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const typedefs = @import("root.zig");

pub const CSSPerspectiveValue = union(enum) {
    cssnumeric_value: *runtime.Instance,
    csskeywordish: typedefs.CSSKeywordish,
};
