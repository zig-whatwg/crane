//! WebIDL typedef: CSSToken
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const v8 = @import("v8");
const typedefs = @import("root.zig");

pub const CSSToken = union(enum) {
    domstring: runtime.DOMString,
    cssstyle_value: *runtime.Instance,
    cssparser_value: *runtime.Instance,
};
