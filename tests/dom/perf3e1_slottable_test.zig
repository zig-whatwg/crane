//! An element's slottable state in its rare data (lane perf3, E1 item 2).
//!
//! DOM 4.2.2.2 gives every slottable (an Element or a Text node) an assigned
//! slot and a manual slot assignment. Crane kept both in every element and
//! every Text node - 64 bytes each - and over the perf pages' 3,039,618
//! elements none was ever assigned. Blink keeps them in NodeRareData's
//! FlatTreeNodeData (kFlatTreeNodeData = 46: assigned_slot_,
//! manually_assigned_slot_, core/dom/flat_tree_node_data.h), made by
//! Node::EnsureFlatTreeNodeData when a slot assigns the node; WebKit stores
//! no assigned slot at all (Node::assignedSlot asks the shadow root's slot
//! assignment) and keeps the manually assigned slot in NodeRareData
//! (m_manuallyAssignedSlot). E1 moves the element's state into
//! ElementRareData and splits dom.slot_helpers into a reader's path, which
//! never makes rare data (an event's path, innerText and the style engine
//! read it for every element they visit), and a writer's (`ensure`), which
//! only "assign slottables" and HTML assign() take, for the nodes they
//! assign.
//!
//! The size pins and the rare-data checks are red until item 2 lands; the
//! behaviour tests hold before and after it.
//!
//! These name only generated interfaces, their States and src/dom types
//! (AGENTS.md "The impls boundary").

const std = @import("std");
const builtin = @import("builtin");
const testing = std.testing;
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const dom = @import("dom");
const enums = @import("enums");

fn str(text: []const u8) runtime.DOMString {
    return runtime.DOMString.initInterned(text);
}

fn printLayout(comptime T: type) void {
    @setEvalBranchQuota(100_000);
    std.debug.print("\n{s}: {d} bytes, align {d} (mode {s}, runtime_safety {})\n", .{ @typeName(T), @sizeOf(T), @alignOf(T), @tagName(builtin.mode), std.debug.runtime_safety });
    std.debug.print("{s:<34} {s:>6} {s:>6} {s:>6}  {s}\n", .{ "field", "offset", "size", "align", "type" });
    inline for (@typeInfo(T).@"struct".field_names) |name| {
        const F = @FieldType(T, name);
        std.debug.print("{s:<34} {d:>6} {d:>6} {d:>6}  {s}\n", .{ name, @offsetOf(T, name), @sizeOf(F), @alignOf(F), @typeName(F) });
    }
}

fn expectSize(comptime T: type, expected: usize) !void {
    if (@sizeOf(T) != expected) {
        printLayout(T);
        std.debug.print("{s}: {d} bytes, pinned {d}\n", .{ @typeName(T), @sizeOf(T), expected });
        return error.SizePinMoved;
    }
}

const ElementState = @FieldType(interfaces.Element.State, "_embedded");
const has_rare_slottable = @hasField(dom.element_rare_data.Field, "slottable");

// ============================================================================
// Sizes (red until item 2)
// ============================================================================

test "Element's InternalState keeps no slottable state: 40 bytes" {
    if (comptime @hasField(ElementState, "slottable")) {
        printLayout(ElementState);
        return error.SlottableStillInElement;
    }
    // 200 after item 1: - 64 (the assigned slot and the manual slot
    // assignment, two NodeRefs with their optional tags).
    // 136 at E1; lane nd2 N2 took the name into one record pointer (tests/dom/nd2_element_name_test.zig): 88.
    // nd2 N3: the ID and classes views (48) are indices in the list's header.
    try expectSize(ElementState, 40);
}

// A div's whole State block is pinned in ONE place: tests/dom/node_block_sizes_test.zig
// (lane cg1; lesson testing-a-total-pinned-in-six-files-moves-in-six-files.md).

test "the rare data keeps the slottable state in a block of its own" {
    if (comptime !has_rare_slottable) return error.NoRareSlottable;
    // 344 at E1 in one fixed block; since lane rare1 the rare data is one
    // sparse block whose slot names the state's own block, so the writers'
    // `*SlottableState` (dom.slot_helpers.ensureSlottable) stays good when
    // the block grows (tests/dom/rare1_sparse_rare_data_test.zig).
    try testing.expect(dom.element_rare_data.Value(.slottable) == *dom.slot_helpers.SlottableState);
}

// ============================================================================
// An engine-less page
// ============================================================================

const Page = struct {
    allocator: std.mem.Allocator,
    scope: runtime.BrowserScope,
    ctx: runtime.ContextData,
    document: *runtime.Instance = undefined,
    div: *runtime.Instance = undefined,

    /// In place: the scope must not move once it has made an object.
    fn open(self: *Page, allocator: std.mem.Allocator) !void {
        interfaces.process_hooks.startHooksForTest();
        self.* = .{ .allocator = allocator, .scope = runtime.BrowserScope.init(allocator), .ctx = try runtime.ContextData.init(allocator, .{}) };
        self.ctx.browser_scope = &self.scope;
        self.document = try interfaces.Document.init(allocator, &self.ctx);
        try dom.document_internals.setContentType(self.document, "text/html");
        try dom.document_internals.setDocumentType(self.document, .html);
        self.div = try self.element("div");
        _ = try interfaces.Node.call_appendChild(self.document, self.div);
    }

    fn element(self: *Page, name: []const u8) !*runtime.Instance {
        return interfaces.Document.call_createElement(self.document, str(name), .{ .was_passed = false, .value = undefined });
    }

    fn text(self: *Page, data: []const u8) !*runtime.Instance {
        return interfaces.Document.call_createTextNode(self.document, str(data));
    }

    fn close(self: *Page) void {
        interfaces.Document.deinit(self.document);
        dom.teardown_sweeps.runAll(&self.scope);
        self.scope.deinit();
        self.ctx.deinit();
    }

    /// A host in the div with an open shadow root holding a slot named "a"
    /// and a default slot.
    fn host(self: *Page, mode: ?enums.SlotAssignmentMode) !Host {
        const host_element = try self.element("section");
        _ = try interfaces.Node.call_appendChild(self.div, host_element);
        const shadow = try interfaces.Element.call_attachShadow(host_element, .{ .mode = ._open_, .slotAssignment = mode });
        const named = try self.element("slot");
        try interfaces.Element.call_setAttribute(named, str("name"), .{ .domstring = str("a") });
        const default = try self.element("slot");
        _ = try interfaces.Node.call_appendChild(shadow, named);
        _ = try interfaces.Node.call_appendChild(shadow, default);
        return .{ .element = host_element, .shadow = shadow, .named = named, .default = default };
    }
};

const Host = struct {
    element: *runtime.Instance,
    shadow: *runtime.Instance,
    named: *runtime.Instance,
    default: *runtime.Instance,
};

/// `element`'s rare block, or null when it has none.
fn rareOf(element: *runtime.Instance) ?*dom.element_rare_data.Block {
    return dom.element_rare_data.of(element).block;
}

fn assignedSlotOf(node: *runtime.Instance) ?*runtime.Instance {
    return dom.shadow_dom_algorithms.assignedSlotOf(node);
}

// ============================================================================
// Readers make no rare data
// ============================================================================

test "reading the slottable state of elements no slot assigns makes no rare data" {
    if (comptime !has_rare_slottable) return error.NoRareSlottable;
    var page: Page = undefined;
    try page.open(testing.allocator);
    defer page.close();

    try interfaces.Element.set_innerHTML(page.div, .{ .domstring = str("<p slot=a>p <b>b</b></p><span>s</span>") });
    const p = (try interfaces.Node.get_firstChild(page.div)).?;
    const b = (try interfaces.Node.get_lastChild(p)).?;
    const span = (try interfaces.Node.get_nextSibling(p)).?;
    for ([_]*runtime.Instance{ page.div, p, b, span }) |el| {
        try testing.expect((try interfaces.Element.get_assignedSlot(el)) == null);
        try testing.expect(assignedSlotOf(el) == null);
        try testing.expect(rareOf(el) == null);
    }
    // A host's children with no slot to go to: found by no slot, never
    // assigned, never given state.
    const lone = try page.element("article");
    _ = try interfaces.Node.call_appendChild(page.div, lone);
    _ = try interfaces.Element.call_attachShadow(lone, .{ .mode = ._open_ });
    const child = try page.element("i");
    _ = try interfaces.Node.call_appendChild(lone, child);
    try testing.expect(assignedSlotOf(child) == null);
    try testing.expect(rareOf(child) == null);
}

// ============================================================================
// Writers: assign slottables and assign()
// ============================================================================

test "named assignment: an assigned element gets its state in rare data and follows its slot attribute" {
    var page: Page = undefined;
    try page.open(testing.allocator);
    defer page.close();
    const h = try page.host(null);

    const child = try page.element("span");
    _ = try interfaces.Node.call_appendChild(h.element, child);
    const text = try page.text("t");
    _ = try interfaces.Node.call_appendChild(h.element, text);
    try testing.expect(assignedSlotOf(child).? == h.default);
    try testing.expect(assignedSlotOf(text).? == h.default);
    if (comptime has_rare_slottable) try testing.expect(rareOf(child) != null);

    try interfaces.Element.set_slot(child, str("a"));
    try testing.expect(assignedSlotOf(child).? == h.named);
    try testing.expect((try interfaces.Element.get_assignedSlot(child)).? == h.named);
    try interfaces.Element.call_setAttribute(child, str("slot"), .{ .domstring = str("none") });
    try testing.expect(assignedSlotOf(child) == null);
    try interfaces.Element.call_removeAttribute(child, str("slot"));
    try testing.expect(assignedSlotOf(child).? == h.default);
    // Removed from the host: unassigned (DOM remove step 8 reassigns the
    // slot; every engine clears the old assigned slot).
    _ = try interfaces.Node.call_removeChild(h.element, child);
    try testing.expect(assignedSlotOf(child) == null);
    // The slot's assigned nodes are the Text node alone.
    const assigned = try dom.shadow_dom_algorithms.assignedNodes(testing.allocator, h.default, false, false);
    defer testing.allocator.free(assigned);
    try testing.expectEqual(@as(usize, 1), assigned.len);
    try testing.expect(assigned[0] == text);
}

test "manual assignment: assign() gives each node its manual slot assignment and moves it between slots" {
    var page: Page = undefined;
    try page.open(testing.allocator);
    defer page.close();
    const h = try page.host(._manual_);

    const first = try page.element("span");
    const second = try page.element("em");
    _ = try interfaces.Node.call_appendChild(h.element, first);
    _ = try interfaces.Node.call_appendChild(h.element, second);
    // Manual: nothing is assigned until assign().
    try testing.expect(assignedSlotOf(first) == null);
    try testing.expect(rareOf(first) == null);

    try dom.shadow_dom_algorithms.assign(testing.allocator, h.named, &.{ first, second });
    try testing.expect(assignedSlotOf(first).? == h.named);
    try testing.expect(assignedSlotOf(second).? == h.named);
    if (comptime has_rare_slottable) try testing.expect(rareOf(first) != null and rareOf(second) != null);
    // assign() on another slot takes `second` from the first one (step 3.1).
    try dom.shadow_dom_algorithms.assign(testing.allocator, h.default, &.{second});
    try testing.expect(assignedSlotOf(first).? == h.named);
    try testing.expect(assignedSlotOf(second).? == h.default);
    // An empty assign() clears the slot's manually assigned nodes (step 1).
    try dom.shadow_dom_algorithms.assign(testing.allocator, h.named, &.{});
    try testing.expect(assignedSlotOf(first) == null);
    try testing.expect(assignedSlotOf(second).? == h.default);
}

test "assigned elements' rare data is freed at both exits (poisoning DebugAllocator)" {
    var debug: @import("root").poisoning.DebugAllocator(.{}) = .init;
    defer testing.expect(debug.deinit() == .ok) catch @panic("the page leaked");
    var page: Page = undefined;
    try page.open(debug.allocator());
    defer page.close();
    const h = try page.host(null);

    // Parsed into the host: every element child assigned, then dropped by
    // innerHTML; one kept; an orphan assigned once and removed.
    try interfaces.Element.set_innerHTML(h.element, .{ .domstring = str("<p>a</p><p slot=a>b</p>c<p>d</p>") });
    const kept = (try interfaces.Node.get_firstChild(h.element)).?;
    try testing.expect(assignedSlotOf(kept).? == h.default);
    try interfaces.Element.set_innerHTML(h.element, .{ .domstring = str("<b>x</b>") });
    const orphan = try page.element("span");
    _ = try interfaces.Node.call_appendChild(h.element, orphan);
    try testing.expect(assignedSlotOf(orphan).? == h.default);
    _ = try interfaces.Node.call_removeChild(h.element, orphan);
    try testing.expect(assignedSlotOf(orphan) == null);
}
