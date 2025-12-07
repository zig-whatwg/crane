//! WebIDL dictionary: SanitizerElementNamespaceWithAttributes
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const typedefs = @import("typedefs");
const SanitizerElementNamespace = @import("SanitizerElementNamespace.zig").SanitizerElementNamespace;

pub const SanitizerElementNamespaceWithAttributes = struct {
    // Inherited from SanitizerElementNamespace
    base: SanitizerElementNamespace,

    attributes: ?[]const typedefs.SanitizerAttribute = null,
    removeAttributes: ?[]const typedefs.SanitizerAttribute = null,
};
