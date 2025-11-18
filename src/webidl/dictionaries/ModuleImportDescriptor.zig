//! WebIDL dictionary: ModuleImportDescriptor
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");

pub const ModuleImportDescriptor = struct {
    module: runtime.DOMString,
    name: runtime.DOMString,
    kind: anyopaque,
};
