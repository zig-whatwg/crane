//! WebIDL dictionary: MutationObserverInit
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const v8 = @import("v8");
const typedefs = @import("typedefs");

pub const MutationObserverInit = struct {
    childList: ?bool = null,
    attributes: ?bool = null,
    characterData: ?bool = null,
    subtree: ?bool = null,
    attributeOldValue: ?bool = null,
    characterDataOldValue: ?bool = null,
    attributeFilter: ?[]const runtime.DOMString = null,
};
