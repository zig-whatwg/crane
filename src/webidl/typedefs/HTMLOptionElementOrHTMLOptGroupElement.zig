//! WebIDL typedef: HTMLOptionElementOrHTMLOptGroupElement
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const typedefs = @import("root.zig");

pub const HTMLOptionElementOrHTMLOptGroupElement = union(enum) {
    htmloption_element: *runtime.Instance,
    htmlopt_group_element: *runtime.Instance,
};
