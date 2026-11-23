//! WebIDL dictionary: CollectedClientData
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");

pub const CollectedClientData = struct {
    /// A WebIDL dictionary (the binding's dictionary rules read this marker).
    pub const webidl_dictionary = true;
    type: runtime.DOMString,
    challenge: runtime.DOMString,
    origin: runtime.DOMString,
    crossOrigin: ?bool = null,
    topOrigin: ?runtime.DOMString = null,
};
