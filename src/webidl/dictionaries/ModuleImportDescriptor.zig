//! WebIDL dictionary: ModuleImportDescriptor
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");

pub const ModuleImportDescriptor = struct {
    module: runtime.USVString,
    name: runtime.USVString,
    kind: *const anyopaque,
};
