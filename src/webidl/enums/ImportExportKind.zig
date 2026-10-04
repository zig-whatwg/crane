//! WebIDL enum: ImportExportKind
//!
//! This file is AUTO-GENERATED. Do not edit manually.

pub const ImportExportKind = enum {
    _function_,
    _table_,
    _memory_,
    _global_,
    _tag_,

    /// Each variant's value exactly as the IDL spells it, by variant index.
    pub const idl_values = [_][]const u8{ "function", "table", "memory", "global", "tag" };
};
