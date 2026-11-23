//! WebIDL dictionary: ModuleImportDescriptor
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const enums = @import("enums");

pub const ModuleImportDescriptor = struct {
    /// A WebIDL dictionary (the binding's dictionary rules read this marker).
    pub const webidl_dictionary = true;
    module: runtime.USVString,
    name: runtime.USVString,
    kind: enums.ImportExportKind,
};
