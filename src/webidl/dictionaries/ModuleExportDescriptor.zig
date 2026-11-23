//! WebIDL dictionary: ModuleExportDescriptor
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const enums = @import("enums");

pub const ModuleExportDescriptor = struct {
    /// A WebIDL dictionary (the binding's dictionary rules read this marker).
    pub const webidl_dictionary = true;
    name: runtime.USVString,
    kind: enums.ImportExportKind,
};
