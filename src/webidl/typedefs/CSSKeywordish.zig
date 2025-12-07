//! WebIDL typedef: CSSKeywordish
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const v8 = @import("v8");
const typedefs = @import("root.zig");

pub const CSSKeywordish = union(enum) {
    domstring: runtime.DOMString,
    csskeyword_value: *runtime.Instance,
};
