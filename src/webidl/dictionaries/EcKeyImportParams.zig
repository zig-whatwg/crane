//! WebIDL dictionary: EcKeyImportParams
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const v8 = @import("v8");
const typedefs = @import("typedefs");
const Algorithm = @import("Algorithm.zig").Algorithm;

pub const EcKeyImportParams = struct {
    // Inherited from Algorithm
    base: Algorithm,

    namedCurve: typedefs.NamedCurve,
};
