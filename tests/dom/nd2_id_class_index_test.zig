//! An element's ID and classes as two indices in its attribute list's
//! header (lane nd2, batch 1, phase N3; tmp/redesign/nodedata-design.md 4.1
//! N3, techniques.md T3; the integrator's perf3 D1 condition: INDICES,
//! never pointers).
//!
//! Every element kept two 24-byte DOMString views - its ID and its class
//! attribute's value - re-derived by the attribute change steps, though the
//! view is empty on 58-99.9% (ID) and 19-94% (classes) of the elements of
//! real pages (crane-layout.md 0.3). Blink and WebKit keep them in the
//! out-of-line ElementData, null for an element with no attributes
//! (Blink core/dom/element_data.h `id_for_style_resolution_`,
//! `class_names_`; WebKit Source/WebCore/dom/ElementData.h m_idForStyleResolution,
//! m_classNames). N3 keeps two one-byte indices in the attribute list's
//! header (which only an element with attributes has): the position of its
//! id and class attributes in no namespace, 0xFF for none and 0xFE for "at a
//! position past 253: scan" - no element has a cap on its attributes (the
//! integrator, 2026-11-10: an element with 70,000 attributes still answers;
//! the length stays 32 bits wide). Each list change (append, remove,
//! replace, change, a clone's appends) re-derives them structurally.
//!
//! The size pins and the header tests are red until N3 lands. The behaviour
//! tests hold before and after it: the ID and classes through every
//! mutation, getElementById, #id / .class matching and getElementsByClassName,
//! at the saturation boundary and far past it.
//!
//! These name only generated interfaces, their States and src/dom types:
//! Element's InternalState is reached as its State's field type, never
//! through its impl (AGENTS.md "The impls boundary").

const std = @import("std");
const builtin = @import("builtin");
const testing = std.testing;
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const dom = @import("dom");

const element_data = dom.element_data;
const ElementData = element_data.ElementData;
const AttributeList = element_data.AttributeList;

/// Whether N3's header indices are in this build.
const has_indices = @hasField(AttributeList, "id_index");

/// Element's InternalState, as its generated State keeps it by value.
const ElementState = @FieldType(interfaces.Element.State, "_embedded");

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

// ============================================================================
// Sizes (red until N3)
// ============================================================================

test "ElementData keeps no ID or classes view: its name and its list, 16 bytes" {
    // 64 at N2: - 24 (the ID view) - 24 (the classes view).
    inline for (.{ "id", "class_name" }) |gone| {
        if (@hasField(ElementData, gone)) {
            printLayout(ElementData);
            return error.FieldStillThere;
        }
    }
    try expectSize(ElementData, 16);
}

test "the attribute list's header keeps the two indices in its 8 bytes; the length stays 32 bits" {
    if (comptime !has_indices) {
        printLayout(AttributeList);
        return error.NoIndices;
    } else {
        try expectSize(AttributeList, 8);
        try testing.expect(@FieldType(AttributeList, "id_index") == u8);
        try testing.expect(@FieldType(AttributeList, "class_index") == u8);
        try testing.expect(@FieldType(AttributeList, "len") == u32);
        try testing.expectEqual(@as(u8, 0xFF), AttributeList.no_index);
        try testing.expectEqual(@as(u8, 0xFE), AttributeList.saturated_index);
    }
}

test "Element's InternalState is 40 bytes" {
    // 88 at N2, less ElementData's 48.
    try expectSize(ElementState, 40);
}

test "a div's one block is 264 bytes, in a 272-byte class" {
    // 312 at N2 (a 320-byte class), less ElementData's 48.
    const S = interfaces.HTMLDivElement.State;
    try expectSize(S, 264);
    try testing.expectEqual(@as(usize, 272), runtime.ArenaAllocator.heldBytes(@sizeOf(S), @alignOf(S)));
}

// ============================================================================
// An engine-less page
// ============================================================================

/// An HTML document with one div in it.
const Page = struct {
    scope: runtime.BrowserScope,
    ctx: runtime.ContextData,
    document: *runtime.Instance = undefined,
    div: *runtime.Instance = undefined,

    /// In place: the scope must not move once it has made an object.
    fn open(self: *Page, allocator: std.mem.Allocator) !void {
        interfaces.process_hooks.startHooksForTest();
        self.* = .{ .scope = runtime.BrowserScope.init(allocator), .ctx = try runtime.ContextData.init(allocator, .{}) };
        self.ctx.browser_scope = &self.scope;
        self.document = try interfaces.Document.init(allocator, &self.ctx);
        try dom.document_internals.setContentType(self.document, "text/html");
        try dom.document_internals.setDocumentType(self.document, .html);
        self.div = try self.element("div");
        _ = try interfaces.Node.call_appendChild(self.document, self.div);
    }

    fn close(self: *Page) void {
        interfaces.Document.deinit(self.document);
        dom.teardown_sweeps.runAll(&self.scope);
        self.scope.deinit();
        self.ctx.deinit();
    }

    fn element(self: *Page, name: []const u8) !*runtime.Instance {
        return interfaces.Document.call_createElement(self.document, str(name), .{ .was_passed = false, .value = undefined });
    }

    /// A child of the div with `n` attributes data-a0 .. data-a{n-1}, made
    /// as the parser makes them (appended, no lookup).
    fn withAttributes(self: *Page, n: usize) !*runtime.Instance {
        const el = try self.element("span");
        _ = try interfaces.Node.call_appendChild(self.div, el);
        try fill(el, 0, n);
        return el;
    }

    fn fill(el: *runtime.Instance, from: usize, to: usize) !void {
        var i = from;
        while (i < to) : (i += 1) {
            var buffer: [32]u8 = undefined;
            const name = try std.fmt.bufPrint(&buffer, "data-a{d}", .{i});
            try dom.element_attributes.append(el, .{ .namespace = null, .prefix = null, .local_name = name, .value = "v" });
        }
    }

    fn set(el: *runtime.Instance, name: []const u8, value: []const u8) !void {
        try interfaces.Element.call_setAttribute(el, str(name), .{ .domstring = str(value) });
    }

    fn remove(el: *runtime.Instance, name: []const u8) !void {
        try interfaces.Element.call_removeAttribute(el, str(name));
    }

    /// `el`'s ID and classes as every reader sees them: the IDL getters,
    /// getElementById, #id and .class matching, getElementsByClassName.
    fn expectIdAndClass(self: *Page, el: *runtime.Instance, id: []const u8, class_name: []const u8) !void {
        const allocator = self.ctx.allocator;
        var got_id = try interfaces.Element.get_id(el);
        defer got_id.deinit(allocator);
        try testing.expectEqualStrings(id, got_id.asSlice());
        var got_class = try interfaces.Element.get_className(el);
        defer got_class.deinit(allocator);
        try testing.expectEqualStrings(class_name, got_class.asSlice());
        if (id.len != 0) {
            try testing.expect((try interfaces.Document.call_getElementById(self.document, str(id))) == el);
            var buffer: [64]u8 = undefined;
            try testing.expect(try interfaces.Element.call_matches(el, str(try std.fmt.bufPrint(&buffer, "#{s}", .{id}))));
            try testing.expect((try interfaces.Document.call_querySelector(self.document, str(try std.fmt.bufPrint(&buffer, "#{s}", .{id})))) == el);
        }
        if (class_name.len != 0) {
            var buffer: [64]u8 = undefined;
            try testing.expect(try interfaces.Element.call_matches(el, str(try std.fmt.bufPrint(&buffer, ".{s}", .{class_name}))));
            const list = try interfaces.Document.call_getElementsByClassName(self.document, str(class_name));
            try testing.expectEqual(@as(u32, 1), try interfaces.HTMLCollection.get_length(list));
            try testing.expect((try interfaces.HTMLCollection.call_item(list, 0)) == el);
        }
    }

    /// The header's indices, when N3 is in.
    fn expectIndices(el: *runtime.Instance, id_index: u8, class_index: u8) !void {
        if (comptime has_indices) {
            const list = element_data.of(el).?.attrs.?;
            try testing.expectEqual(id_index, list.id_index);
            try testing.expectEqual(class_index, list.class_index);
        }
    }
};

// ============================================================================
// The boundary: 253 indexes exactly, 254 and on saturate and scan
// ============================================================================

test "an id and class at positions 253, 254, 255 and 300 all answer" {
    var page: Page = undefined;
    try page.open(testing.allocator);
    defer page.close();

    const cases = [_]struct { at: usize, index: u8 }{
        .{ .at = 0, .index = 0 },
        .{ .at = 253, .index = 253 },
        .{ .at = 254, .index = 0xFE },
        .{ .at = 255, .index = 0xFE },
        .{ .at = 300, .index = 0xFE },
    };
    for (cases, 0..) |case, n| {
        const el = try page.withAttributes(case.at);
        var id_buffer: [16]u8 = undefined;
        var class_buffer: [16]u8 = undefined;
        const id = try std.fmt.bufPrint(&id_buffer, "id{d}", .{n});
        const class_name = try std.fmt.bufPrint(&class_buffer, "c{d}", .{n});
        try Page.set(el, "id", id);
        try Page.set(el, "class", class_name);
        try page.expectIdAndClass(el, id, class_name);
        const class_index: u8 = if (case.at + 1 >= 0xFE) 0xFE else @intCast(case.at + 1);
        try Page.expectIndices(el, case.index, class_index);
        // A change of value keeps the position.
        try Page.set(el, "id", "changed");
        try page.expectIdAndClass(el, "changed", class_name);
        try Page.set(el, "id", id);
    }
}

test "removing attributes before a saturated id brings it back to an exact index; removing the id itself unsets it" {
    var page: Page = undefined;
    try page.open(testing.allocator);
    defer page.close();

    // The id at 254: saturated.
    const el = try page.withAttributes(254);
    try Page.set(el, "id", "sat");
    try Page.set(el, "class", "k");
    try Page.expectIndices(el, 0xFE, 0xFE);
    try page.expectIdAndClass(el, "sat", "k");
    // One attribute before it goes: the id is at 253 now, exact again.
    try Page.remove(el, "data-a0");
    try Page.expectIndices(el, 253, 0xFE);
    try page.expectIdAndClass(el, "sat", "k");
    // One after it goes: nothing moves.
    try Page.remove(el, "class");
    try Page.expectIndices(el, 253, 0xFF);
    try page.expectIdAndClass(el, "sat", "");
    // Back past the boundary, then the id itself goes while saturated.
    try Page.fill(el, 1000, 1001);
    try Page.remove(el, "id");
    try Page.set(el, "id", "again");
    try Page.expectIndices(el, 0xFE, 0xFF);
    try page.expectIdAndClass(el, "again", "");
    try Page.remove(el, "id");
    try Page.expectIndices(el, 0xFF, 0xFF);
    try page.expectIdAndClass(el, "", "");
    try testing.expect((try interfaces.Document.call_getElementById(page.document, str("again"))) == null);
}

test "an id and class set first follow every removal before them and the list's reallocations past 255" {
    var page: Page = undefined;
    try page.open(testing.allocator);
    defer page.close();

    const el = try page.withAttributes(3);
    try Page.set(el, "id", "first");
    try Page.set(el, "class", "a b");
    try Page.expectIndices(el, 3, 4);
    // Grow the list past 255 slots: it reallocates (moves) many times.
    try Page.fill(el, 3, 400);
    try page.expectIdAndClass(el, "first", "a b");
    try Page.expectIndices(el, 3, 4);
    // Removals before them move them down; one after does not.
    try Page.remove(el, "data-a1");
    try Page.expectIndices(el, 2, 3);
    try Page.remove(el, "data-a300");
    try Page.expectIndices(el, 2, 3);
    try page.expectIdAndClass(el, "first", "a b");
    // toggleAttribute removes and re-adds the class at the end: saturated.
    try testing.expect(!try interfaces.Element.call_toggleAttribute(el, str("class"), .{ .was_passed = false, .value = undefined }));
    try Page.expectIndices(el, 2, 0xFF);
    try testing.expect(try interfaces.Element.call_toggleAttribute(el, str("class"), .{ .was_passed = false, .value = undefined }));
    try Page.expectIndices(el, 2, 0xFE);
    try Page.set(el, "class", "z");
    try page.expectIdAndClass(el, "first", "z");
}

test "setAttributeNode replaces a saturated id in place: its value changes, its position does not" {
    var page: Page = undefined;
    try page.open(testing.allocator);
    defer page.close();

    const el = try page.withAttributes(260);
    try Page.set(el, "id", "old");
    try Page.fill(el, 260, 270);
    try Page.expectIndices(el, 0xFE, 0xFF);
    const attr = try interfaces.Document.call_createAttribute(page.document, str("id"));
    try interfaces.Attr.set_value(attr, str("new"));
    const replaced = (try interfaces.Element.call_setAttributeNode(el, attr)).?;
    try testing.expect((try interfaces.Attr.get_ownerElement(replaced)) == null);
    try page.expectIdAndClass(el, "new", "");
    try Page.expectIndices(el, 0xFE, 0xFF);
    // Still at position 260.
    try testing.expectEqualStrings("id", dom.element_attributes.at(el, 260).?.local_name);
    try testing.expect((try interfaces.Document.call_getElementById(page.document, str("old"))) == null);
    // Its Attr's value setter changes it again.
    try interfaces.Attr.set_value(attr, str("newer"));
    try page.expectIdAndClass(el, "newer", "");
}

test "a clone of a 300-attribute element keeps its id and classes" {
    var page: Page = undefined;
    try page.open(testing.allocator);
    defer page.close();

    const el = try page.withAttributes(5);
    try Page.set(el, "class", "early");
    try Page.fill(el, 5, 299);
    try Page.set(el, "id", "late");
    try Page.expectIndices(el, 0xFE, 5);
    const clone = try interfaces.Node.call_cloneNode(el, .{ .was_passed = true, .value = false });
    // The original leaves the tree, so getElementById finds the clone.
    _ = try interfaces.Node.call_removeChild(page.div, el);
    _ = try interfaces.Node.call_appendChild(page.div, clone);
    try page.expectIdAndClass(clone, "late", "early");
    try Page.expectIndices(clone, 0xFE, 5);
    try testing.expectEqual(@as(usize, 301), dom.element_attributes.count(clone));
}

test "an element with 70,000 attributes still answers its id and classes" {
    var page: Page = undefined;
    try page.open(testing.allocator);
    defer page.close();

    const el = try page.withAttributes(70_000);
    try Page.set(el, "class", "many");
    try Page.set(el, "id", "deep");
    try testing.expectEqual(@as(usize, 70_002), dom.element_attributes.count(el));
    try page.expectIdAndClass(el, "deep", "many");
    try Page.expectIndices(el, 0xFE, 0xFE);
    try testing.expectEqualStrings("deep", dom.element_attributes.at(el, 70_001).?.value);
}

test "an id or class in a namespace is not the element's, at any position" {
    var page: Page = undefined;
    try page.open(testing.allocator);
    defer page.close();

    const el = try page.withAttributes(2);
    try interfaces.Element.call_setAttributeNS(el, str("urn:x"), str("p:id"), .{ .domstring = str("ns") });
    try interfaces.Element.call_setAttributeNS(el, str("urn:x"), str("p:class"), .{ .domstring = str("ns") });
    try page.expectIdAndClass(el, "", "");
    try Page.expectIndices(el, 0xFF, 0xFF);
    try Page.set(el, "id", "plain");
    try Page.set(el, "class", "plain-c");
    try page.expectIdAndClass(el, "plain", "plain-c");
    try Page.expectIndices(el, 4, 5);
    // Removing the namespaced lookalikes moves the real ones down.
    try interfaces.Element.call_removeAttributeNS(el, str("urn:x"), str("id"));
    try interfaces.Element.call_removeAttributeNS(el, str("urn:x"), str("class"));
    try Page.expectIndices(el, 2, 3);
    try page.expectIdAndClass(el, "plain", "plain-c");
    // An empty id is no ID; the attribute keeps its place.
    try Page.set(el, "id", "");
    try page.expectIdAndClass(el, "", "plain-c");
    try Page.expectIndices(el, 2, 3);
}

test "the ID reads the list under a poisoning allocator across every reallocation" {
    var debug: @import("root").poisoning.DebugAllocator(.{}) = .init;
    defer testing.expect(debug.deinit() == .ok) catch @panic("the page leaked");
    var page: Page = undefined;
    try page.open(debug.allocator());
    defer page.close();

    try Page.set(page.div, "id", "main");
    try Page.set(page.div, "class", "x y");
    try Page.fill(page.div, 0, 300);
    try page.expectIdAndClass(page.div, "main", "x y");
    try Page.remove(page.div, "data-a5");
    try Page.set(page.div, "id", "moved");
    try page.expectIdAndClass(page.div, "moved", "x y");
    try testing.expect((try interfaces.Document.call_getElementById(page.document, str("main"))) == null);
}
