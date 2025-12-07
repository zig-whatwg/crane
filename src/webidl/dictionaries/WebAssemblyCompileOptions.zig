//! WebIDL dictionary: WebAssemblyCompileOptions
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const v8 = @import("v8");

pub const WebAssemblyCompileOptions = struct {
    importedStringConstants: ?runtime.USVString = null,
    builtins: ?[]const runtime.USVString = null,
};
