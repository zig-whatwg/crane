//! WebIDL dictionary: DOMMatrixInit
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const DOMMatrix2DInit = @import("DOMMatrix2DInit.zig").DOMMatrix2DInit;

pub const DOMMatrixInit = struct {
    // Inherited from DOMMatrix2DInit
    base: DOMMatrix2DInit,

    m13: ?f64 = null,
    m14: ?f64 = null,
    m23: ?f64 = null,
    m24: ?f64 = null,
    m31: ?f64 = null,
    m32: ?f64 = null,
    m33: ?f64 = null,
    m34: ?f64 = null,
    m43: ?f64 = null,
    m44: ?f64 = null,
    is2D: ?bool = null,
};
