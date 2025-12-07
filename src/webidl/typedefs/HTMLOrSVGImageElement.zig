//! WebIDL typedef: HTMLOrSVGImageElement
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const v8 = @import("v8");

pub const HTMLOrSVGImageElement = union(enum) {
    htmlimage_element: *runtime.Instance,
    svgimage_element: *runtime.Instance,
};
