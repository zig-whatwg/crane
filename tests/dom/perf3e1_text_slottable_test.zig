//! A Text node's slottable state in its NodeBase's rare data (lane perf3,
//! E1 item 2, the text half).
//!
//! DOM 4.2.2.2: "Element and Text nodes are slottables." Every Text node
//! carried its assigned slot and manual slot assignment (64 bytes: two
//! NodeRefs) in Text's InternalState - its whole InternalState - and none of
//! the perf pages' text nodes was ever assigned. Blink keeps them in
//! NodeRareData's FlatTreeNodeData for any node (kFlatTreeNodeData,
//! core/dom/flat_tree_node_data.h); WebKit keeps a node's manually assigned
//! slot in NodeRareData (m_manuallyAssignedSlot) and no assigned slot at
//! all. The element half moved an Element's into its ElementRareData
//! (tests/dom/perf3e1_slottable_test.zig); this moves a Text node's into
//! its NodeBase's NodeRareData, made by dom.slot_helpers' writers' path only.
//!
//! The size pins and the rare-data checks are red until the text half
//! lands; the behaviour tests hold before and after it.
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

const TextState = @FieldType(interfaces.Text.State, "_embedded");
const NodeRareData = dom.node_base.NodeRareData;
const has_rare_slottable = @hasField(NodeRareData, "slottable");

// ============================================================================
// Sizes (red until the text half)
// ============================================================================

test "Text's InternalState keeps no slottable state: it is empty" {
    if (comptime @hasField(TextState, "slottable")) {
        printLayout(TextState);
        return error.SlottableStillInText;
    }
    try expectSize(TextState, 0);
}

test "a text node's one block is 160 bytes: 280 less the slottable state, the inline buffer, EventTarget's lists and NodeBase.holds" {
    // 280 after perf2 b7: 16 of pointers and the live word, EventTarget's 24,
    // Node's 128, CharacterData's 48 and Text's 64 - its slottable state.
    // 216 after perf3 E1; 184 since lane nd1 batch 1 took CharacterData's
    // data to 16 bytes (tests/dom/nd1_text_data_layout_test.zig); 168 since
    // lane lis1 made EventTarget's 24 one pointer (8); 160 since the wrapper
    // redesign's P6 took NodeBase.holds (8).
    const S = interfaces.Text.State;
    try expectSize(S, 160);
    const held = runtime.ArenaAllocator.heldBytes(@sizeOf(S), @alignOf(S));
    if (held - @sizeOf(S) >= 16) {
        std.debug.print("Text.State: {d} bytes in a {d}-byte block\n", .{ @sizeOf(S), held });
        return error.NotExactSize;
    }
}

test "NodeRareData keeps a Text node's slottable state: 104 bytes" {
    if (comptime !has_rare_slottable) return error.NoRareSlottable;
    // 40 (perf2 b4: the registered observer list 16, the node name 16 and
    // its flag) + the slottable state 64.
    try expectSize(NodeRareData, 104);
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

    /// A host in the div with an open shadow root holding a default slot.
    fn host(self: *Page, mode: ?enums.SlotAssignmentMode) !struct { element: *runtime.Instance, slot: *runtime.Instance } {
        const host_element = try self.element("section");
        _ = try interfaces.Node.call_appendChild(self.div, host_element);
        const shadow = try interfaces.Element.call_attachShadow(host_element, .{ .mode = ._open_, .slotAssignment = mode });
        const slot = try self.element("slot");
        _ = try interfaces.Node.call_appendChild(shadow, slot);
        return .{ .element = host_element, .slot = slot };
    }
};

fn nodeRareOf(node: *runtime.Instance) ?*NodeRareData {
    const base = dom.instance_bridge.getNodeBase(node) orelse return null;
    return base.rareData();
}

fn assignedSlotOf(node: *runtime.Instance) ?*runtime.Instance {
    return dom.shadow_dom_algorithms.assignedSlotOf(node);
}

test "a text node no slot assigns has no rare data, however its slottable state is read" {
    var page: Page = undefined;
    try page.open(testing.allocator);
    defer page.close();

    try interfaces.Element.set_innerHTML(page.div, .{ .domstring = str("a<b>b</b>c") });
    const a = (try interfaces.Node.get_firstChild(page.div)).?;
    const c = (try interfaces.Node.get_lastChild(page.div)).?;
    for ([_]*runtime.Instance{ a, c }) |t| {
        try testing.expect(assignedSlotOf(t) == null);
        try testing.expect((try interfaces.Text.get_assignedSlot(t)) == null);
        try testing.expect(nodeRareOf(t) == null);
    }
    // A host with no slot: its text child is found by no slot.
    const lone = try page.element("article");
    _ = try interfaces.Node.call_appendChild(page.div, lone);
    _ = try interfaces.Element.call_attachShadow(lone, .{ .mode = ._open_ });
    const t = try page.text("t");
    _ = try interfaces.Node.call_appendChild(lone, t);
    try testing.expect(assignedSlotOf(t) == null);
    try testing.expect(nodeRareOf(t) == null);
}

test "an assigned text node gets its state in rare data; unassigned by removal and by assign()" {
    var page: Page = undefined;
    try page.open(testing.allocator);
    defer page.close();
    const named = try page.host(null);

    const t = try page.text("t");
    _ = try interfaces.Node.call_appendChild(named.element, t);
    try testing.expect(assignedSlotOf(t).? == named.slot);
    try testing.expect((try interfaces.Text.get_assignedSlot(t)).? == named.slot);
    if (comptime has_rare_slottable) try testing.expect(nodeRareOf(t) != null);
    _ = try interfaces.Node.call_removeChild(named.element, t);
    try testing.expect(assignedSlotOf(t) == null);

    // Manual assignment: assign() writes the manual slot assignment.
    const manual = try page.host(._manual_);
    const u = try page.text("u");
    _ = try interfaces.Node.call_appendChild(manual.element, u);
    try testing.expect(assignedSlotOf(u) == null);
    try testing.expect(nodeRareOf(u) == null);
    try dom.shadow_dom_algorithms.assign(testing.allocator, manual.slot, &.{u});
    try testing.expect(assignedSlotOf(u).? == manual.slot);
    if (comptime has_rare_slottable) try testing.expect(nodeRareOf(u) != null);
    try dom.shadow_dom_algorithms.assign(testing.allocator, manual.slot, &.{});
    try testing.expect(assignedSlotOf(u) == null);
}

test "assigned text nodes' rare data is freed at both exits (poisoning DebugAllocator)" {
    var debug: @import("root").poisoning.DebugAllocator(.{}) = .init;
    defer testing.expect(debug.deinit() == .ok) catch @panic("the page leaked");
    var page: Page = undefined;
    try page.open(debug.allocator());
    defer page.close();
    const h = try page.host(null);

    try interfaces.Element.set_innerHTML(h.element, .{ .domstring = str("a<i>i</i>b") });
    const first = (try interfaces.Node.get_firstChild(h.element)).?;
    try testing.expect(assignedSlotOf(first).? == h.slot);
    // Dropped by innerHTML while assigned; an orphan assigned once.
    try interfaces.Element.set_innerHTML(h.element, .{ .domstring = str("c") });
    const orphan = try page.text("o");
    _ = try interfaces.Node.call_appendChild(h.element, orphan);
    try testing.expect(assignedSlotOf(orphan).? == h.slot);
    _ = try interfaces.Node.call_removeChild(h.element, orphan);
}
