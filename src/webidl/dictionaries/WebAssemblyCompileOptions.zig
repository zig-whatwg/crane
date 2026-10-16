//! WebIDL dictionary: WebAssemblyCompileOptions
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");

pub const WebAssemblyCompileOptions = struct {
    importedStringConstants: ?runtime.USVString = null,
    builtins: ?[]const runtime.USVString = null,

    /// Optional members whose IDL type is nullable: a present null is the
    /// value null. Any other member's present null converts by its type.
    pub const nullable_members = .{"importedStringConstants"};
};
