//! WebIDL dictionary: MemoryAttribution
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const MemoryAttributionContainer = @import("MemoryAttributionContainer.zig").MemoryAttributionContainer;

pub const MemoryAttribution = struct {
    /// A WebIDL dictionary (the binding's dictionary rules read this marker).
    pub const webidl_dictionary = true;
    url: ?runtime.USVString = null,
    container: ?MemoryAttributionContainer = null,
    scope: ?runtime.DOMString = null,
};
