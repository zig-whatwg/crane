//! WebIDL dictionary: SanitizerConfig
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");

pub const SanitizerConfig = struct {
    elements: ?*const anyopaque = null,
    removeElements: ?*const anyopaque = null,
    replaceWithChildrenElements: ?*const anyopaque = null,
    attributes: ?*const anyopaque = null,
    removeAttributes: ?*const anyopaque = null,
    comments: ?bool = null,
    dataAttributes: ?bool = null,
};
