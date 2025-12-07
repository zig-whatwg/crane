//! WebIDL dictionary: ModuleExportDescriptor
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const v8 = @import("v8");
const enums = @import("enums");

pub const ModuleExportDescriptor = struct {
    name: runtime.USVString,
    kind: enums.ImportExportKind,
};
