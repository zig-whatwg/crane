//! HTML 6.6.2/6.6.5 focus navigation scopes and sequential search.
//!
//! Scope-local search implements the flattened tabindex order without
//! storing it or imposing a bound on the number of focusable elements.
//! All cursors borrow nodes only during native reads, before focusing can
//! dispatch script. Design reference: Blink FocusNavigation and
//! ScopedFocusNavigation, focus_controller.cc at 8d5ba1795f0c50b90072399d0403389df6eebbd6.
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const dom = @import("dom");
const focus = @import("focus.zig");
const associated = @import("form_associated.zig");
const radio_focus = @import("forms/radio_focus.zig");

const Instance = runtime.Instance;
const Direction = focus.Direction;

fn parent(node: *Instance) ?*Instance {
    return interfaces.Node.get_parentNode(node) catch null;
}

fn instanceOf(node: *dom.NodeBase) ?*Instance {
    return @ptrCast(@alignCast(node.owner_instance orelse return null));
}

fn slotState(node: *Instance) ?*dom.slot_helpers.SlotState {
    const base = dom.instance_bridge.getNodeBase(node) orelse return null;
    return dom.slot_helpers.slotState(base);
}

fn isSlot(node: *Instance) bool {
    return node.vtable == &interfaces.HTMLSlotElement.vtable;
}

fn ownsTree(node: *Instance) bool {
    return isSlot(node) or dom.shadow_hosts.rootForHost(node) != null;
}

/// The root whose descendants belong to one owner's scope. Assigned slot
/// contents have several subtree roots; fallback uses the slot's children.
const Scope = struct {
    root: *Instance,
    owner: ?*Instance = null,
    assigned: ?*dom.slot_helpers.SlotState = null,

    fn ownedBy(owner: *Instance) Scope {
        if (dom.shadow_hosts.rootForHost(owner)) |root| return .{ .root = root, .owner = owner };
        if (slotState(owner)) |slot| {
            return .{ .root = owner, .owner = owner, .assigned = if (slot.hasAssignedNodes()) slot else null };
        }
        return .{ .root = owner, .owner = owner };
    }

    fn tree(self: Scope) *Instance {
        if (self.assigned) |slot| {
            for (slot.assigned_nodes.items) |ref| {
                const node = ref.get() orelse continue;
                return associated.rootOf(instanceOf(node) orelse continue);
            }
        }
        return associated.rootOf(self.root);
    }
};

/// Shadow-including tree order, without an allocated flattened node list.
fn nextIncludingShadow(node: *Instance, document: *Instance) ?*Instance {
    if (dom.shadow_hosts.rootForHost(node)) |root| {
        if (interfaces.Node.get_firstChild(root) catch null) |child| return child;
    }
    if (interfaces.Node.get_firstChild(node) catch null) |child| return child;
    var current = node;
    while (current != document) {
        if (interfaces.Node.get_nextSibling(current) catch null) |sibling| return sibling;
        const p = parent(current) orelse return null;
        if (p.stateAs(interfaces.ShadowRoot.State) != null) {
            const host = interfaces.ShadowRoot.get_host(p) catch return null;
            if (interfaces.Node.get_firstChild(host) catch null) |child| return child;
            current = host;
        } else current = p;
    }
    return null;
}

const Iterator = struct {
    scope: Scope,
    current: ?*Instance = null,
    boundary: *Instance,
    assigned_index: usize = 0,
    search: *Search,

    fn init(scope: Scope, searcher: *Search) Iterator {
        var result = Iterator{ .scope = scope, .boundary = scope.root, .search = searcher };
        if (searcher.popovers != null) {
            result.current = interfaces.Node.get_firstChild(searcher.document) catch null;
            return result;
        }
        result.current = if (scope.assigned != null) result.nextAssigned() else interfaces.Node.get_firstChild(scope.root) catch null;
        return result;
    }

    fn nextAssigned(self: *Iterator) ?*Instance {
        const slot = self.scope.assigned orelse return null;
        while (self.assigned_index < slot.assigned_nodes.items.len) {
            const ref = slot.assigned_nodes.items[self.assigned_index];
            self.assigned_index += 1;
            const node = instanceOf(ref.get() orelse continue) orelse continue;
            self.boundary = node;
            return node;
        }
        return null;
    }

    fn next(self: *Iterator) ?*Instance {
        if (self.search.popovers != null) {
            // A host that also invokes a popover orders both scope parts in
            // shadow-including tree order. Chrome/Safari visit its shadow
            // children first (WPT ffc4686d11); HTML issue #12871 / PR #12916
            // propose a different order but remain open (2026-10-27).
            while (self.current) |node| {
                self.current = nextIncludingShadow(node, self.search.document);
                if (!associated.isElement(node)) continue;
                const scope = self.search.scopeOf(node) orelse continue;
                if (scope.owner == self.scope.owner) return node;
            }
            return null;
        }
        const result = self.current orelse return null;
        // A nested owner belongs to this scope; its descendants belong to
        // its own scope, entered only by the flattening step below.
        self.current = associated.nextInTree(result, self.boundary, ownsTree(result));
        if (self.current == null and self.scope.assigned != null) self.current = self.nextAssigned();
        return result;
    }
};

// Positive tabindex precedes zero/null. u32 covers every positive IDL long
// and leaves the final rank for zero, without an artificial element limit.
fn rank(value: i32) u32 {
    return if (value > 0) @intCast(value) else 0x80000000;
}

const Search = struct {
    document: *Instance,
    radios: radio_focus.Navigation,
    popovers: ?*dom.top_layer.State,

    /// Blink InvokerForOpenPopover: an invoker in its own popover does not
    /// create a scope edge. All reads borrow existing document-owned state.
    fn invoker(self: *Search, popover: *Instance) ?*Instance {
        const state = self.popovers orelse return null;
        const entry = state.find(popover) orelse return null;
        const source = entry.source.get() orelse return null;
        var current: ?*Instance = source;
        while (current) |node| {
            if (node == popover) return null;
            current = dom.shadow_dom_algorithms.assignedSlotOf(node) orelse parent(node);
            if (current) |p| {
                if (p.stateAs(interfaces.ShadowRoot.State) != null)
                    current = interfaces.ShadowRoot.get_host(p) catch null;
            }
        }
        return source;
    }

    fn isOwner(self: *Search, node: *Instance) bool {
        if (ownsTree(node)) return true;
        const state = self.popovers orelse return false;
        for (state.entries.items) |entry| {
            if (!entry.showing or entry.picker or entry.source.get() != node) continue;
            if (self.invoker(entry.node() orelse continue) == node) return true;
        }
        return false;
    }

    /// HTML 6.6.2 associated focus navigation owner, steps 1–6. Slot
    /// fallback also forms a scope, matching all three engines and Blink's
    /// FindFallbackScopeOwnerSlot (aligned WPT ffc4686d11).
    fn scopeOf(self: *Search, node: *Instance) ?Scope {
        var current = node;
        while (parent(current)) |p| : (current = p) {
            // Steps 2–3: slot assignment and shadow root take precedence.
            if (dom.shadow_hosts.rootForHost(p) != null) {
                const slot = dom.shadow_dom_algorithms.assignedSlotOf(current) orelse return null;
                return Scope.ownedBy(slot);
            }
            if (p.stateAs(interfaces.ShadowRoot.State) != null) {
                const host = interfaces.ShadowRoot.get_host(p) catch return null;
                return .{ .root = p, .owner = host };
            }
            if (isSlot(p)) return Scope.ownedBy(p);
            // Steps 4–5: the document element and showing-popover source.
            if (p == self.document or (interfaces.Document.get_documentElement(self.document) catch null) == p)
                return .{ .root = self.document };
            if (self.invoker(current)) |owner| return .{ .root = current, .owner = owner };
        }
        return null;
    }

    fn eligible(self: *Search, node: *Instance, document_tree: bool) bool {
        if (document_tree) if (self.radios.eligibility(node)) |answer| return answer;
        return focus.isSequentiallyFocusable(node);
    }

    /// One rank selection in a tabindex-ordered scope, preserving tree order
    /// for ties. A negative adjusted starting tabindex uses DOM order.
    fn nextInScope(self: *Search, scope: Scope, start: ?*Instance, direction: Direction) ?*Instance {
        const document_tree = self.popovers == null and scope.tree() == self.document;
        // Browser-majority deviation from HTML 6.6.5 step 4: disabling a
        // positive-tabindex button keeps its explicit rank as the start.
        // Blink AdjustedTabIndex/NextFocusableElement (focus_controller.cc,
        // 8d5ba1795f0c50b90072399d0403389df6eebbd6) and WebKit
        // shadowAdjustedTabIndex (FocusController.cpp, Element.h and
        // HTMLButtonElement.cpp, e40b37859cbe43e3c4fcdc858ade2f16be0ef7dc)
        // preserve it. Gecko IsHTMLFocusable/GetNextTabbableContent
        // (nsGenericHTMLElement.cpp/nsFocusManager.cpp,
        // 7c8835ea32b20d0f3f6118bc27e1b3647015ecba) instead uses DOM order.
        const start_value = if (start) |s| focus.tabindexValue(s) orelse (if (self.isOwner(s) or focus.isFocusableArea(s)) @as(i32, 0) else -1) else 0;
        const start_rank = rank(start_value);
        var seen_start = start == null;
        var best: ?*Instance = null;
        var best_rank: u32 = 0;
        var iterator = Iterator.init(scope, self);
        while (iterator.next()) |node| {
            if (node == start) {
                seen_start = true;
                continue;
            }
            if (!associated.isElement(node)) continue;
            const value = focus.tabindexValue(node) orelse 0;
            if (value < 0) continue;
            const node_rank = rank(value);
            if (start != null) {
                const on_side = if (direction == .forward) seen_start else !seen_start;
                if (start_value < 0) {
                    if (!on_side) continue;
                } else {
                    if (node_rank == start_rank and !on_side) continue;
                    if (direction == .forward and node_rank < start_rank) continue;
                    if (direction == .backward and node_rank > start_rank) continue;
                }
            }
            if (best != null and !(start != null and start_value < 0)) {
                if (direction == .forward and node_rank >= best_rank) continue;
                if (direction == .backward and node_rank < best_rank) continue;
            }
            if (!self.isOwner(node) and !self.eligible(node, document_tree)) continue;
            best = node;
            best_rank = node_rank;
            if (start != null and start_value < 0 and direction == .forward) break;
        }
        return best;
    }

    /// HTML 6.6.2 flattening step 2: retain a focusable owner, and insert its
    /// scope after it; replace a non-focusable owner with its scope.
    fn within(self: *Search, scope: Scope, start: ?*Instance, direction: Direction) ?*Instance {
        var current = start;
        const document_tree = self.popovers == null and scope.tree() == self.document;
        while (self.nextInScope(scope, current, direction)) |candidate| {
            current = candidate;
            if (self.isOwner(candidate)) {
                if (direction == .forward and self.eligible(candidate, document_tree)) return candidate;
                if (self.within(Scope.ownedBy(candidate), null, direction)) |inner| return inner;
                if (direction == .backward and self.eligible(candidate, document_tree)) return candidate;
            } else return candidate;
        }
        return null;
    }

    fn find(self: *Search, start: ?*Instance, direction: Direction) ?*Instance {
        var scope = if (start) |node| self.scopeOf(node) orelse return null else Scope{ .root = self.document };
        // A focused scope owner precedes its descendants, even if script
        // focused a negative-tabindex host outside the normal entry order.
        if (start) |node| {
            if (direction == .forward and self.isOwner(node)) {
                if (self.within(Scope.ownedBy(node), null, direction)) |inner| return inner;
            }
        }
        var current = start;
        while (true) {
            if (self.within(scope, current, direction)) |found| return found;
            const owner = scope.owner orelse return null;
            // Exhausted a nested scope: backward reaches a focusable owner;
            // forward resumes after it. Negative owners are not Tab stops.
            if (direction == .backward and self.eligible(owner, associated.rootOf(owner) == self.document)) return owner;
            scope = self.scopeOf(owner) orelse return null;
            current = owner;
        }
    }
};

/// Find the next/previous area in the flattened scope order. The caller
/// handles child navigables and focuses the result after this borrow ends.
pub fn search(document: *Instance, start: ?*Instance, direction: Direction) ?*Instance {
    const state = dom.top_layer.ofDocument(document, false) catch null;
    const popovers = if (state) |layer| blk: {
        for (layer.entries.items) |entry| {
            if (entry.showing and !entry.picker and entry.source.get() != null) break :blk layer;
        }
        break :blk null;
    } else null;
    var navigation = Search{
        .document = document,
        .radios = radio_focus.Navigation.init(document.ctx.allocator, document),
        .popovers = popovers,
    };
    defer navigation.radios.deinit();
    return navigation.find(start, direction);
}
