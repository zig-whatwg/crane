//! Attr interface per WHATWG DOM Standard
//! Spec: https://dom.spec.whatwg.org/#interface-attr
//! DOM §4.9

const std = @import("std");
const webidl = @import("webidl");
const infra = @import("infra");
const Node = @import("node").Node;
const Element = @import("element").Element;
const ShadowRoot = @import("shadow_root").ShadowRoot;

/// DOM §4.9 - Attr interface
/// Attr nodes represent attributes.
/// Attributes have a namespace, namespace prefix, local name, value, and element.
pub const Attr = webidl.interface(struct {
    pub const extends = Node;

    allocator: std.mem.Allocator,
    /// The attribute's namespace (null or a non-empty string)
    namespace_uri: ?[]const u8,
    /// The attribute's namespace prefix (null or a non-empty string)
    prefix: ?[]const u8,
    /// The attribute's local name (a non-empty string)
    local_name: []const u8,
    /// The attribute's value (a string)
    value: []u8,
    /// The element this attribute belongs to (null or an element)
    owner_element: ?*Element,

    pub fn init(
        allocator: std.mem.Allocator,
        namespace_uri: ?[]const u8,
        prefix: ?[]const u8,
        local_name: []const u8,
        value: []const u8,
    ) !Attr {
        return .{
            .event_listener_list = null, // From EventTarget
            .node_type = 2, // ATTRIBUTE_NODE
            .node_name = local_name, // Per DOM spec, Attr's nodeName is its localName
            .parent_node = null,
            .child_nodes = infra.List(*Node).init(allocator),
            .owner_document = null,
            .registered_observers = infra.List(@import("registered_observer").RegisteredObserver).init(allocator),
            .cloning_steps_hook = null,
            .cached_child_nodes = null,
            .allocator = allocator,
            .namespace_uri = if (namespace_uri) |ns| try allocator.dupe(u8, ns) else null,
            .prefix = if (prefix) |p| try allocator.dupe(u8, p) else null,
            .local_name = try allocator.dupe(u8, local_name),
            .value = try allocator.dupe(u8, value),
            .owner_element = null,
        };
    }

    pub fn deinit(self: *Attr) void {
        if (self.namespace_uri) |ns| self.allocator.free(ns);
        if (self.prefix) |p| self.allocator.free(p);
        self.allocator.free(self.local_name);
        self.allocator.free(self.value);
        // NOTE: Parent Node cleanup is handled by codegen
    }

    /// DOM §4.9 - namespaceURI getter
    /// Returns this's namespace.
    pub fn get_namespaceURI(self: *const Attr) ?[]const u8 {
        return self.namespace_uri;
    }

    /// DOM §4.9 - prefix getter
    /// Returns this's namespace prefix.
    pub fn get_prefix(self: *const Attr) ?[]const u8 {
        return self.prefix;
    }

    /// DOM §4.9 - localName getter
    /// Returns this's local name.
    pub fn get_localName(self: *const Attr) []const u8 {
        return self.local_name;
    }

    /// DOM §4.9 - name getter
    /// Returns this's qualified name.
    /// The qualified name is local name if namespace prefix is null,
    /// otherwise it's prefix + ":" + local name.
    pub fn get_name(self: *const Attr) ![]const u8 {
        if (self.prefix) |p| {
            // Qualified name: prefix + ":" + localName
            const qualified = try std.fmt.allocPrint(
                self.allocator,
                "{s}:{s}",
                .{ p, self.local_name },
            );
            return qualified;
        }
        // No prefix, just return local name
        return self.local_name;
    }

    /// DOM §4.9 - value getter
    /// Returns this's value.
    pub fn get_value(self: *const Attr) []const u8 {
        return self.value;
    }

    /// DOM §4.9 - value setter
    /// Sets this's value.
    /// Steps: Set an existing attribute value with this and the given value.
    pub fn set_value(self: *Attr, new_value: []const u8) !void {
        try Attr.setExistingAttributeValue(self, new_value);
    }

    /// Set an existing attribute value - DOM Spec algorithm
    pub fn setExistingAttributeValue(attribute: *Attr, value: []const u8) !void {
        // Step 1: If attribute's element is null, set attribute's value
        if (attribute.owner_element == null) {
            attribute.allocator.free(attribute.value);
            attribute.value = try attribute.allocator.dupe(u8, value);
            return;
        }

        // Step 2: Otherwise, change attribute to value
        try Attr.changeAttribute(attribute, value);
    }

    /// Change an attribute - DOM Spec algorithm
    pub fn changeAttribute(attribute: *Attr, value: []const u8) !void {
        // Step 1: Let oldValue be attribute's value
        const old_value = attribute.value;

        // Step 2: Set attribute's value to value
        attribute.value = try attribute.allocator.dupe(u8, value);

        // Free old value after duplication succeeds
        attribute.allocator.free(old_value);

        // Step 3: Handle attribute changes
        try Attr.handleAttributeChanges(attribute, attribute.owner_element.?, old_value, value);
    }

    /// Handle attribute changes - DOM Spec algorithm
    pub fn handleAttributeChanges(
        attribute: *Attr,
        element: *Element,
        old_value: ?[]const u8,
        new_value: []const u8,
    ) !void {
        // Step 1: Queue a mutation record of "attributes"
        const mutation = @import("mutation");
        const empty_nodes: []const *@import("node").Node = &[_]*@import("node").Node{};
        try mutation.queueMutationRecord(
            "attributes",
            &element.base,
            attribute.local_name,
            attribute.namespace_uri,
            old_value,
            empty_nodes,
            empty_nodes,
            null,
            null,
        );

        // Step 2: If element is custom, enqueue custom element callback reaction
        // NOTE: Custom element callback requires custom elements implementation
        _ = new_value;

        // Step 3: Run the attribute change steps
        // Extension point for HTML, SVG, etc. to define attribute-specific behavior
        // Currently no attribute change steps defined for base DOM
        // Note: attribute parameter is used above (lines 144-145), no discard needed
    }

    /// DOM §4.9 - ownerElement getter
    /// Returns this's element.
    pub fn get_ownerElement(self: *const Attr) ?*Element {
        return self.owner_element;
    }

    /// DOM §4.9 - specified getter
    /// Always returns true (this is a legacy attribute).
    pub fn get_specified(self: *const Attr) bool {
        _ = self;
        return true;
    }
}, .{
    .exposed = &.{.Window},
});
