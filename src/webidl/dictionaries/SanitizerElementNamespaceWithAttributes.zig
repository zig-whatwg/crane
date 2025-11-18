//! WebIDL dictionary: SanitizerElementNamespaceWithAttributes
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const SanitizerElementNamespace = @import("SanitizerElementNamespace.zig").SanitizerElementNamespace;

pub const SanitizerElementNamespaceWithAttributes = struct {
    // Inherited from SanitizerElementNamespace
    base: SanitizerElementNamespace,

    attributes: ?anyopaque = null,
    removeAttributes: ?anyopaque = null,
};
