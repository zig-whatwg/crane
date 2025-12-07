//! WebIDL dictionary: MemoryAttribution
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const v8 = @import("v8");
const typedefs = @import("typedefs");
const MemoryAttributionContainer = @import("MemoryAttributionContainer.zig").MemoryAttributionContainer;

pub const MemoryAttribution = struct {
    url: ?runtime.USVString = null,
    container: ?MemoryAttributionContainer = null,
    scope: ?runtime.DOMString = null,
};
