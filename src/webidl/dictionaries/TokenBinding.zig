//! WebIDL dictionary: TokenBinding
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");

pub const TokenBinding = struct {
    /// A WebIDL dictionary (the binding's dictionary rules read this marker).
    pub const webidl_dictionary = true;
    status: runtime.DOMString,
    id: ?runtime.DOMString = null,
};
