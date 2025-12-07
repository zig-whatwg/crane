//! WebIDL dictionary: ImportNodeOptions
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const v8 = @import("v8");

pub const ImportNodeOptions = struct {
    customElementRegistry: ?*runtime.Instance = null,
    selfOnly: ?bool = null,
};
