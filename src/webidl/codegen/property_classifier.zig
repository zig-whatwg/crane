//! Property Classification Heuristics
//!
//! Classifies WebIDL properties as "eager" (define immediately) or "lazy" (define on first access)
//! for performance optimization.

const std = @import("std");

/// Classification result for a property
pub const PropertyClass = enum {
    /// Eager properties: defined immediately, frequently accessed
    eager,

    /// Lazy properties: defined on first access, rarely used
    lazy,
};

/// Classify a property based on its name and extended attributes
pub fn classifyProperty(
    property_name: []const u8,
    extended_attrs: []const []const u8,
) PropertyClass {
    // Check extended attributes first - they take precedence
    for (extended_attrs) |attr| {
        // [CEReactions] and [Reflect] properties are accessed frequently
        if (std.mem.eql(u8, attr, "CEReactions") or
            std.mem.eql(u8, attr, "Reflect"))
        {
            return .eager;
        }
    }

    // Common frequently-accessed properties (eager)
    const eager_properties = &[_][]const u8{
        // Core identity
        "id",
        "className",
        "classList",
        "tagName",
        "nodeName",
        "nodeType",

        // Content
        "textContent",
        "innerHTML",
        "outerHTML",
        "innerText",
        "value",
        "checked",
        "selected",

        // Style
        "style",

        // Common DOM traversal
        "parentNode",
        "parentElement",
        "childNodes",
        "children",
        "firstChild",
        "lastChild",
        "nextSibling",
        "previousSibling",

        // Common attributes
        "href",
        "src",
        "alt",
        "title",
        "type",
        "name",

        // Event handlers (very common)
        "onclick",
        "onload",
        "onerror",
        "onchange",
        "oninput",
    };

    for (eager_properties) |eager_prop| {
        if (std.mem.eql(u8, property_name, eager_prop)) {
            return .eager;
        }
    }

    // Computed layout properties (lazy - expensive to compute)
    const lazy_layout_properties = &[_][]const u8{
        "offsetWidth",
        "offsetHeight",
        "offsetTop",
        "offsetLeft",
        "offsetParent",
        "scrollWidth",
        "scrollHeight",
        "scrollTop",
        "scrollLeft",
        "clientWidth",
        "clientHeight",
        "clientTop",
        "clientLeft",
    };

    for (lazy_layout_properties) |lazy_prop| {
        if (std.mem.eql(u8, property_name, lazy_prop)) {
            return .lazy;
        }
    }

    // Rare/advanced properties (lazy)
    const lazy_advanced_properties = &[_][]const u8{
        "dataset",
        "attributes",
        "namespaceURI",
        "prefix",
        "localName",
        "baseURI",
        "isConnected",
        "ownerDocument",
        "shadowRoot",
        "assignedSlot",
        "slot",
        "tabIndex",
        "accessKey",
        "contentEditable",
        "isContentEditable",
        "draggable",
        "spellcheck",
        "autocapitalize",
        "translate",
        "dir",
        "lang",
        "hidden",
        "inert",
    };

    for (lazy_advanced_properties) |lazy_prop| {
        if (std.mem.eql(u8, property_name, lazy_prop)) {
            return .lazy;
        }
    }

    // Default: properties not explicitly listed are eager
    // This is conservative - we only lazify known rarely-used properties
    return .eager;
}

// =============================================================================
// Tests
// =============================================================================

test "classify common properties as eager" {
    try std.testing.expectEqual(PropertyClass.eager, classifyProperty("id", &.{}));
    try std.testing.expectEqual(PropertyClass.eager, classifyProperty("className", &.{}));
    try std.testing.expectEqual(PropertyClass.eager, classifyProperty("innerHTML", &.{}));
    try std.testing.expectEqual(PropertyClass.eager, classifyProperty("value", &.{}));
}

test "classify layout properties as lazy" {
    try std.testing.expectEqual(PropertyClass.lazy, classifyProperty("offsetWidth", &.{}));
    try std.testing.expectEqual(PropertyClass.lazy, classifyProperty("scrollHeight", &.{}));
    try std.testing.expectEqual(PropertyClass.lazy, classifyProperty("clientTop", &.{}));
}

test "classify advanced properties as lazy" {
    try std.testing.expectEqual(PropertyClass.lazy, classifyProperty("dataset", &.{}));
    try std.testing.expectEqual(PropertyClass.lazy, classifyProperty("namespaceURI", &.{}));
    try std.testing.expectEqual(PropertyClass.lazy, classifyProperty("shadowRoot", &.{}));
}

test "CEReactions attribute makes property eager" {
    try std.testing.expectEqual(PropertyClass.eager, classifyProperty("someProperty", &.{"CEReactions"}));
}

test "Reflect attribute makes property eager" {
    try std.testing.expectEqual(PropertyClass.eager, classifyProperty("someProperty", &.{"Reflect"}));
}

test "unknown properties default to eager" {
    try std.testing.expectEqual(PropertyClass.eager, classifyProperty("unknownProperty", &.{}));
}
