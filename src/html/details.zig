//! HTML details and summary algorithms shared by input and fragment navigation.
const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const dom = @import("dom");
const form_associated = @import("form_associated.zig");

fn isSummary(node: *runtime.Instance) bool {
    const names = dom.node_creation.elementNames(node) orelse return false;
    return std.mem.eql(u8, names.local_name, "summary") and
        std.mem.eql(u8, names.namespace orelse "", "http://www.w3.org/1999/xhtml");
}

/// A summary represents its parent details' legend only when it is the first
/// summary child. Other elements before that summary do not disqualify it.
pub fn isSummaryForParentDetails(element: *runtime.Instance) bool {
    if (!isSummary(element)) return false;
    const parent = form_associated.parentOf(element) orelse return false;
    if (parent.stateAs(interfaces.HTMLDetailsElement.State) == null) return false;
    var child = interfaces.Node.get_firstChild(parent) catch null;
    while (child) |node| : (child = interfaces.Node.get_nextSibling(node) catch null) {
        if (isSummary(node)) return node == element;
    }
    return false;
}

pub fn installHooks() void {
    dom.ancestor_revealing.install(&reveal);
}

fn flatParent(node: *runtime.Instance) ?*runtime.Instance {
    if (dom.shadow_dom_algorithms.assignedSlotOf(node)) |slot| return slot;
    const parent = form_associated.parentOf(node) orelse return null;
    if (parent.stateAs(interfaces.ShadowRoot.State) != null) return interfaces.ShadowRoot.get_host(parent) catch null;
    if (dom.instance_bridge.getNodeBase(parent)) |base| {
        // Unassigned light children and hidden slot fallback are absent
        // from the flat tree (CSS Scoping 2.1).
        if (base.is_shadow_host) return null;
        if (dom.slot_helpers.slotState(base)) |slot| if (slot.hasAssignedNodes()) return null;
    }
    return parent;
}

fn reveal(target: *runtime.Instance) void {
    revealWithAllocator(target.ctx.allocator, target) catch {};
}

/// HTML ancestor revealing, details pairs (steps 1–4). Hidden-until-found
/// revealing has a separate beforematch algorithm and is not implemented here.
pub fn revealWithAllocator(allocator: std.mem.Allocator, target: *runtime.Instance) !void {
    var ancestors: std.ArrayList(*runtime.Instance) = .empty;
    defer ancestors.deinit(allocator);
    var ancestor = target;
    while (flatParent(ancestor)) |parent| : (ancestor = parent) {
        // The details UA shadow tree's second slot contains every child
        // except its first summary. Crane represents those slots implicitly.
        if (parent.stateAs(interfaces.HTMLDetailsElement.State) != null and
            !isSummaryForParentDetails(ancestor) and
            !form_associated.hasAttribute(parent, "open"))
        {
            try ancestors.append(allocator, parent);
        }
    }
    // No script runs while this borrowed list is live: the internal DOM
    // attribute algorithm enqueues reactions, without an IDL reaction scope.
    for (ancestors.items) |details| {
        // 4.1 and 4.3: stop on disconnected/already-open ancestors.
        if (!(try interfaces.Node.get_isConnected(details))) return;
        if (form_associated.hasAttribute(details, "open")) return;
        try dom.element_attributes.set(details, "open", "", .{});
    }
}
