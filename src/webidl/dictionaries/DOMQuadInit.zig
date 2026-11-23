//! WebIDL dictionary: DOMQuadInit
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const DOMPointInit = @import("DOMPointInit.zig").DOMPointInit;

pub const DOMQuadInit = struct {
    /// A WebIDL dictionary (the binding's dictionary rules read this marker).
    pub const webidl_dictionary = true;
    p1: ?DOMPointInit = null,
    p2: ?DOMPointInit = null,
    p3: ?DOMPointInit = null,
    p4: ?DOMPointInit = null,
};
