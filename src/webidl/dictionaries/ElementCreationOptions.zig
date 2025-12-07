//! WebIDL dictionary: ElementCreationOptions
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const v8 = @import("v8");
const typedefs = @import("typedefs");

pub const ElementCreationOptions = struct {
    customElementRegistry: ?*runtime.Instance = null,
    is: ?runtime.DOMString = null,
};
