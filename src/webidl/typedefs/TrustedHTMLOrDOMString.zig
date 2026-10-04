//! WebIDL typedef: TrustedHTMLOrDOMString
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const typedefs = @import("root.zig");

pub const TrustedHTMLOrDOMString = union(enum) {
    trusted_html: *runtime.Instance,
    domstring: runtime.DOMString,
};
