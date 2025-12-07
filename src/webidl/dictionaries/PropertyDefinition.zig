//! WebIDL dictionary: PropertyDefinition
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const typedefs = @import("typedefs");

pub const PropertyDefinition = struct {
    name: runtime.DOMString,
    syntax: ?runtime.DOMString = null,
    inherits: bool,
    initialValue: ?runtime.DOMString = null,
};
