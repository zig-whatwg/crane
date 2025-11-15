//! DOM Attribute Algorithms (WHATWG DOM Standard §4.9)
//!
//! Spec: https://dom.spec.whatwg.org/#interface-element
//!
//! This module implements the complete set of attribute algorithms for DOM elements.
//! All algorithms follow the WHATWG DOM specification precisely.

const std = @import("std");
const infra = @import("infra");
const Attr = @import("attr").Attr;
const Element = @import("element").Element;
const Node = @import("node").Node;
const mutation_observer = @import("mutation_observer_algorithms.zig");

// HTML custom elements stub (inline to avoid module path issues)
const custom_elements = struct {
    pub fn enqueueCustomElementCallbackReaction(
        element: anytype,
        callback_name: []const u8,
        args: anytype,
    ) void {
        _ = element;
        _ = callback_name;
        _ = args;
        // TODO(HTML): Implement custom element reactions
        // This is a stub - no custom elements supported yet
    }
};

/// Handle attribute changes for an attribute
/// Spec: https://dom.spec.whatwg.org/#handle-attribute-changes
///
/// Arguments:
///   - attribute: The attribute that changed
///   - element: The element owning the attribute
///   - old_value: The old value (null if attribute was just added)
///   - new_value: The new value (null if attribute was just removed)
pub fn handleAttributeChanges(
    attribute: *Attr,
    element: *Element,
    old_value: ?[]const u8,
    new_value: ?[]const u8,
) !void {
    // Step 1: Queue a mutation record of "attributes" for element
    // with attribute's local name, attribute's namespace, oldValue, « », « », null, and null

    // Note: We need to create empty node lists for added/removed nodes
    const allocator = element.allocator;
    const NodeList = @import("node_list").NodeList;
    var empty_added = try NodeList.init(allocator);
    defer empty_added.deinit();
    var empty_removed = try NodeList.init(allocator);
    defer empty_removed.deinit();

    try mutation_observer.queueMutationRecord(
        allocator,
        "attributes",
        element.asNode(),
        attribute.local_name,
        attribute.namespace_uri,
        old_value,
        &empty_added,
        &empty_removed,
        null,
        null,
    );

    // Step 2: If element is custom, enqueue a custom element callback reaction
    // with element, callback name "attributeChangedCallback",
    // and « attribute's local name, oldValue, newValue, attribute's namespace »

    // TODO(HTML): Check if element is custom once we have custom element support
    // For now, we call the stub which is a no-op
    custom_elements.enqueueCustomElementCallbackReaction(
        element,
        "attributeChangedCallback",
        .{ attribute.local_name, old_value, new_value, attribute.namespace_uri },
    );

    // Step 3: Run the attribute change steps
    // with element, attribute's local name, oldValue, newValue, and attribute's namespace
    try runAttributeChangeSteps(
        element,
        attribute.local_name,
        old_value,
        new_value,
        attribute.namespace_uri,
    );
}

/// Run attribute change steps (extension point for specifications)
/// Spec: https://dom.spec.whatwg.org/#concept-element-attributes-change-ext
///
/// This includes the ID attribute change steps defined in the DOM spec.
fn runAttributeChangeSteps(
    element: *Element,
    local_name: []const u8,
    old_value: ?[]const u8,
    new_value: ?[]const u8,
    namespace: ?[]const u8,
) !void {
    // ID attribute change steps (Spec §4.9, lines 4163-4167)

    // Step 1: If localName is "id", namespace is null,
    // and value is null or the empty string, then unset element's ID
    if (std.mem.eql(u8, local_name, "id") and namespace == null) {
        if (new_value == null or new_value.?.len == 0) {
            element.unique_id = null;
        }
        // Step 2: Otherwise, if localName is "id", namespace is null,
        // then set element's ID to value
        else {
            // Store the ID value (needs to be heap-allocated for lifetime)
            const allocator = element.allocator;
            if (element.unique_id) |old_id| {
                allocator.free(old_id);
            }
            element.unique_id = try allocator.dupe(u8, new_value.?);
        }
    }

    // TODO(DOM): Other specs may define additional attribute change steps
    // For example:
    // - class attribute: Update DOMTokenList
    // - slot attribute: Signal slot change
    // - HTML-specific attributes: Update element state

    _ = old_value; // May be used by other attribute change steps
}

/// Change an attribute to a value
/// Spec: https://dom.spec.whatwg.org/#concept-element-attributes-change
pub fn changeAttribute(
    attribute: *Attr,
    value: []const u8,
) !void {
    // Step 1: Let oldValue be attribute's value
    const old_value = attribute.value;

    // Step 2: Set attribute's value to value
    try attribute.setValue(value);

    // Step 3: Handle attribute changes for attribute
    // with attribute's element, oldValue, and value
    if (attribute.owner_element) |owner_ptr| {
        const element: *Element = @ptrCast(@alignCast(owner_ptr));
        try handleAttributeChanges(attribute, element, old_value, value);
    }
}

/// Append an attribute to an element
/// Spec: https://dom.spec.whatwg.org/#concept-element-attributes-append
pub fn appendAttribute(
    attribute: *Attr,
    element: *Element,
) !void {
    // Step 1: Append attribute to element's attribute list
    try element.attributes.append(attribute.*);

    // Step 2: Set attribute's element to element
    attribute.owner_element = element;

    // Step 3: Set attribute's node document to element's node document
    attribute.owner_document = element.owner_document;

    // Step 4: Handle attribute changes for attribute
    // with element, null, and attribute's value
    try handleAttributeChanges(attribute, element, null, attribute.value);
}

/// Remove an attribute
/// Spec: https://dom.spec.whatwg.org/#concept-element-attributes-remove
pub fn removeAttribute(
    attribute: *Attr,
) !void {
    // Step 1: Let element be attribute's element
    const element: *Element = @ptrCast(@alignCast(attribute.owner_element.?));

    // Store old value before removal
    const old_value = attribute.value;

    // Step 2: Remove attribute from element's attribute list
    var found_index: ?usize = null;
    for (0..element.attributes.size()) |i| {
        if (element.attributes.get(i)) |attr| {
            if (attr == attribute) {
                found_index = i;
                break;
            }
        }
    }

    if (found_index) |index| {
        _ = element.attributes.remove(index);
    }

    // Step 3: Set attribute's element to null
    attribute.owner_element = null;

    // Step 4: Handle attribute changes for attribute
    // with element, attribute's value, and null
    try handleAttributeChanges(attribute, element, old_value, null);
}

/// Replace an oldAttribute with a newAttribute
/// Spec: https://dom.spec.whatwg.org/#concept-element-attributes-replace
pub fn replaceAttribute(
    old_attribute: *Attr,
    new_attribute: *Attr,
) !void {
    // Step 1: Let element be oldAttribute's element
    const element: *Element = @ptrCast(@alignCast(old_attribute.owner_element.?));

    // Find the index of oldAttribute
    var found_index: ?usize = null;
    for (0..element.attributes.size()) |i| {
        if (element.attributes.get(i)) |attr| {
            if (attr == old_attribute) {
                found_index = i;
                break;
            }
        }
    }

    if (found_index) |index| {
        // Step 2: Replace oldAttribute by newAttribute in element's attribute list
        _ = element.attributes.remove(index);
        try element.attributes.insert(index, new_attribute);
    }

    // Step 3: Set newAttribute's element to element
    new_attribute.owner_element = element;

    // Step 4: Set newAttribute's node document to element's node document
    new_attribute.owner_document = element.owner_document;

    // Step 5: Set oldAttribute's element to null
    old_attribute.owner_element = null;

    // Step 6: Handle attribute changes for oldAttribute
    // with element, oldAttribute's value, and newAttribute's value
    try handleAttributeChanges(
        old_attribute,
        element,
        old_attribute.value,
        new_attribute.value,
    );
}

/// Set an attribute value
/// Spec: https://dom.spec.whatwg.org/#concept-element-attributes-set-value
///
/// This is a higher-level operation that creates or updates an attribute.
pub fn setAttributeValue(
    element: *Element,
    local_name: []const u8,
    value: []const u8,
    prefix: ?[]const u8,
    namespace: ?[]const u8,
) !void {
    const allocator = element.allocator;

    // Step 1: Let attribute be the result of getting an attribute
    // given namespace, localName, and element
    const attribute = getAttributeByNamespaceAndLocalName(element, namespace, local_name);

    // Step 2: If attribute is null, create an attribute whose namespace is namespace,
    // namespace prefix is prefix, local name is localName, value is value,
    // and node document is element's node document, then append this attribute to element, and then return
    if (attribute == null) {
        const new_attr = try allocator.create(Attr);
        errdefer allocator.destroy(new_attr);

        new_attr.* = try Attr.init(
            allocator,
            local_name,
            value,
            namespace,
            prefix,
        );

        try appendAttribute(new_attr, element);
        return;
    }

    // Step 3: Change attribute to value
    try changeAttribute(attribute.?, value);
}

/// Get an attribute by namespace and local name
/// Spec: https://dom.spec.whatwg.org/#concept-element-attributes-get-by-namespace
fn getAttributeByNamespaceAndLocalName(
    element: *const Element,
    namespace: ?[]const u8,
    local_name: []const u8,
) ?*Attr {
    // Step 1: If namespace is the empty string, then set it to null
    const ns = if (namespace) |n| (if (n.len == 0) null else namespace) else null;

    // Step 2: Return the attribute in element's attribute list
    // whose namespace is namespace and local name is localName, if any; otherwise null
    for (0..element.attributes.size()) |i| {
        if (element.attributes.get(i)) |attr| {
            const attr_ns_matches = if (ns == null and attr.namespace_uri == null)
                true
            else if (ns != null and attr.namespace_uri != null)
                std.mem.eql(u8, ns.?, attr.namespace_uri.?)
            else
                false;

            if (attr_ns_matches and std.mem.eql(u8, attr.local_name, local_name)) {
                return attr;
            }
        }
    }

    return null;
}
