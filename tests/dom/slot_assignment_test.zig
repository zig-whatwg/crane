//! DOM 4.2.2.3-4.2.2.4: slot assignment, run by insert, remove and the
//! attribute change steps, with HTML's assign() for manual assignment.
const std = @import("std");
const dom = @import("dom");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const algorithms = dom.shadow_dom_algorithms;

const allocator = std.testing.allocator;

const Fixture = struct {
    ctx: runtime.ContextData,
    document: *runtime.Instance,
    body: *runtime.Instance,
    shadows: [4]*runtime.Instance = undefined,
    shadow_count: usize = 0,

    fn init(self: *Fixture) !void {
        interfaces.process_hooks.startHooksForTest();
        runtime.initializeRuntime(allocator);
        self.* = .{ .ctx = try runtime.ContextData.init(allocator, .{}), .document = undefined, .body = undefined };
        self.document = try interfaces.Document.init(allocator, &self.ctx);
        try dom.document_internals.setContentType(self.document, "text/html");
        try dom.document_internals.setDocumentType(self.document, .html);
        const html = try self.element("html");
        _ = try interfaces.Node.call_appendChild(self.document, html);
        self.body = try self.element("body");
        _ = try interfaces.Node.call_appendChild(html, self.body);
    }

    fn deinit(self: *Fixture) void {
        // The document tears its tree down - hosts first, each telling its
        // shadow root it is gone - then each shadow root frees its own tree.
        interfaces.Document.deinit(self.document);
        for (self.shadows[0..self.shadow_count]) |shadow| interfaces.ShadowRoot.deinit(shadow);
        self.ctx.deinit();
        runtime.deinitializeRuntime();
    }

    fn element(self: *Fixture, name: []const u8) !*runtime.Instance {
        return interfaces.Document.call_createElement(self.document, runtime.DOMString.initInterned(name), .{ .was_passed = false, .value = undefined });
    }

    fn text(self: *Fixture, data: []const u8) !*runtime.Instance {
        return interfaces.Document.call_createTextNode(self.document, runtime.DOMString.initInterned(data));
    }

    fn append(parent: *runtime.Instance, child: *runtime.Instance) !void {
        _ = try interfaces.Node.call_appendChild(parent, child);
    }

    fn setAttribute(target: *runtime.Instance, name: []const u8, value: []const u8) !void {
        try interfaces.Element.call_setAttribute(target, runtime.DOMString.initInterned(name), .{ .domstring = runtime.DOMString.initInterned(value) });
    }

    /// A connected host with a shadow root of `mode` and `assignment`.
    fn host(self: *Fixture, mode: anytype, assignment: anytype) !struct { host: *runtime.Instance, shadow: *runtime.Instance } {
        const h = try self.element("div");
        try append(self.body, h);
        const shadow = try interfaces.Element.call_attachShadow(h, .{ .mode = mode, .slotAssignment = assignment });
        try dom.node_document.set(shadow, self.document);
        self.shadows[self.shadow_count] = shadow;
        self.shadow_count += 1;
        return .{ .host = h, .shadow = shadow };
    }

    fn slot(self: *Fixture, parent: *runtime.Instance, name: ?[]const u8) !*runtime.Instance {
        const s = try self.element("slot");
        if (name) |n| try setAttribute(s, "name", n);
        try append(parent, s);
        return s;
    }
};

fn expectAssigned(slot: *runtime.Instance, expected: []const *runtime.Instance) !void {
    const nodes = try algorithms.assignedNodes(allocator, slot, false, false);
    defer allocator.free(nodes);
    try std.testing.expectEqualSlices(*runtime.Instance, expected, nodes);
}

fn expectFlattened(slot: *runtime.Instance, expected: []const *runtime.Instance) !void {
    const nodes = try algorithms.assignedNodes(allocator, slot, true, false);
    defer allocator.free(nodes);
    try std.testing.expectEqualSlices(*runtime.Instance, expected, nodes);
}

test "named slots take the host's children by slot name, the default slot the rest" {
    var f: Fixture = undefined;
    try f.init();
    defer f.deinit();
    const h = try f.host(._open_, null);
    const named = try f.slot(h.shadow, "a");
    const default = try f.slot(h.shadow, null);
    const a = try f.element("span");
    try Fixture.setAttribute(a, "slot", "a");
    const t = try f.text("x");
    const b = try f.element("b");
    const unmatched = try f.element("i");
    try Fixture.setAttribute(unmatched, "slot", "nowhere");
    for ([_]*runtime.Instance{ a, t, b, unmatched }) |child| try Fixture.append(h.host, child);

    try expectAssigned(named, &.{a});
    try expectAssigned(default, &.{ t, b });
    try std.testing.expectEqual(@as(?*runtime.Instance, named), algorithms.assignedSlotForScript(a));
    try std.testing.expectEqual(@as(?*runtime.Instance, default), algorithms.assignedSlotForScript(t));
    try std.testing.expectEqual(@as(?*runtime.Instance, null), algorithms.assignedSlotForScript(unmatched));
    try std.testing.expectEqual(@as(?*runtime.Instance, default), algorithms.assignedSlotOf(b));

    // Remove step 8: a removed node leaves its slot and is no longer assigned.
    _ = try interfaces.Node.call_removeChild(h.host, b);
    try expectAssigned(default, &.{t});
    try std.testing.expectEqual(@as(?*runtime.Instance, null), algorithms.assignedSlotOf(b));
    try std.testing.expectEqual(@as(?*runtime.Instance, null), algorithms.assignedSlotForScript(b));
    try Fixture.append(f.body, b);
}

test "a slot inserted later takes the children it names; the first slot of a name wins" {
    var f: Fixture = undefined;
    try f.init();
    defer f.deinit();
    const h = try f.host(._open_, null);
    const a = try f.element("span");
    try Fixture.setAttribute(a, "slot", "a");
    try Fixture.append(h.host, a);
    const second = try f.slot(h.shadow, "a");
    try expectAssigned(second, &.{a});

    // Insert step 7.6: a slot earlier in tree order takes over the name.
    const first = try f.element("slot");
    try Fixture.setAttribute(first, "name", "a");
    _ = try interfaces.Node.call_insertBefore(h.shadow, first, second);
    try expectAssigned(first, &.{a});
    try expectAssigned(second, &.{});
    try std.testing.expectEqual(@as(?*runtime.Instance, first), algorithms.assignedSlotOf(a));
}

test "a slot leaving its shadow tree empties its assigned nodes and unassigns them" {
    var f: Fixture = undefined;
    try f.init();
    defer f.deinit();
    const h = try f.host(._open_, null);
    const wrapper = try f.element("div");
    try Fixture.append(h.shadow, wrapper);
    const s = try f.slot(wrapper, null);
    const child = try f.element("span");
    try Fixture.append(h.host, child);
    try expectAssigned(s, &.{child});

    // Remove step 10: the removed subtree holds the slot.
    _ = try interfaces.Node.call_removeChild(h.shadow, wrapper);
    try expectAssigned(s, &.{});
    try std.testing.expectEqual(@as(?*runtime.Instance, null), algorithms.assignedSlotOf(child));
    try Fixture.append(f.body, wrapper);
}

test "changing a slot attribute or a slot name re-assigns" {
    var f: Fixture = undefined;
    try f.init();
    defer f.deinit();
    const h = try f.host(._open_, null);
    const a = try f.slot(h.shadow, "a");
    const b = try f.slot(h.shadow, "b");
    const child = try f.element("span");
    try Fixture.setAttribute(child, "slot", "a");
    try Fixture.append(h.host, child);
    try expectAssigned(a, &.{child});

    try Fixture.setAttribute(child, "slot", "b");
    try expectAssigned(a, &.{});
    try expectAssigned(b, &.{child});

    try Fixture.setAttribute(b, "name", "c");
    try expectAssigned(b, &.{});
    try std.testing.expectEqual(@as(?*runtime.Instance, null), algorithms.assignedSlotOf(child));
    try Fixture.setAttribute(a, "name", "b");
    try expectAssigned(a, &.{child});
}

test "a closed shadow root's slot is internal: assignedSlot hides it, get the parent does not" {
    var f: Fixture = undefined;
    try f.init();
    defer f.deinit();
    const h = try f.host(._closed_, null);
    const s = try f.slot(h.shadow, null);
    const child = try f.element("span");
    try Fixture.append(h.host, child);
    try expectAssigned(s, &.{child});
    try std.testing.expectEqual(@as(?*runtime.Instance, null), algorithms.assignedSlotForScript(child));
    try std.testing.expectEqual(@as(?*runtime.Instance, s), algorithms.assignedSlotOf(child));
}

test "manual assignment: assign() takes host children, and a manually assigned node appended to its host is assigned" {
    var f: Fixture = undefined;
    try f.init();
    defer f.deinit();
    const h = try f.host(._open_, ._manual_);
    const s1 = try f.slot(h.shadow, null);
    const s2 = try f.slot(h.shadow, null);
    const c1 = try f.element("span");
    const c2 = try f.element("span");
    const c3 = try f.element("span");
    try Fixture.append(h.host, c1);
    try Fixture.append(h.host, c2);
    // Not a child of the host yet.
    try algorithms.assign(allocator, s1, &.{ c1, c3, c2, c1 });
    try expectAssigned(s1, &.{ c1, c2 });
    try std.testing.expectEqual(@as(?*runtime.Instance, null), algorithms.assignedSlotForScript(c3));

    // Golden rule 2: appended to the host, c3 takes its place in order.
    try Fixture.append(h.host, c3);
    try expectAssigned(s1, &.{ c1, c3, c2 });
    try std.testing.expectEqual(@as(?*runtime.Instance, s1), algorithms.assignedSlotForScript(c3));

    // Step 3.1: assigning c1 elsewhere takes it from s1.
    try algorithms.assign(allocator, s2, &.{c1});
    try expectAssigned(s1, &.{ c3, c2 });
    try expectAssigned(s2, &.{c1});
    try std.testing.expectEqual(@as(?*runtime.Instance, s2), algorithms.assignedSlotOf(c1));

    // A slot removed from the tree unassigns its nodes.
    _ = try interfaces.Node.call_removeChild(h.shadow, s1);
    try std.testing.expectEqual(@as(?*runtime.Instance, null), algorithms.assignedSlotOf(c2));
    try std.testing.expectEqual(@as(?*runtime.Instance, null), algorithms.assignedSlotForScript(c3));
    try Fixture.append(f.body, s1);
}

test "flattened slottables follow nested slots, and fall back to a slot's children" {
    var f: Fixture = undefined;
    try f.init();
    defer f.deinit();
    // outer host > [inner host > [slot (in the light tree of the inner host,
    // inside the outer shadow tree)]]: built as outer shadow tree content.
    const outer = try f.host(._open_, null);
    const inner_host = try f.element("div");
    try Fixture.append(outer.shadow, inner_host);
    const inner_shadow = try interfaces.Element.call_attachShadow(inner_host, .{ .mode = ._open_ });
    try dom.node_document.set(inner_shadow, f.document);
    f.shadows[f.shadow_count] = inner_shadow;
    f.shadow_count += 1;
    const inner_slot = try f.slot(inner_shadow, null);
    // The outer slot is a child of the inner host: a slottable of it.
    const outer_slot = try f.slot(inner_host, null);
    const fallback = try f.element("em");
    try Fixture.append(outer_slot, fallback);

    try expectAssigned(inner_slot, &.{outer_slot});
    // No assigned nodes in the outer slot: its children are the fallback.
    try expectFlattened(inner_slot, &.{fallback});

    const light = try f.element("span");
    try Fixture.append(outer.host, light);
    try expectAssigned(outer_slot, &.{light});
    try expectFlattened(inner_slot, &.{light});
    // A slot whose root is no shadow root has no flattened slottables.
    const loose = try f.element("slot");
    try Fixture.append(f.body, loose);
    try Fixture.append(loose, try f.element("u"));
    try expectFlattened(loose, &.{});
}
