//! WebIDL typedef: HTMLOrSVGScriptElement
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");

pub const HTMLOrSVGScriptElement = union(enum) {
    htmlscript_element: *runtime.Instance,
    svgscript_element: *runtime.Instance,
};
