//! WebIDL dictionary: SanitizerConfig
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const typedefs = @import("typedefs");

pub const SanitizerConfig = struct {
    /// A WebIDL dictionary (the binding's dictionary rules read this marker).
    pub const webidl_dictionary = true;
    elements: ?[]const typedefs.SanitizerElementWithAttributes = null,
    removeElements: ?[]const typedefs.SanitizerElement = null,
    replaceWithChildrenElements: ?[]const typedefs.SanitizerElement = null,
    processingInstructions: ?[]const typedefs.SanitizerPI = null,
    removeProcessingInstructions: ?[]const typedefs.SanitizerPI = null,
    attributes: ?[]const typedefs.SanitizerAttribute = null,
    removeAttributes: ?[]const typedefs.SanitizerAttribute = null,
    comments: ?bool = null,
    dataAttributes: ?bool = null,
    javascriptURLs: ?bool = null,
};
