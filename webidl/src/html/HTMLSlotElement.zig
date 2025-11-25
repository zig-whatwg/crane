//! HTMLSlotElement interface per WHATWG HTML Standard
//!
//! Spec: https://html.spec.whatwg.org/multipage/scripting.html#the-slot-element
//!
//! The <slot> element is part of the shadow DOM specification. It defines
//! insertion points within shadow trees where slotted content appears.
//!
//! This element:
//! - Has a "name" attribute for named slots (empty string = default slot)
//! - Tracks assigned nodes (slottables distributed to this slot)
//! - Supports manual slot assignment mode
//! - Fires "slotchange" events when assignments change

const std = @import("std");
const infra = @import("infra");
const webidl = @import("webidl");
const dom = @import("dom");

const Node = dom.Node;
const Element = dom.Element;
const Text = dom.Text;
const ShadowRoot = dom.ShadowRoot;
const Allocator = std.mem.Allocator;

/// AssignedNodesOptions dictionary
/// Spec: https://dom.spec.whatwg.org/#dictdef-assignednodesoptions
pub const AssignedNodesOptions = struct {
    /// If true, returns flattened slottables (recursive slot distribution)
    flatten: bool = false,
};

/// HTMLSlotElement interface
/// Spec: https://html.spec.whatwg.org/multipage/scripting.html#htmlslotelement
///
/// Note: This currently doesn't extend HTMLElement since HTMLElement isn't fully
/// implemented. It extends Element directly. When HTMLElement is available,
/// this should be updated to: pub const extends = HTMLElement;
pub const HTMLSlotElement = webidl.interface(struct {
    pub const extends = Element;

    allocator: Allocator,

    /// Internal list of assigned nodes
    /// Updated by the assign slottables algorithm
    /// DOM §4.8.2.3: A slot has an associated assigned nodes (a list of slottables).
    /// It is initially empty.
    _assigned_nodes: infra.List(*anyopaque),

    /// Internal list of manually assigned nodes
    /// For manual slot assignment mode
    /// DOM §4.8.2.5: A slot has manually assigned nodes (an ordered set of slottables).
    /// It is initially empty.
    _manually_assigned_nodes: infra.List(*anyopaque),

    /// Initialize a new HTMLSlotElement
    pub fn init(allocator: Allocator) !HTMLSlotElement {
        return .{
            // Inherited from EventTarget
            .event_listener_list = null,
            // Inherited from Node
            .allocator = allocator,
            .node_type = Node.ELEMENT_NODE,
            .node_name = "SLOT",
            .parent_node = null,
            .child_nodes = infra.List(*Node).init(allocator),
            .owner_document = null,
            .registered_observers = infra.List(@import("registered_observer").RegisteredObserver).init(allocator),
            .cloning_steps_hook = null,
            .cached_child_nodes = null,
            // Inherited from Element
            .tag_name = "SLOT",
            .namespace_uri = "http://www.w3.org/1999/xhtml", // HTML namespace
            .prefix = null,
            .local_name = "slot",
            .attributes = infra.List(@import("attr").Attr).init(allocator),
            .shadow_root = null,
            .custom_element_state = .undefined,
            .is_value = null,
            .cached_class_list = null,
            .cached_attributes = null,
            // Slottable mixin fields (from Element)
            .slottable_name = "",
            .assigned_slot = null,
            .manual_slot_assignment = null,
            // HTMLSlotElement own fields
            ._assigned_nodes = infra.List(*anyopaque).init(allocator),
            ._manually_assigned_nodes = infra.List(*anyopaque).init(allocator),
        };
    }

    pub fn deinit(self: *HTMLSlotElement) void {
        self._assigned_nodes.deinit();
        self._manually_assigned_nodes.deinit();
        // Parent Element cleanup
        self.child_nodes.deinit();
        self.registered_observers.deinit();
        self.attributes.deinit();
        if (self.cached_child_nodes) |list| {
            list.deinit();
            self.allocator.destroy(list);
        }
    }

    // ========================================================================
    // Attributes
    // ========================================================================

    /// HTML §4.12.1 - HTMLSlotElement.name
    ///
    /// The name content attribute is used to assign slots to other elements:
    /// slottables with a slot attribute whose value matches a slot element's
    /// name are assigned to that slot.
    ///
    /// Spec: https://html.spec.whatwg.org/multipage/scripting.html#attr-slot-name
    pub fn get_name(self: *const HTMLSlotElement) []const u8 {
        // Get the "name" attribute value
        if (self.call_getAttribute("name")) |name| {
            return name;
        }
        return ""; // Default slot has empty name
    }

    pub fn set_name(self: *HTMLSlotElement, value: []const u8) !void {
        try self.call_setAttribute("name", value);
    }

    // ========================================================================
    // Methods
    // ========================================================================

    /// HTML §4.12.1 - HTMLSlotElement.assignedNodes(options)
    ///
    /// Returns the nodes assigned to this slot.
    /// If options.flatten is true, returns flattened slottables.
    ///
    /// Spec: https://html.spec.whatwg.org/multipage/scripting.html#dom-slot-assignednodes
    pub fn call_assignedNodes(self: *HTMLSlotElement, options: ?AssignedNodesOptions) ![]*Node {
        const opts = options orelse AssignedNodesOptions{};

        if (opts.flatten) {
            // Return flattened slottables
            var flattened = try dom.shadow_dom_algorithms.findFlattenedSlottables(
                self.allocator,
                @ptrCast(self),
            );
            defer flattened.deinit();

            // Convert to []*Node
            const result = try self.allocator.alloc(*Node, flattened.len);
            for (flattened.toSlice(), 0..) |item, i| {
                result[i] = @ptrCast(@alignCast(item));
            }
            return result;
        } else {
            // Return assigned nodes directly
            const result = try self.allocator.alloc(*Node, self._assigned_nodes.len);
            for (self._assigned_nodes.toSlice(), 0..) |item, i| {
                result[i] = @ptrCast(@alignCast(item));
            }
            return result;
        }
    }

    /// HTML §4.12.1 - HTMLSlotElement.assignedElements(options)
    ///
    /// Returns the elements assigned to this slot (filters out Text nodes).
    /// If options.flatten is true, returns flattened slottables.
    ///
    /// Spec: https://html.spec.whatwg.org/multipage/scripting.html#dom-slot-assignedelements
    pub fn call_assignedElements(self: *HTMLSlotElement, options: ?AssignedNodesOptions) ![]*Element {
        const nodes = try self.call_assignedNodes(options);
        defer self.allocator.free(nodes);

        // Count elements
        var count: usize = 0;
        for (nodes) |node| {
            if (node.node_type == Node.ELEMENT_NODE) {
                count += 1;
            }
        }

        // Allocate and fill result
        const result = try self.allocator.alloc(*Element, count);
        var i: usize = 0;
        for (nodes) |node| {
            if (node.node_type == Node.ELEMENT_NODE) {
                result[i] = @ptrCast(node);
                i += 1;
            }
        }

        return result;
    }

    /// HTML §4.12.1 - HTMLSlotElement.assign(nodes...)
    ///
    /// Manually assigns slottables to this slot.
    /// Only valid when shadow root's slot assignment mode is "manual".
    ///
    /// Spec: https://html.spec.whatwg.org/multipage/scripting.html#dom-slot-assign
    pub fn call_assign(self: *HTMLSlotElement, nodes: []const *anyopaque) !void {
        // Step 1: For each node of this's manually assigned nodes,
        // set node's manual slot assignment to null
        for (self._manually_assigned_nodes.toSlice()) |node| {
            dom.slot_helpers.setSlottableManualAssignment(node, null);
        }

        // Step 2: Empty this's manually assigned nodes
        self._manually_assigned_nodes.clearRetainingCapacity();

        // Step 3: For each node of nodes:
        for (nodes) |node| {
            // Step 3.1: If node's manual slot assignment refers to a slot,
            // remove node from that slot's manually assigned nodes
            if (dom.slot_helpers.getSlottableManualAssignment(node)) |old_slot| {
                const old_slot_element: *HTMLSlotElement = @ptrCast(@alignCast(old_slot));
                old_slot_element.removeFromManuallyAssignedNodes(node);
            }

            // Step 3.2: Set node's manual slot assignment to this
            dom.slot_helpers.setSlottableManualAssignment(node, @ptrCast(self));

            // Step 3.3: Append node to this's manually assigned nodes
            try self._manually_assigned_nodes.append(node);
        }

        // Step 4: Run assign slottables for a tree with this's root
        const root = dom.slot_helpers.getRoot(@ptrCast(self));
        try dom.shadow_dom_algorithms.assignSlottablesForTree(self.allocator, root);
    }

    // ========================================================================
    // Internal Methods
    // ========================================================================

    /// Get the internal assigned nodes list
    pub fn getAssignedNodesList(self: *HTMLSlotElement) *infra.List(*anyopaque) {
        return &self._assigned_nodes;
    }

    /// Get the internal manually assigned nodes list
    pub fn getManuallyAssignedNodesList(self: *HTMLSlotElement) *infra.List(*anyopaque) {
        return &self._manually_assigned_nodes;
    }

    /// Set the assigned nodes list (called by assign slottables algorithm)
    pub fn setAssignedNodes(self: *HTMLSlotElement, nodes: []const *anyopaque) !void {
        self._assigned_nodes.clearRetainingCapacity();
        for (nodes) |node| {
            try self._assigned_nodes.append(node);
        }
    }

    /// Remove a node from manually assigned nodes
    fn removeFromManuallyAssignedNodes(self: *HTMLSlotElement, node: *anyopaque) void {
        var i: usize = 0;
        while (i < self._manually_assigned_nodes.len) {
            if (self._manually_assigned_nodes.get(i)) |item| {
                if (item == node) {
                    _ = self._manually_assigned_nodes.remove(i) catch return;
                    return;
                }
            }
            i += 1;
        }
    }

    /// Check if slot has any assigned content
    pub fn hasAssignedNodes(self: *const HTMLSlotElement) bool {
        return self._assigned_nodes.len > 0;
    }
}, .{
    .exposed = &.{.Window},
});

// ============================================================================
// Tests
// ============================================================================

test "HTMLSlotElement: default name is empty string" {
    const allocator = std.testing.allocator;

    var slot = try HTMLSlotElement.init(allocator);
    defer slot.deinit();

    try std.testing.expectEqualStrings("", slot.get_name());
}
